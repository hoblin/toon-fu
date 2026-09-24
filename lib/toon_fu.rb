# frozen_string_literal: true

require_relative "toon_fu/version"
require_relative "toon_fu/encoder"
require_relative "toon_fu/float_literal"
require_relative "toon_fu/string_literal"
require_relative "toon_fu/writer"

# TOON (Token-Oriented Object Notation) for Ruby.
module ToonFu
  class Error < StandardError; end

  private_constant :FloatLiteral, :StringLiteral, :Writer

  # Encodes a value as TOON.
  #
  #   ToonFu.encode("hello")               # => "hello"
  #   ToonFu.encode("a,b")                 # => "\"a,b\""
  #   ToonFu.encode("a,b", delimiter: "|") # => "a,b"
  #   ToonFu.encode(1e-7)                  # => "1e-7"
  #   ToonFu.encode({user: {id: 1}})       # => "user:\n  id: 1"
  #   ToonFu.encode({tags: ["a", "b"]})    # => "tags[2]: a,b"
  #
  # @param value [Hash, Array, nil, true, false, Integer, Float, String]
  # @param options [Hash] see {Encoder#initialize}
  # @return [String]
  # @raise [Error] when the value has no TOON representation
  def self.encode(value, **options)
    Encoder.new(**options).encode(value)
  end
end
