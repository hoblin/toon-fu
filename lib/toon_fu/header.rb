# frozen_string_literal: true

module ToonFu
  class Header
    LENGTH = /\A(?:0|[1-9][0-9]*)\z/
    DELIMITERS = {"" => ",", "\t" => "\t", "|" => "|"}.freeze

    attr_reader :key, :length, :delimiter, :fields, :inline

    def self.parse(content)
      bracket = Tokens.bracket_index(content)
      return nil if bracket.nil?

      new(content, bracket).parse
    end

    def initialize(content, bracket)
      @content = content
      @bracket = bracket
      @malformed = false
    end

    # A line carrying a bracket segment is either a header, or an attempt at
    # one that §6 makes a strict-mode error; only a line without one falls
    # through to the key-value class untouched.
    def malformed?
      @malformed
    end

    def parse
      @key = @bracket.zero? ? nil : @content[0...@bracket]
      return nil unless @key.nil? || Tokens.whole_token?(@key)
      return broken if @key&.match?(/\s\z/)
      return broken unless (closing = @content.index("]", @bracket))

      return broken unless segment(@content[(@bracket + 1)...closing])
      return broken unless tail(closing + 1)
      # §6: a keyed header's field list is required, and a fields-bearing
      # header carries no inline content.
      return broken if @keyed && !fields?
      return broken if fields? && !@inline.strip.empty?

      self
    end

    def broken
      @malformed = true
      self
    end

    def keyed?
      @keyed
    end

    def fields?
      !@fields.nil?
    end

    def leaves
      @leaves ||= walk(@fields)
    end

    # Names repeated across nesting levels are not duplicates (§9.3): only a
    # repeat within one list counts.
    def duplicate
      return @duplicate if defined?(@duplicate)

      @duplicate = repeated(@fields)
    end

    private

    def segment(text)
      @keyed = false
      if text.end_with?(":")
        @keyed = true
        text = text[0...-1]
      elsif (marker = text[-1]) && DELIMITERS.key?(marker) && !marker.empty?
        @delimiter = DELIMITERS.fetch(marker)
        text = text[0...-1]
        if text.end_with?(":")
          @keyed = true
          text = text[0...-1]
        end
      end
      @delimiter ||= ","
      return false unless LENGTH.match?(text)

      @length = Integer(text, 10)
      true
    end

    def tail(index)
      rest = @content[index..]
      if rest.start_with?("{")
        closing = Tokens.closing_brace(rest)
        return false if closing.nil?

        @fields = FieldList.parse(rest[1...closing], @delimiter)
        return false if @fields.nil?

        rest = rest[(closing + 1)..]
      end
      return false unless rest.start_with?(":")

      @inline = rest[1..]
      true
    end

    def walk(fields)
      fields.flat_map { |name, nested| nested ? walk(nested) : [name] }
    end

    def repeated(fields)
      names = fields.map(&:first)
      duplicate = names.find { |name| names.count(name) > 1 }
      return duplicate if duplicate

      fields.filter_map { |_, nested| nested && repeated(nested) }.first
    end
  end
end
