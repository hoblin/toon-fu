# frozen_string_literal: true

module ToonFu
  # Decodes TOON with one set of options, for callers that decode many.
  class Decoder
    # @param strict [Boolean] whether to enforce the spec's strict-mode
    #   checks; with +false+ duplicate keys resolve last-write-wins and
    #   indentation is lenient
    # @param indent_size [Integer] spaces per nesting level
    # @raise [ArgumentError] when strict is not a boolean or indent_size is
    #   not a positive Integer
    def initialize(strict: true, indent_size: 2)
      raise ArgumentError, "strict must be true or false, got #{strict.inspect}" unless [true, false].include?(strict)
      raise ArgumentError, "indent_size must be a positive Integer, got #{indent_size.inspect}" unless indent_size.is_a?(Integer) && indent_size.positive?

      @strict = strict
      @indent_size = indent_size
    end

    # Decodes TOON into the JSON data model.
    #
    # Returns +Hash+ with String keys, +Array+, +String+, +Integer+,
    # +Float+, +true+, +false+ or +nil+. An unquoted token is a number only
    # when it matches the spec's own grammar, so +.5+, +1.+, +05+, +Infinity+
    # and +1_000+ decode as strings.
    #
    # Out-of-range numbers: a token the grammar accepts but +Float+ cannot
    # hold without losing its magnitude, such as +1e400+ or +1e-400+, raises
    # rather than becoming infinity or zero. Integers are exact at any size.
    #
    # @param text [String] UTF-8, or an encoding that transcodes to it
    # @return [Hash, Array, String, Integer, Float, true, false, nil]
    # @raise [Error] for text that is not a String or not valid UTF-8; for a
    #   number outside the Float range; for an invalid escape, an
    #   unterminated quoted string, or content after a closing quote; for a
    #   key without a colon; and, when strict, for duplicate keys and
    #   indentation that is not a multiple of indent_size
    def decode(text)
      Reader.new(@strict, @indent_size).read(utf8(text))
    end

    private

    def utf8(text)
      raise Error, "cannot decode #{text.class}; pass a String" unless text.is_a?(String)

      text = text.dup.force_encoding(Encoding::UTF_8) if text.encoding == Encoding::BINARY
      text = text.encode(Encoding::UTF_8) unless text.encoding == Encoding::UTF_8
      raise Error, "cannot decode text that is not valid UTF-8" unless text.valid_encoding?

      text
    rescue EncodingError => error
      raise Error, "cannot decode text as UTF-8: #{error.message}"
    end
  end
end
