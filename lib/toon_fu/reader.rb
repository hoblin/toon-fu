# frozen_string_literal: true

module ToonFu
  class Reader
    BOM = "\u{feff}"
    COMMENT = /\A *#/
    BRACKETS = /\[(?:0|[1-9][0-9]*):?[\t|]?\](?:\{.*\})?:/
    HEADER = /\A(?:"(?:[^"\\]|\\.)*"|[^\s\[]+)?#{BRACKETS}/
    ROOT_HEADER = /\A#{BRACKETS}/
    TABS = /\A\t+/
    BLANK = /\A\s*\z/
    INDENTATION = /\A[ \t]*/
    PLAIN = /[^":]+/
    QUOTED = /"(?:[^"\\]|\\.)*"/

    def initialize(strict, indent_size)
      @strict = strict
      @indent_size = indent_size
    end

    def read(text)
      @lines = significant(text)
      return {} if @lines.empty?

      @lines.each { |line| indent(line) } if @strict
      root
    end

    private

    def significant(text)
      text = text.delete_prefix(BOM)
      text.split("\n", -1).map { |line| line.delete_suffix("\r") }
        .reject { |line| COMMENT.match?(line) }
        .map { |line| line.sub(/ +\z/, "") }
        .reject { |line| BLANK.match?(line) }
    end

    def root
      first = content(@lines.first)
      return header_root(first) if ROOT_HEADER.match?(first)
      return trailing(1) { [] } if first == "[]"
      return Token.decode(first) if @lines.one? && colon_index(first).nil?

      object
    end

    def header_root(header)
      scope = 1 + @lines.drop(1).take_while { |line| depth(line).positive? }.length
      trailing(scope) { raise Error, "cannot decode a root array yet: #{header}" }
    end

    def trailing(consumed)
      raise Error, "cannot decode content after the root form: #{@lines[consumed]}" if @lines.length > consumed

      yield
    end

    def depth(line)
      line[/\A */].length / @indent_size
    end

    def object
      @lines.each_with_object({}) do |line, result|
        content = content(line)
        colon = colon_index(content)
        raise Error, "cannot decode an array yet: #{line}" if header?(content, colon)
        raise Error, "cannot decode nesting yet: #{line}" if depth(line).positive?
        raise Error, "cannot decode a line that is not a key-value pair: #{line}" if colon.nil?

        key = Token.key(trim(content[0...colon]))
        raise Error, "cannot decode a duplicate key: #{key.inspect}" if @strict && result.key?(key)

        result[key] = value(trim(content[(colon + 1)..]))
      end
    end

    def indent(line)
      raise Error, "cannot decode a line indented with a tab: #{line}" if TABS.match?(line)

      spaces = line[/\A */].length
      raise Error, "cannot decode an indentation of #{spaces} spaces, not a multiple of #{@indent_size}: #{line}" unless (spaces % @indent_size).zero?
    end

    def value(text)
      case text
      when "[]" then []
      when "" then {}
      else Token.decode(text)
      end
    end

    def content(line)
      line.sub(INDENTATION, "")
    end

    def header?(line, colon)
      HEADER.match?(line) && (colon.nil? || line.index("[") < colon)
    end

    def trim(text)
      text = text.dup
      nil while text.delete_prefix!(" ")
      nil while text.delete_suffix!(" ")
      text
    end

    def colon_index(line)
      scanner = StringScanner.new(line)
      until scanner.eos?
        next if scanner.skip(PLAIN)
        return scanner.charpos if scanner.peek(1) == ":"
        return nil unless scanner.skip(QUOTED)
      end
      nil
    end
  end
end
