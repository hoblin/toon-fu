# frozen_string_literal: true

module ToonFu
  class Normalizer
    def initialize
      @path = {}.compare_by_identity
    end

    def call(value)
      return plain(value) unless value.respond_to?(:as_toon)

      converted = value.as_toon
      raise Error, "#{value.class}#as_toon returned the object itself" if converted.equal?(value)

      call(converted)
    end

    private

    def plain(value)
      case value
      when nil, true, false, Integer, Float then value
      when String then utf8(value)
      when Symbol then utf8(value.name)
      when Hash then within(value) { object(value) }
      when Array, Set then within(value) { value.map { |element| call(element) } }
      when Time then timestamp(value)
      else host(value)
      end
    end

    def host(value)
      if defined?(DateTime) && value.is_a?(DateTime) then timestamp(value.to_time)
      elsif defined?(Date) && value.is_a?(Date) then value.iso8601
      elsif defined?(BigDecimal) && value.is_a?(BigDecimal) then DecimalLiteral.new(value)
      elsif value.respond_to?(:to_hash) then within(value) { call(value.to_hash) }
      elsif value.respond_to?(:to_ary) then within(value) { call(value.to_ary) }
      elsif value.respond_to?(:to_str) then call(value.to_str)
      else raise Error, "cannot encode #{value.class}; convert it first or define #as_toon"
      end
    end

    def object(hash)
      hash.each_with_object({}) do |(key, value), result|
        name = key(key)
        raise Error, "duplicate key #{name.inspect} after converting keys to strings" if result.key?(name)

        result[name] = call(value)
      end
    end

    def key(key)
      case key
      when String then utf8(key)
      when Symbol then utf8(key.name)
      when Integer then key.to_s
      else raise Error, "cannot encode a #{key.class} key; use String, Symbol or Integer keys"
      end
    end

    def within(container)
      raise Error, "cannot encode a circular reference" if @path.key?(container)

      @path[container] = true
      result = yield
      @path.delete(container)
      result
    end

    def timestamp(time)
      time.iso8601(9).sub(/\.?0+(?=Z|[+-]\d\d:\d\d\z)/, "")
    end

    def utf8(string)
      string = string.dup.force_encoding(Encoding::UTF_8) if string.encoding == Encoding::BINARY
      string = string.encode(Encoding::UTF_8) unless string.encoding == Encoding::UTF_8
      raise Error, "cannot encode a string that is not valid UTF-8: #{string.inspect}" unless string.valid_encoding?

      string
    rescue EncodingError => error
      raise Error, "cannot encode a string as UTF-8: #{error.message}"
    end
  end
end
