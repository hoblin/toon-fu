# frozen_string_literal: true

module ToonFu
  # Adds +to_toon+ to the core and standard-library classes TOON encodes.
  # +BigDecimal+ is left out: it is a bundled gem the encoder accepts but
  # does not load. Include this module into a class that defines +as_toon+
  # to give that class +to_toon+ as well.
  module Encodable
    # @param options [Hash] see {Encoder#initialize}
    # @return [String] the receiver encoded as TOON, as {ToonFu.encode} would
    # @raise [Error] see {Encoder#encode}
    def to_toon(**options)
      ToonFu.encode(self, **options)
    end
  end

  [Hash, Array, Set, String, Symbol, Integer, Float, TrueClass, FalseClass, NilClass, Time, Date].each do |klass|
    klass.include(Encodable)
  end
end
