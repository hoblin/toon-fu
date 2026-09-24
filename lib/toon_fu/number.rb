# frozen_string_literal: true

module ToonFu
  class Number
    DECIMAL_RANGE = (1e-6...1e21)

    def initialize(value)
      @value = value
    end

    def to_s
      return @value.to_s if @value.is_a?(Integer)
      return "0" if @value.zero?
      return @value.to_i.to_s if @value.abs < 1e21 && @value == @value.truncate

      DECIMAL_RANGE.cover?(@value.abs) ? decimal : exponential
    end

    private

    def decimal
      digits, point = significand
      text =
        if point <= 0
          "0.#{"0" * -point}#{digits}"
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
