# frozen_string_literal: true

module ToonFu
  class Normalizer
    TRAILING_FRACTION_ZEROS = /\.?0+\z/

    def initialize
      @path = {}.compare_by_identity
    end

    def call(value)
      raise Error, "cannot encode a BasicObject" unless Kernel === value
      return core(value) unless value.respond_to?(:as_toon)

      within(value) { call(value.as_toon) }
    end

    private

    def core(value)
      case value
      when nil, true, false, Integer, Float then value
      when String then utf8(value)
      when Symbol then utf8(value.name)
      when Hash then within(value) { object(value) }
      when Array, Set then within(value) { value.map { |element| call(element) } }
      when Time then timestamp(value)
      when DateTime then date_time(value)
      when Date then value.iso8601
      else convert(value)
      end
    end

    def convert(value)
      if defined?(BigDecimal) && value.is_a?(BigDecimal) then DecimalLiteral.new(value)
      elsif value.respond_to?(:to_hash) then within(value) { call(value.to_hash) }
      elsif value.respond_to?(:to_ary) then within(value) { call(value.to_ary) }
      elsif value.respond_to?(:to_str) then within(value) { call(value.to_str) }
      else raise Error, "cannot encode #{value.class}; convert it first or define #as_toon"
      end
    end

    def object(hash)
      hash.each_with_object({}) do |(key, value), result|
        name = key_name(key)
        raise Error, "duplicate key #{name.inspect} after converting keys to strings" if result.key?(name)

        result[name] = call(value)
      end
    end

    def key_name(key)
      case key
      when String then utf8(key)
      when Symbol then utf8(key.name)
      when Integer then key.to_s
      else raise Error, "cannot encode #{key.class} keys; use String, Symbol or Integer keys"
      end
    end

    def within(container)
      raise Error, "cannot encode a circular reference through #{container.class}" if @path.key?(container)

      @path[container] = true
      result = yield
      @path.delete(container)
      result
    end

    def timestamp(time)
      moment = time.strftime("%Y-%m-%dT%H:%M:%S.%9N").sub(TRAILING_FRACTION_ZEROS, "")
      "#{moment}#{time.utc? ? "Z" : time.strftime("%:z")}"
    end

    def date_time(value)
      moment, offset = value.iso8601(9).split(/(?=[+-]\d\d:\d\d\z)/)
      "#{moment.sub(TRAILING_FRACTION_ZEROS, "")}#{offset}"
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
