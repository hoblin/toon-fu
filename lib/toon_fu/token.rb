# frozen_string_literal: true

module ToonFu
  class Token
    NUMBER = /\A-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:e[+-]?[0-9]+)?\z/i
    INTEGER = /\A-?(?:0|[1-9][0-9]*)\z/
    ESCAPE = /\\(?:(["\\nrt])|u([0-9a-fA-F]{4})|(.|\z))/m
    UNESCAPES = {'"' => '"', "\\" => "\\", "n" => "\n", "r" => "\r", "t" => "\t"}.freeze
    SURROGATES = (0xd800..0xdfff)
    EXACT_INTEGERS = 2**Float::MANT_DIG

    def self.key(text)
      text.start_with?('"') ? quoted(text) : text
    end

    def self.decode(text)
      return quoted(text) if text.start_with?('"')
      return nil if text == "null"
      return true if text == "true"
      return false if text == "false"
      return number(text) if NUMBER.match?(text)

      text
    end

    def self.quoted(text)
      closing = closing_quote(text)
      raise Error, "cannot decode an unterminated quoted string: #{text}" if closing.nil?
      raise Error, "cannot decode content after a closing quote: #{text}" unless closing == text.length - 1

      unescape(text[1...closing])
    end

    def self.closing_quote(text)
      index = 1
      while index < text.length
        case text[index]
        when "\\" then index += 2
        when '"' then return index
        else index += 1
        end
      end
      nil
    end

    def self.unescape(body)
      body.gsub(ESCAPE) do
        if (literal = UNESCAPES[$1])
          literal
        elsif $2
          codepoint($2.hex)
        else
          raise Error, "cannot decode the escape sequence \\#{$3}"
        end
      end
    end

    def self.codepoint(value)
      raise Error, "cannot decode the lone surrogate escape \\u#{format("%04x", value)}" if SURROGATES.cover?(value)

      value.chr(Encoding::UTF_8)
    end

    def self.number(text)
      return Integer(text, 10) if INTEGER.match?(text)

      float = Float(text)
      raise Error, "cannot decode #{text} as a Float without losing its magnitude" if float.infinite? || (float.zero? && nonzero?(text))

      integral?(float) ? Integer(float) : float
    end

    def self.integral?(float)
      float == float.truncate && float.abs <= EXACT_INTEGERS
    end

    def self.nonzero?(text)
      text.split(/e/i).first.match?(/[1-9]/)
    end

    private_class_method :quoted, :unescape, :codepoint, :number, :nonzero?, :integral?
  end
end
