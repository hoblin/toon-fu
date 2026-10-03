# frozen_string_literal: true

module ToonFu
  class Reader
    MAX_DEPTH = 100

    def initialize(strict, indent_size)
      @strict = strict
      @indent_size = indent_size
      @depth = 0
    end

    def read(text)
      @lines = Lines.new(text, @strict, @indent_size)
      return {} if @lines.empty?

      root
    end

    private

    def root
      line = @lines.peek
      return empty_array_root if line.content == "[]"

      header = usable(Header.parse(line.content), line)
      return keyless_root(header) if header && header.key.nil?
      return scalar_root(line) if @lines.one? && Tokens.colon_index(line.content).nil?

      object(0)
    end

    def keyless_root(header)
      @lines.next
      value = header.fields? ? table(header, 1) : array(header, 1)
      trailing
      value
    end

    def empty_array_root
      @lines.next
      trailing
      []
    end

    def scalar_root(line)
      @lines.next
      Token.decode(Tokens.trim(line.content))
    end

    def trailing
      return if @lines.empty?

      raise Error, "cannot decode content after the root form: #{@lines.peek.text}"
    end

    def object(depth, result = {})
      while (line = @lines.peek) && line.depth >= depth
        if line.depth > depth
          orphan(line)
          next
        end

        @lines.next
        key, value = field(line, depth)
        store(result, key, value, line)
      end
      result
    end

    def orphan(line)
      raise Error, "cannot decode a line that belongs to no scope on line #{line.number}: #{line.text}" if @strict

      @lines.next
    end

    def store(result, key, value, line)
      raise Error, "cannot decode a duplicate key on line #{line.number}: #{key.inspect}" if @strict && result.key?(key)

      result[key] = value
    end

    def field(line, depth)
      header = usable(Header.parse(line.content), line)
      return [Tokens.key(header.key), header_value(header, depth)] if header&.key
      raise Error, "cannot decode a keyless array header in object field position on line #{line.number}: #{line.text}" if header

      colon = Tokens.colon_index(line.content)
      raise Error, "cannot decode a line without a colon after its key on line #{line.number}: #{line.text}" if colon.nil?

      key = Tokens.key(line.content[0...colon])
      [key, field_value(Tokens.trim(line.content[(colon + 1)..]), depth)]
    end

    def field_value(text, depth)
      return [] if text == "[]"
      return nested(depth) if text.empty?

      Token.decode(text)
    end

    def nested(depth)
      line = @lines.peek
      return {} if line.nil? || line.depth <= depth

      guard(line)
      descend { object(depth + 1) }
    end

    def header_value(header, depth)
      return table(header, depth + 1) if header.fields?
      return [] if header.length.zero? && !items?(depth + 1)

      array(header, depth + 1)
    end

    def items?(depth)
      line = @lines.peek
      !line.nil? && line.depth == depth
    end

    def array(header, depth)
      return inline(header) unless header.inline.empty?

      descend { list(header, depth) }
    end

    def inline(header)
      cells = Tokens.split(header.inline, header.delimiter).map { |cell| Token.decode(Tokens.trim(cell)) }
      count(cells.length, header, "value")
      cells
    end

    def list(header, depth)
      items = []
      while (line = @lines.peek) && line.depth == depth && line.item?
        span(line) unless items.empty?
        @lines.next
        items << item(line, depth)
      end
      scalar_line(@lines.peek, depth)
      count(items.length, header, "item")
      items
    end

    # A scalar line is valid only as a root primitive; inside a scope it is a
    # structural error in strict and non-strict mode alike (§5.2, §14.2).
    def scalar_line(line, depth)
      return if line.nil? || line.depth != depth || Tokens.colon_index(line.content)

      header = Header.parse(line.content)
      return if header && !header.malformed?

      raise Error, "cannot decode a bare token line inside a scope on line #{line.number}: #{line.text}"
    end

    def item(line, depth)
      rest = line.item_content
      return {} if rest.empty?
      return [] if rest == "[]"

      header = usable(Header.parse(rest), line)
      return item_header(header, line, depth) if header
      return item_object(rest, depth) if Tokens.colon_index(rest)

      Token.decode(Tokens.trim(rest))
    end

    def item_header(header, line, depth)
      return item_object(line.item_content, depth) if header.key
      raise Error, "cannot decode a keyless fields-bearing header as a list item on line #{line.number}: #{line.text}" if header.fields?

      array(header, depth + 1)
    end

    def item_object(rest, depth)
      synthetic = Line.new(rest, depth + 1, @lines.number)
      key, value = descend { field(synthetic, depth + 1) }
      result = {}
      store(result, key, value, synthetic)
      following = @lines.peek
      span(following) if following && following.depth == depth + 1
      descend { object(depth + 1, result) }
    end

    def table(header, depth)
      raise Error, "cannot decode a field name repeated in one field list: #{header.duplicate.inspect}" if @strict && header.duplicate

      header.keyed? ? entries(header, depth) : rows(header, depth)
    end

    def rows(header, depth)
      collected = descend do
        gather(depth, stop: ->(line) { key_value_line?(line, header.delimiter) }) { |line| row(header, line) }
      end
      count(collected.length, header, "row")
      collected
    end

    # §9.3: at row depth a line whose first unquoted colon precedes its first
    # unquoted delimiter is a key-value line, and the rows end before it.
    def key_value_line?(line, delimiter)
      colon = Tokens.colon_index(line.content)
      return false if colon.nil?

      cell = Tokens.index_of(line.content, Tokens::UNTIL_CELL_END.fetch(delimiter), delimiter)
      cell.nil? || colon < cell
    end

    def entries(header, depth)
      result = {}
      collected = descend do
        gather(depth) do |line|
          colon = Tokens.colon_index(line.content)
          if colon.nil?
            raise Error, "cannot decode an entry row without a colon on line #{line.number}: #{line.text}" if @strict

            next nil
          end
          [Tokens.key(line.content[0...colon]), row(header, line, line.content[(colon + 1)..]), line]
        end
      end
      collected.compact!
      count(collected.length, header, "entry row")
      collected.each { |key, value, line| store(result, key, value, line) }
      result
    end

    def gather(depth, stop: nil)
      collected = []
      while (line = @lines.peek) && line.depth == depth
        break if stop&.call(line)

        span(line) unless collected.empty?
        @lines.next
        collected << yield(line)
      end
      collected
    end

    def span(line)
      return unless @strict && line.after_blank

      raise Error, "cannot decode a blank line inside a header span, before line #{line.number}: #{line.text}"
    end

    def row(header, line, text = line.content)
      cells = Tokens.split(text, header.delimiter)
      cells = [] if cells.length == 1 && Tokens.trim(cells.first).empty?
      width(cells.length, header, line)
      shape(header.fields, cells.each)
    end

    def shape(fields, cells)
      fields.each_with_object({}) do |(name, nested), result|
        if nested
          result[name] = shape(nested, cells)
        else
          cell = begin
            cells.next
          rescue StopIteration
            next
          end
          result[name] = Token.decode(Tokens.trim(cell))
        end
      end
    end

    def count(actual, header, noun)
      return unless @strict && actual != header.length

      raise Error, "cannot decode #{actual} #{noun}#{"s" unless actual == 1} where the header declares #{header.length}"
    end

    def width(actual, header, line)
      return unless @strict && actual != header.leaves.length

      raise Error, "cannot decode #{actual} cells on line #{line.number} where the header declares #{header.leaves.length} field#{"s" unless header.leaves.length == 1}"
    end

    def usable(header, line)
      return header unless header&.malformed?
      raise Error, "cannot decode a malformed array header on line #{line.number}: #{line.text}" if @strict

      nil
    end

    def guard(line)
      return unless @strict && line.depth > @depth + 1

      raise Error, "cannot decode a depth jump on line #{line.number}: #{line.text}"
    end

    def descend
      @depth += 1
      raise Error, "cannot decode nesting deeper than #{MAX_DEPTH} levels" if @depth > MAX_DEPTH

      yield
    ensure
      @depth -= 1
    end
  end
end
