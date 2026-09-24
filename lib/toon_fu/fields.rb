# frozen_string_literal: true

module ToonFu
  class Fields
    attr_reader :columns

    def self.of(rows)
      return if rows.empty? || !rows.all?(Hash)

      keys = rows.first.keys
      return if keys.empty?
      return unless rows.all? { |row| row.size == keys.size && keys.all? { |key| row.key?(key) } }

      columns = keys.to_h do |key|
        values = rows.map { |row| row[key] }
        next [key, nil] if values.none? { |value| value.is_a?(Hash) || value.is_a?(Array) }

        nested = of(values)
        return nil unless nested

        [key, nested]
      end
      new(columns)
    end

    attr_reader :paths

    def initialize(columns)
      @columns = columns
      @paths = columns.flat_map { |key, nested| nested ? nested.paths.map { |path| [key, *path] } : [[key]] }
    end

    def cells(row)
      @paths.map { |path| path.reduce(row) { |node, key| node[key] } }
    end
  end
end
