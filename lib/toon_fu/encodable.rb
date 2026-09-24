# frozen_string_literal: true

module ToonFu
  # Adds +to_toon+ to the core classes TOON encodes. Include it into a class
  # that defines +as_toon+ to give that class +to_toon+ as well.
  module Encodable
    # @param options [Hash] see {Encoder#initialize}
    # @return [String] the receiver encoded as TOON, as {ToonFu.encode} would
    # @raise [Error] see {Encoder#encode}
    def to_toon(**options)
      ToonFu.encode(self, **options)
    end
  end

  [Hash, Array, Set, String, Symbol, Integer, Float, TrueClass, FalseClass, NilClass, Time].each do |klass|
    klass.include(Encodable)
  end
end
