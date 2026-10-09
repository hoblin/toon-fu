# frozen_string_literal: true

module ToonFu
  class Line
    ITEM = /\A-(?: +|\z)/

    attr_reader :content, :depth, :number, :text

    attr_reader :after_blank

    def initialize(content, depth, number, text = content, after_blank = false)
      @content = content
      @depth = depth
      @number = number
      @text = text
      @after_blank = after_blank
    end

    def item?
      ITEM.match?(@content)
    end

    def item_content
      @content.sub(ITEM, "")
    end
  end

  class Lines
    BOM = "\u{feff}"
    COMMENT = /\A *#/
    TRAILING_SPACES = / +\z/
    INDENTATION = /\A[ \t]*/
    BLANK_WITH_TABS = /\A[ \t]*\z/

    def initialize(text, strict, indent_size)
      @strict = strict
      @indent_size = indent_size
      @lines = significant(text.delete_prefix(BOM))
      @index = 0
    end

    def empty?
      @index >= @lines.length
    end

    def one?
      @lines.length - @index == 1
    end

    def peek
      @lines[@index]
    end

    def next
      line = @lines[@index]
      @index += 1
      line
    end

    def number
      peek ? peek.number : @lines.length
    end

    private

    def significant(text)
      blank = false
      text.split("\n", -1).each_with_index.filter_map do |raw, offset|
        line = raw.delete_suffix("\r").sub(TRAILING_SPACES, "")
        next if COMMENT.match?(line)

        if blank?(line)
          blank = true
          next
        end

        built = build(line, offset + 1, blank)
        blank = false
        built
      end
    end

    def blank?(line)
      @strict ? line.empty? : BLANK_WITH_TABS.match?(line)
    end

    def build(line, number, blank)
      Line.new(line.sub(INDENTATION, ""), depth(line, number), number, line, blank)
    end

    # Non-strict mode accepts a tab as indentation (§12), where each tab
    # counts as one level; strict mode rejects it.
    def depth(line, number)
      indent = line[INDENTATION]
      raise Error, "cannot decode a line indented with a tab on line #{number}: #{line}" if @strict && indent.include?("\t")

      spaces = indent.count(" ")
      raise Error, "cannot decode an indentation of #{spaces} spaces on line #{number}, not a multiple of #{@indent_size}: #{line}" if @strict && !(spaces % @indent_size).zero?

      spaces / @indent_size + indent.count("\t")
    end
  end
end
