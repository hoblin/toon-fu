# frozen_string_literal: true

module ToonFu
  module Tokens
    QUOTED = /"(?:[^"\\]|\\.)*"/
    PLAIN_UNTIL = {}

    def self.scanner(text)
      StringScanner.new(text)
    end

    def self.index_of(text, stops)
      pattern = PLAIN_UNTIL[stops] ||= /[^"#{Regexp.escape(stops)}]+/
      scanner = scanner(text)
      until scanner.eos?
        next if scanner.skip(pattern)
        return scanner.charpos if stops.include?(scanner.peek(1))
        return nil unless scanner.skip(QUOTED)
      end
      nil
    end

    def self.colon_index(text)
      index_of(text, ":")
    end

    def self.bracket_index(text)
      index = index_of(text, "[:")
      (index && text[index] == "[") ? index : nil
    end

    def self.brace_index(text)
      index = index_of(text, "{")
      (index && text[index] == "{") ? index : nil
    end

    def self.closing_brace(text)
      depth = 0
      scanner = scanner(text)
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
      scanner = scanner(text)
      until scanner.eos?
        if (quoted = scanner.scan(QUOTED))
          current << quoted
        elsif depth.zero? && scanner.skip(/#{Regexp.escape(delimiter)}/)
          entries << current
          current = +""
        elsif (brace = scanner.scan(/[{}]/))
          depth += (brace == "{") ? 1 : -1
          current << brace
        else
          current << (scanner.scan(/[^"{}#{Regexp.escape(delimiter)}]+/) || scanner.getch)
        end
      end
      entries << current
      entries
    end

    def self.split(text, delimiter)
      cells = []
      current = +""
      scanner = scanner(text)
      until scanner.eos?
        if (quoted = scanner.scan(QUOTED))
          current << quoted
        elsif scanner.skip(/#{Regexp.escape(delimiter)}/)
          cells << current
          current = +""
        else
          current << (scanner.scan(/[^"#{Regexp.escape(delimiter)}]+/) || scanner.getch)
        end
      end
      cells << current
      cells
    end

    def self.trim(text)
      text = text.dup
      nil while text.delete_prefix!(" ")
      nil while text.delete_suffix!(" ")
      text
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
