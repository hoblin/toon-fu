# frozen_string_literal: true

def users(count)
  Array.new(count) do |i|
    {"id" => i, "name" => "user #{i}", "email" => "user#{i}@example.com", "active" => i.even?, "score" => i * 1.5,
     "geo" => {"lat" => 60.17 + i / 1000.0, "lon" => 24.94}}
  end
end

WORKLOADS = {
  "table, 100 rows" => {"users" => users(100)},
  "table, 1000 rows" => {"users" => users(1000)},
  "nested objects" => {"config" => {"db" => {"host" => "localhost", "port" => 5432, "pool" => {"min" => 1, "max" => 10}},
                                    "cache" => {"ttl" => 300, "keys" => ["a", "b", "c"]}}},
  "list of mixed objects" => {"items" => Array.new(100) { |i| i.even? ? {"id" => i, "tags" => ["x", "y"]} : {"id" => i, "note" => "n: #{i}"} }},
  "strings needing quotes" => {"values" => Array.new(200) { |i| ["plain", "a,b", "#tag", "+1", "true", "line\nbreak", "42", " pad "][i % 8] }}
}.freeze
