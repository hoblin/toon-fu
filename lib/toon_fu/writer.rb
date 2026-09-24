# frozen_string_literal: true

module ToonFu
  class Writer
    def initialize(delimiter, indent)
      @delimiter = delimiter
      @marker = (delimiter == ",") ? "" : delimiter
      @strings = StringLiteral.new(delimiter)
      @unit = indent
      @indent = ""
      @lines = []
    end

    def write(value)
      case value
      when Hash then object(value)
      when Array then array("", value)
      else @lines << scalar(value)
      end
      @lines.join("\n")
    end

    private

    def object(hash)
      hash.each do |key, value|
        name = @strings.key(key.to_s)
        case value
        when Hash
          line("#{name}:")
          nested { object(value) }
        when Array then array(name, value)
        else line("#{name}: #{scalar(value)}")
        end
      end
    end

    def array(name, values)
      if values.empty?
        line(name.empty? ? "[]" : "#{name}: []")
      elsif (fields = Fields.of(values))
        line("#{name}#{header(values, fields)}")
        nested { values.each { |element| line(row(fields.cells(element))) } }
      elsif values.all?(Array)
        line("#{name}#{header(values)}")
        nested { values.each { |inner| line("- #{inline(inner)}") } }
      else
        line("#{name}#{inline(values)}")
      end
    end

    def inline(values)
      return header(values) if values.empty?

      "#{header(values)} #{row(values)}"
    end

    def row(values)
      values.map { |value| scalar(value) }.join(@delimiter)
    end

    def header(values, fields = nil)
      "[#{values.size}#{@marker}]#{field_list(fields) if fields}:"
    end

    def field_list(fields)
      names = fields.columns.map { |key, nested| "#{@strings.key(key.to_s)}#{field_list(nested) if nested}" }
      "{#{names.join(@delimiter)}}"
    end

    def line(text)
      @lines << "#{@indent}#{text}"
    end

    def nested
      outer = @indent
      @indent += @unit
      yield
    ensure
      @indent = outer
    end

    def scalar(value)
      case value
      when nil then "null"
      when true, false, Integer then value.to_s
      when Float then FloatLiteral.new(value).to_s
      when String then @strings.encode(value)
      else raise Error, "cannot encode #{value.class}"
      end
    end
  end
end
