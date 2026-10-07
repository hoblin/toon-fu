# frozen_string_literal: true

module ToonFu
  class FieldList
    def self.parse(text, delimiter)
      new(text, delimiter).parse
    end

    def initialize(text, delimiter)
      @text = text
      @delimiter = delimiter
    end

    def parse
      return nil if @text.empty?

      entries = []
      Tokens.split_fields(@text, @delimiter).each do |entry|
        return nil if foreign?(entry)

        name, nested = split(entry)
        return nil if name.nil?

        entries << [name, nested]
      end
      entries
    end

    private

    # A field list is split by the bracket segment's delimiter alone, so
    # another delimiter left unquoted in an entry is a header defect (§6).
    # Quoting protects it, which is how the encoder emits {id,"a|b"}.
    def foreign?(entry)
      others = Encoder::DELIMITERS - [@delimiter]
      Tokens.index_of(entry, Tokens::UNTIL_FOREIGN.fetch(@delimiter), others.join) ? true : false
    end

    def split(entry)
      entry = Tokens.trim(entry)
      return [nil, nil] if entry.empty?

      brace = Tokens.brace_index(entry)
      return [Token.key(entry), nil] if brace.nil?

      name = entry[0...brace]
      return [nil, nil] if name.empty? || name.match?(Tokens::TRAILING_WHITESPACE)

      group = entry[brace..]
      closing = Tokens.closing_brace(group)
      return [nil, nil] unless closing == group.length - 1

      nested = self.class.parse(group[1...closing], @delimiter)
      nested.nil? ? [nil, nil] : [Token.key(name), nested]
    end
  end
end
