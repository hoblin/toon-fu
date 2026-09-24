# frozen_string_literal: true

module ToonFu
  class DecimalLiteral
    def initialize(value)
      @value = value
    end

    def to_s
      return "null" unless @value.finite?
      return "0" if @value.zero?

      @value.to_s("F").delete_suffix(".0")
    end
  end
end
