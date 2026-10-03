# frozen_string_literal: true

module ToonFu
  class Reader
    BOM = "\u{feff}"
    COMMENT = /\A *#/
    BRACKETS = /\[(?:0|[1-9][0-9]*):?[\t|]?\](?:\{.*\})?:/
    HEADER = /\A(?:"(?:[^"\\]|\\.)*"|[^\s\[]+)?#{BRACKETS}/
    ROOT_HEADER = /\A#{BRACKETS}/
    TABS = /\A\t+/

    def initialize(strict, indent_size)
      @strict = strict
      @indent_size = indent_size
    end

    def read(text)
      @lines = significant(text)
      return {} if @lines.empty?

      root
    end

    private

    def significant(text)
      text = text.delete_prefix(BOM)
      text.split("\n", -1).map { |line| line.delete_suffix("\r") }
        .reject { |line| COMMENT.match?(line) }
        .map { |line| line.sub(/ +\z/, "") }
        .reject(&:empty?)
    end

    def root
      first = @lines.first
      return header_root(first) if ROOT_HEADER.match?(first)
      return trailing(1) { [] } if first == "[]"
      return Token.decode(first) if @lines.one? && !key_value?(first)

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
        indent(line)
        raise Error, "cannot decode an array yet: #{line}" if HEADER.match?(line.strip)
        raise Error, "cannot decode nesting yet: #{line}" if depth(line).positive?
        raise Error, "cannot decode a line that is not a key-value pair: #{line}" unless key_value?(line)

        key, value = pair(line)
        raise Error, "cannot decode a duplicate key: #{key.inspect}" if @strict && result.key?(key)

        result[key] = value
      end
    end

    def indent(line)
      spaces = line[/\A */].length
      raise Error, "cannot decode a line indented with a tab: #{line}" if @strict && TABS.match?(line)
      raise Error, "cannot decode an indentation of #{spaces} spaces, not a multiple of #{@indent_size}: #{line}" if @strict && !(spaces % @indent_size).zero?
    end

    def pair(line)
      key, value = split_key(line.strip)
      [Token.decode(key), (value == "[]") ? [] : Token.decode(value)]
    end

    def split_key(line)
      colon = colon_index(line)
      raise Error, "cannot decode a line without a colon after its key: #{line}" if colon.nil?

      [line[0...colon].strip, line[(colon + 1)..].strip]
    end

    def key_value?(line)
      !colon_index(line.strip).nil?
    end

    def colon_index(line)
      index = 0
      while index < line.length
        case line[index]
        when '"'
          closing = Token.closing_quote(line[index..])
          return nil if closing.nil?

          index += closing + 1
        when ":" then return index
        else index += 1
        end
      end
      nil
    end
  end
end
