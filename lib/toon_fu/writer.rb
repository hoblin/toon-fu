# frozen_string_literal: true

module ToonFu
  class Writer
    def initialize(strings, indent)
      @strings = strings
      @unit = indent
      @indent = ""
      @lines = []
    end

    def write(value)
      value.is_a?(Hash) ? object(value) : @lines << scalar(value)
      @lines.join("\n")
    end

    private

    def object(hash)
      hash.each do |key, value|
        field = "#{@strings.key(key.to_s)}:"
        if value.is_a?(Hash)
          line(field)
          nested { object(value) }
        else
          line("#{field} #{scalar(value)}")
        end
      end
    end

    def line(text)
      @lines << "#{@indent}#{text}"
    end

    def nested
      outer = @indent
      @indent += @unit
      yield
    ensure
      @indent = outer
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
