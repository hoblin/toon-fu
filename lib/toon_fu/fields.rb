# frozen_string_literal: true

module ToonFu
  class Fields
    include Enumerable

    def self.of(rows)
      new(rows) if tabular?(rows)
    end

    def self.tabular?(rows)
      return false unless rows.all?(Hash)

      keys = rows.first.keys
      !keys.empty? &&
        rows.all? { |row| row.size == keys.size && keys.all? { |key| row.key?(key) } } &&
        keys.all? { |key| column?(rows.map { |row| row[key] }) }
    end

    def self.column?(values)
      values.none? { |value| value.is_a?(Hash) || value.is_a?(Array) } || tabular?(values)
    end

    private_class_method :tabular?, :column?

    def initialize(rows)
      @columns = rows.first.keys.map do |key|
        values = rows.map { |row| row[key] }
        [key, (Fields.new(values) if values.first.is_a?(Hash))]
      end
    end

    def each(&)
      @columns.each(&)
    end

    def cells(row)
      @columns.flat_map { |key, nested| nested ? nested.cells(row[key]) : [row[key]] }
    end
  end
end
