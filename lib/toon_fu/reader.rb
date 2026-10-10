# frozen_string_literal: true

module ToonFu
  class Reader
    MAX_DEPTH = 100

    def initialize(strict, indent_size)
      @strict = strict
      @indent_size = indent_size
      @depth = 0
      @in_span = false
    end

    def read(text)
      @lines = Lines.new(text, @strict, @indent_size)
      return {} if @lines.empty?

      root
    end

    private

    def root
      line = @lines.peek
      return object(-1, 0) unless line.depth.zero?
      return empty_array_root if line.content == "[]"

      header = parse_header(line)
      return keyless_root(header) if header && header.key.nil?
      return scalar_root(line) if @lines.one? && scalar?(line)

      object(-1, 0)
    end

    def keyless_root(header)
      @lines.next
      value = header.fields? ? table(header, 0) : array(header, 0)
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

    def object(parent, depth, result = {})
      while (line = @lines.peek) && line.depth > parent
        if line.depth == depth
          take
          key, value = field(line, depth)
          store(result, key, value, line)
        else
          orphan(line)
        end
      end
      result
    end

    def orphan(line)
      raise Error, "cannot decode a line that belongs to no scope on line #{line.number}: #{line.text}"
    end

    def scalar?(line)
      Tokens.colon_index(line.content).nil?
    end

    def store(result, key, value, line)
      raise Error, "cannot decode a duplicate key on line #{line.number}: #{key.inspect}" if @strict && result.key?(key)

      result[key] = value
    end

    def field(line, depth)
      header = parse_header(line)
      return [Tokens.key(header.key), header_value(header, depth)] if header&.key
      misplaced(line, "a keyless array header in object field position") if header

      colon = Tokens.colon_index(line.content)
      raise Error, "cannot decode a line without a colon on line #{line.number}: #{line.text}" if colon.nil?

      key = Tokens.key(line.content[0...colon])
      [key, field_value(Tokens.trim(line.content[(colon + 1)..]), depth)]
    end

    def field_value(text, depth)
      return [] if text == "[]"
      return nested(depth) if text.empty?

      Token.decode(text)
    end

    def nested(parent)
      depth = content_depth(parent)
      return {} if depth.nil?

      descend { object(parent, depth) }
    end

    def header_value(header, depth)
      header.fields? ? table(header, depth) : array(header, depth)
    end

    def array(header, parent)
      return inline(header) unless header.inline.empty?

      items = descend { gather(parent, stop: ->(line) { !line.item? }) { |line| item(line) } }
      count(items.length, header, "item")
      items
    end

    def inline(header)
      cells = Tokens.split(header.inline, header.delimiter).map { |cell| Token.decode(Tokens.trim(cell)) }
      count(cells.length, header, "value")
      cells
    end

    def item(line)
      rest = line.item_content
      return {} if rest.empty?
      return [] if rest == "[]"

      header = parse_header(line, rest)
      return item_header(header, line) if header
      return item_object(rest, line) if Tokens.colon_index(rest)

      Token.decode(Tokens.trim(rest))
    end

    def item_header(header, line)
      return array(header, line.depth) unless header.key || header.fields?

      misplaced(line, "a keyless fields-bearing header as a list item") unless header.key
      item_object(line.item_content, line)
    end

    def misplaced(line, what)
      raise Error, "cannot decode #{what} on line #{line.number}: #{line.text}"
    end

    def item_object(rest, line)
      depth = line.depth + 1
      synthetic = Line.new(rest, depth, line.number)
      key, value = descend { field(synthetic, depth) }
      result = {}
      store(result, key, value, synthetic)
      descend { object(line.depth, depth, result) }
    end

    def table(header, parent)
      raise Error, "cannot decode a field name repeated in one field list: #{header.duplicate.inspect}" if @strict && header.duplicate

      header.keyed? ? entries(header, parent) : rows(header, parent)
    end

    def rows(header, parent)
      collected = descend do
        gather(parent, stop: ->(line) { key_value_line?(line, header.delimiter) }) { |line| row(header, line) }
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

    def entries(header, parent)
      result = {}
      collected = descend do
        gather(parent) do |line|
          colon = Tokens.colon_index(line.content)
          raise Error, "cannot decode an entry row without a colon on line #{line.number}: #{line.text}" if colon.nil?

          [Tokens.key(line.content[0...colon]), row(header, line, line.content[(colon + 1)..]), line]
        end
      end
      count(collected.length, header, "entry row")
      collected.each { |key, value, line| store(result, key, value, line) }
      result
    end

    def gather(parent, stop: nil)
      outer = @in_span
      collected = []
      depth = content_depth(parent)
      while depth && (line = @lines.peek) && line.depth > parent
        orphan(line) if line.depth != depth
        break if stop&.call(line)

        take
        @in_span = true
        collected << yield(line)
      end
      collected
    ensure
      @in_span = outer
    end

    def take
      line = @lines.next
      raise Error, "cannot decode a blank line inside a header span, before line #{line.number}: #{line.text}" if @strict && @in_span && line.after_blank
    end

    def row(header, line, text = line.content)
      cells = Tokens.split(text, header.delimiter)
      cells = [] if cells.length == 1 && Tokens.trim(cells.first).empty?
      width(cells.length, header, line)
      shape(header.fields, cells)
    end

    def shape(fields, cells)
      fields.each_with_object({}) do |(name, nested), result|
        result[name] = nested ? shape(nested, cells) : Token.decode(Tokens.trim(cells.shift))
      end
    end

    def count(actual, header, noun)
      return unless @strict && actual != header.length

      raise Error, "cannot decode #{actual} #{noun}#{"s" unless actual == 1} where the header declares #{header.length}"
    end

    def width(actual, header, line)
      return if actual == header.leaves.length

      raise Error, "cannot decode #{actual} cells on line #{line.number} where the header declares #{header.leaves.length} field#{"s" unless header.leaves.length == 1}"
    end

    def parse_header(line, content = line.content)
      header = Header.parse(content)
      raise Error, "cannot decode a malformed array header on line #{line.number}: #{line.text}" if header&.malformed?

      header
    end

    def content_depth(parent)
      line = @lines.peek
      return if line.nil? || line.depth <= parent
      raise Error, "cannot decode a depth jump on line #{line.number}: #{line.text}" if @strict && line.depth > parent + 1

      line.depth
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
