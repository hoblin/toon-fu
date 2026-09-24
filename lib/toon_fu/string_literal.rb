# frozen_string_literal: true

module ToonFu
  class StringLiteral
    READS_AS_LITERAL = /\A(?:true|false|null|[+-]?[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)\z/
    UNSAFE = Encoder::DELIMITERS.to_h do |delimiter|
      [delimiter, /\A[ \t#-]|[ \t]\z|[:"\\\[\]{}\x00-\x1f#{Regexp.escape(delimiter) if delimiter.ord > 0x1f}]/]
    end.freeze
    BARE_KEY = /\A[A-Za-z_][A-Za-z0-9_.]*\z/
    ESCAPABLE = /["\\\x00-\x1f]/
    ESCAPES = (0x00..0x1f).to_h { |code| [code.chr, format("\\u%04x", code)] }
      .merge("\\" => "\\\\", '"' => '\\"', "\n" => "\\n", "\r" => "\\r", "\t" => "\\t").freeze

    def initialize(delimiter)
      @unsafe = UNSAFE.fetch(delimiter)
    end

    def encode(string)
      quote?(string) ? quote(string) : string
    end

    def key(string)
      BARE_KEY.match?(string) ? string : quote(string)
    end

    private

    def quote(string)
      %("#{string.gsub(ESCAPABLE, ESCAPES)}")
    end

    def quote?(string)
      string.empty? || READS_AS_LITERAL.match?(string) || @unsafe.match?(string)
    end
  end
end
