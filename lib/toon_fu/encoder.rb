# frozen_string_literal: true

module ToonFu
  # Encodes values with one set of options, for callers that encode many.
  class Encoder
    DELIMITERS = [",", "\t", "|"].freeze

    # @param delimiter [String] the document delimiter, one of {DELIMITERS};
    #   strings containing it are quoted
    # @param indent_size [Integer] spaces per nesting level
    # @raise [ArgumentError] when the delimiter is not one of {DELIMITERS}
    #   or indent_size is not a positive Integer
    def initialize(delimiter: ",", indent_size: 2)
      raise ArgumentError, "delimiter must be one of #{DELIMITERS.inspect}, got #{delimiter.inspect}" unless DELIMITERS.include?(delimiter)
      raise ArgumentError, "indent_size must be a positive Integer, got #{indent_size.inspect}" unless indent_size.is_a?(Integer) && indent_size.positive?

      @delimiter = delimiter
      @indent = " " * indent_size
    end

    # Encodes a value as TOON.
    #
    # Accepts the JSON data model plus these Ruby types, nested in any
    # combination:
    #
    # - +Hash+ with String, Symbol or Integer keys, which become strings;
    #   +Array+; +Set+ as an array
    # - +String+ in UTF-8, in an encoding that transcodes to it, or binary
    #   bytes that are valid UTF-8; +Symbol+ as its name
    # - +Integer+ of any size as its exact digits; +Float+ and +BigDecimal+,
    #   with NaN and infinities as +null+, +BigDecimal+ as its exact digits;
    #   +true+, +false+, +nil+
    # - +Date+ as an ISO 8601 date; +Time+ and +DateTime+ as ISO 8601
    #   timestamps keeping their offset, fraction digits up to the last
    #   non-zero one
    # - objects that declare themselves a Hash, Array or String through
    #   Ruby's implicit conversions: +to_hash+, +to_ary+, +to_str+
    # - any object responding to +as_toon+: its result is encoded instead,
    #   ahead of the mappings above
    #
    # @param value [Object] one of the types above
    # @return [String] UTF-8
    # @raise [Error] for any other value type; for keys other than String,
    #   Symbol or Integer, and keys that collide once converted to strings;
    #   for strings that are not valid UTF-8; for circular references,
    #   including an +as_toon+ or implicit conversion that leads back to its
    #   own object
    def encode(value)
      Writer.new(@delimiter, @indent).write(Normalizer.new.call(value))
    rescue SystemStackError
      raise Error, "cannot encode a circular reference or nesting too deep"
    end
  end
end
