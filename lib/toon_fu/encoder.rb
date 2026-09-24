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

      @indent = " " * indent_size
      @strings = StringLiteral.new(delimiter)
    end

    # @param value [Hash, nil, true, false, Integer, Float, String] hash keys
    #   are encoded by their +to_s+
    # @return [String]
    # @raise [Error] when the value has no TOON representation
    def encode(value)
      return scalar(value) unless value.is_a?(Hash)

      lines = []
      object(value, lines, "")
      lines.join("\n")
    end

    private

    def object(hash, lines, indent)
      hash.each do |key, value|
        prefix = "#{indent}#{@strings.key(key.to_s)}:"
        if value.is_a?(Hash)
          lines << prefix
          object(value, lines, indent + @indent)
        else
          lines << "#{prefix} #{scalar(value)}"
        end
      end
    end

    def scalar(value)
      case value
      when nil then "null"
      when true, false, Integer then value.to_s
      when Float then FloatLiteral.new(value).to_s
      when String then @strings.encode(value)
      else raise Error, "cannot encode #{value.class}"
      end
    end
  end
end
