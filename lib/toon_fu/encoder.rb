# frozen_string_literal: true

module ToonFu
  # Encodes values with one set of options, for callers that encode many.
  class Encoder
    DELIMITERS = [",", "\t", "|"].freeze

    # @param delimiter [String] the document delimiter, one of {DELIMITERS};
    #   strings containing it are quoted
    # @param indent [Integer] spaces per nesting level
    # @raise [ArgumentError] when the delimiter is not one of {DELIMITERS}
    def initialize(delimiter: ",", indent: 2)
      raise ArgumentError, "delimiter must be one of #{DELIMITERS.inspect}, got #{delimiter.inspect}" unless DELIMITERS.include?(delimiter)

      @indent = indent
      @strings = StringLiteral.new(delimiter)
    end

    # @param value [nil, true, false, Integer, Float, String]
    # @return [String]
    # @raise [Error] when the value has no TOON representation
    def encode(value)
      case value
      when nil then "null"
      when true, false then value.to_s
      when Integer, Float then Number.new(value).to_s
      when String then @strings.encode(value)
      else raise Error, "cannot encode #{value.class}"
      end
    end
  end
end
