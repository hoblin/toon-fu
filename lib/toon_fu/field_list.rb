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
        name, nested = split(entry)
        return nil if name.nil? || foreign?(name)

        entries << [name, nested]
      end
      entries
    end

    private

    # A field list is split by the bracket segment's delimiter alone, so
    # another delimiter left unquoted in a name is a header defect (§6).
    def foreign?(name)
      (Encoder::DELIMITERS - [@delimiter]).any? { |other| name.include?(other) }
    end

    def split(entry)
      brace = Tokens.brace_index(entry)
      return [Tokens.key(entry), nil] if brace.nil?

      name = entry[0...brace]
      group = entry[brace..]
      closing = Tokens.closing_brace(group)
      return [nil, nil] unless closing == group.length - 1

      nested = self.class.parse(group[1...closing], @delimiter)
      nested.nil? ? [nil, nil] : [Tokens.key(name), nested]
    end
  end
end
