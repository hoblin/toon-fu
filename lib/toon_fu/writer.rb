# frozen_string_literal: true

module ToonFu
  class Writer
    def initialize(delimiter, indent)
      @delimiter = delimiter
      @marker = (delimiter == ",") ? "" : delimiter
      @strings = StringLiteral.new(delimiter)
      @unit = indent
      @indent = ""
      @hyphen = nil
      @lines = []
    end

    def write(value)
      value(value)
      @lines.join("\n")
    end

    private

    def value(value)
      case value
      when Hash then keyed("", value) || object(value)
      when Array then array("", value)
      else line(scalar(value))
      end
    end

    def object(hash)
      hash.each do |key, value|
        name = @strings.key(key.to_s)
        case value
        when Hash
          next if keyed(name, value)

          line("#{name}:")
          nested { object(value) }
        when Array then array(name, value)
        else line("#{name}: #{scalar(value)}")
        end
      end
    end

    def array(name, values)
      listed = name.empty? && @hyphen
      if values.empty? && !listed
        line(name.empty? ? "[]" : "#{name}: []")
      elsif !listed && (fields = Fields.of(values))
        line("#{name}#{header(values, fields)}")
        nested { values.each { |element| line(row(fields.cells(element))) } }
      elsif values.none? { |value| value.is_a?(Hash) || value.is_a?(Array) }
        line("#{name}#{inline(values)}")
      else
        line("#{name}#{header(values)}")
        nested { values.each { |element| item(element) } }
      end
    end

    def keyed(name, hash)
      fields = Fields.of(hash.values) if hash.size >= 2
      return unless fields

      line("#{name}#{header(hash, fields, keyed: true)}")
      nested { hash.each { |key, entry| line("#{@strings.key(key.to_s)}: #{row(fields.cells(entry))}") } }
    end

    def item(element)
      @hyphen = @indent
      case element
      when Array then array("", element)
      when Hash then nested { object(element) }
      else line(scalar(element))
      end
      return unless @hyphen

      @lines << "#{@hyphen}-"
      @hyphen = nil
    end

    def inline(values)
      return header(values) if values.empty?

      "#{header(values)} #{row(values)}"
    end

    def row(values)
      values.map { |value| scalar(value) }.join(@delimiter)
    end

    def header(values, fields = nil, keyed: false)
      "[#{values.size}#{":" if keyed}#{@marker}]#{field_list(fields) if fields}:"
    end

    def field_list(fields)
      names = fields.columns.map { |key, nested| "#{@strings.key(key.to_s)}#{field_list(nested) if nested}" }
      "{#{names.join(@delimiter)}}"
    end

    def line(text)
      if @hyphen
        @lines << "#{@hyphen}- #{text}"
        @hyphen = nil
      else
        @lines << "#{@indent}#{text}"
      end
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
