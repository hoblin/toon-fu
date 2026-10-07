# frozen_string_literal: true

module ToonFu
  module Tokens
    QUOTED = /"(?:[^"\\]|\\.?)*"?/
    UNTIL_COLON = /[^":]+/
    UNTIL_BRACKET = /[^":\[]+/
    UNTIL_BRACE = /[^"{]+/
    BRACE = /[{}]/
    SURROUNDING_SPACES = /\A +| +\z/
    UNTIL_CELL_END = Encoder::DELIMITERS.to_h { |d| [d, /[^"#{Regexp.escape(d)}]+/] }.freeze
    UNTIL_FIELD_END = Encoder::DELIMITERS.to_h { |d| [d, /[^"{}#{Regexp.escape(d)}]+/] }.freeze
    UNTIL_FOREIGN = Encoder::DELIMITERS.to_h { |d| [d, /[^"#{Regexp.escape((Encoder::DELIMITERS - [d]).join)}]+/] }.freeze

    def self.index_of(text, pattern, stops)
      scanner = StringScanner.new(text)
      until scanner.eos?
        next if scanner.skip(pattern)
        return scanner.charpos if stops.include?(scanner.peek(1))
        return nil unless scanner.skip(QUOTED)
      end
      nil
    end

    def self.colon_index(text)
      index_of(text, UNTIL_COLON, ":")
    end

    def self.bracket_index(text)
      index = index_of(text, UNTIL_BRACKET, "[:")
      (index && text[index] == "[") ? index : nil
    end

    def self.brace_index(text)
      index = index_of(text, UNTIL_BRACE, "{")
      (index && text[index] == "{") ? index : nil
    end

    def self.closing_brace(text)
      depth = 0
      scanner = StringScanner.new(text)
      until scanner.eos?
        if scanner.skip(QUOTED)
          next
        elsif scanner.skip(/\{/)
          depth += 1
        elsif scanner.skip(/\}/)
          depth -= 1
          return scanner.charpos - 1 if depth.zero?
        else
          scanner.skip(/[^"{}]+/) || scanner.skip(/./)
        end
      end
      nil
    end

    def self.split_fields(text, delimiter)
      entries = []
      current = +""
      depth = 0
      scanner = StringScanner.new(text)
      until scanner.eos?
        if (quoted = scanner.scan(QUOTED))
          current << quoted
        elsif depth.zero? && scanner.skip(delimiter)
          entries << current
          current = +""
        elsif (brace = scanner.scan(BRACE))
          depth += (brace == "{") ? 1 : -1
          current << brace
        else
          current << (scanner.scan(UNTIL_FIELD_END.fetch(delimiter)) || scanner.getch)
        end
      end
      entries << current
      entries
    end

    def self.split(text, delimiter)
      cells = []
      current = +""
      scanner = StringScanner.new(text)
      until scanner.eos?
        if (quoted = scanner.scan(QUOTED))
          current << quoted
        elsif scanner.skip(delimiter)
          cells << current
          current = +""
        else
          current << (scanner.scan(UNTIL_CELL_END.fetch(delimiter)) || scanner.getch)
        end
      end
      cells << current
      cells
    end

    def self.trim(text)
      text.gsub(SURROUNDING_SPACES, "")
    end

    def self.whole_token?(text)
      return true unless text.start_with?('"')

      Token.closing_quote(text) == text.length - 1
    end

    def self.key(text)
      Token.key(trim(text))
    end
  end
end
