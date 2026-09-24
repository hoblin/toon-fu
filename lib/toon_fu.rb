# frozen_string_literal: true

require "date"

require_relative "toon_fu/version"
require_relative "toon_fu/encoder"
require_relative "toon_fu/float_literal"
require_relative "toon_fu/decimal_literal"
require_relative "toon_fu/string_literal"
require_relative "toon_fu/normalizer"
require_relative "toon_fu/fields"
require_relative "toon_fu/writer"
require_relative "toon_fu/encodable"

# TOON (Token-Oriented Object Notation) for Ruby.
module ToonFu
  # Raised when a value has no TOON representation; see {Encoder#encode}.
  class Error < StandardError; end

  private_constant :FloatLiteral, :DecimalLiteral, :StringLiteral, :Normalizer, :Fields, :Writer

  # Encodes a value as TOON.
  #
  #   ToonFu.encode("hello")                # => "hello"
  #   ToonFu.encode("a,b")                  # => "\"a,b\""
  #   ToonFu.encode("a,b", delimiter: "|")  # => "a,b"
  #   ToonFu.encode(1e-7)                   # => "1e-7"
  #   ToonFu.encode({user: {id: 1}})        # => "user:\n  id: 1"
  #   ToonFu.encode({tags: ["a", "b"]})     # => "tags[2]: a,b"
  #   ToonFu.encode([{id: 1}, {id: 2}])     # => "[2]{id}:\n  1\n  2"
  #   ToonFu.encode({a: {x: 1}, b: {x: 2}}) # => "[2:]{x}:\n  a: 1\n  b: 2"
  #
  # @param value [Object] see {Encoder#encode} for the accepted types
  # @param options [Hash] see {Encoder#initialize}
  # @return [String]
  # @raise [Error] see {Encoder#encode}
  def self.encode(value, **options)
    Encoder.new(**options).encode(value)
  end
end
