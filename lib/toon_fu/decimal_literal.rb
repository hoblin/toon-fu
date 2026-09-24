# frozen_string_literal: true

module ToonFu
  class DecimalLiteral
    def initialize(value)
      @value = value
    end

    def to_s
      return "null" unless @value.finite?
      return "0" if @value.zero?
      return @value.to_s("F").delete_suffix(".0") if FloatLiteral::DECIMAL_RANGE.cover?(@value.abs)

      sign, digits, _base, exponent = @value.split
      mantissa = (digits.size > 1) ? "#{digits[0]}.#{digits[1..]}" : digits
      "#{"-" if sign.negative?}#{mantissa}e#{format("%+d", exponent - 1)}"
    end
  end
end
