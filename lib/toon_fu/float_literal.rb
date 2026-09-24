# frozen_string_literal: true

module ToonFu
  class FloatLiteral
    DECIMAL_RANGE = (1e-6...1e21)

    def self.format(value)
      plain = value.to_s
      return new(value).to_s if plain.include?("e") || !value.finite?

      value.zero? ? "0" : plain.delete_suffix(".0")
    end

    def initialize(value)
      @value = value
    end

    def to_s
      return "null" unless @value.finite?
      return "0" if @value.zero?

      DECIMAL_RANGE.cover?(@value.abs) ? decimal : exponential
    end

    private

    def decimal
      plain = @value.to_s
      return plain.delete_suffix(".0") unless plain.include?("e")

      digits, point = significand
      text =
        if point <= 0
          "0.#{"0" * -point}#{digits}"
        elsif point >= digits.length
          digits.ljust(point, "0")
        else
          "#{digits[0, point]}.#{digits[point..]}"
        end
      sign + text
    end

    def exponential
      mantissa, exponent = @value.abs.to_s.split("e")
      "#{sign}#{mantissa.delete_suffix(".0")}e#{format("%+d", exponent.to_i)}"
    end

    def significand
      mantissa, exponent = @value.abs.to_s.split("e")
      whole, fraction = mantissa.split(".")
      fraction = "" if fraction == "0"
      [whole + fraction, whole.length + exponent.to_i]
    end

    def sign
      @value.negative? ? "-" : ""
    end
  end
end
