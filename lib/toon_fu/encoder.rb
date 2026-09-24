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

    # @param value [Hash, Array, nil, true, false, Integer, Float, String]
    #   nested in any combination; hash keys are encoded by their +to_s+
    # @return [String]
    # @raise [Error] when the value has no TOON representation
    def encode(value)
      Writer.new(@delimiter, @indent).write(value)
    end
  end
end
