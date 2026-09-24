# frozen_string_literal: true

module ToonFu
  class StringLiteral
    AMBIGUOUS = /\A(?:true|false|null|[+-]?[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)\z/
    ESCAPES = {"\\" => "\\\\", '"' => '\\"', "\n" => "\\n", "\r" => "\\r", "\t" => "\\t"}.freeze
    ESCAPABLE = /["\\\x00-\x1f]/

    def initialize(delimiter)
      @unsafe = /\A[ \t#-]|[ \t]\z|[:"\\\[\]{}\x00-\x1f#{Regexp.escape(delimiter)}]/
    end

    def encode(string)
      quote?(string) ? %("#{escape(string)}") : string
    end

    private

    def quote?(string)
      string.empty? || AMBIGUOUS.match?(string) || @unsafe.match?(string)
    end

    def escape(string)
      string.gsub(ESCAPABLE) { |char| ESCAPES.fetch(char) { format("\\u%04x", char.ord) } }
    end
  end
end
