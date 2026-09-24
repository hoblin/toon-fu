# frozen_string_literal: true

require "bundler/setup"
require "benchmark/ips"
require "json"
require "toon_fu"
require "toon"
require "sorbet/toon"
require "toon_my_json"
require "toon_format"

ENCODERS = {
  "toon-fu" => ->(value) { ToonFu.encode(value) },
  "toon-ruby" => ->(value) { Toon.encode(value) },
  "sorbet-toon" => ->(value) { Sorbet::Toon.encode(value) },
  "toon_my_json" => ->(value) { ToonMyJson.encode(value) },
  "toon-format" => ->(value) { ToonFormat.encode(value) }
}.freeze

FIXTURES = Dir[File.expand_path("../spec/toon-spec/tests/fixtures/encode/*.json", __dir__)].sort.flat_map do |path|
  JSON.parse(File.read(path)).fetch("tests").reject { |test| test["options"] }
end

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

puts "Spec conformance: #{FIXTURES.size} encode fixtures of spec #{ToonFu::VERSION[/\A\d+\.\d+/]} that use default options"
ENCODERS.each do |name, encode|
  passed = FIXTURES.count do |fixture|
    encode.call(fixture["input"]) == fixture["expected"]
  rescue
    false
  end
  puts format("  %-14s %3d / %d", name, passed, FIXTURES.size)
end

WORKLOADS.each do |title, value|
  puts "\n#{title}"
  Benchmark.ips do |x|
    x.config(time: 2, warmup: 1)
    ENCODERS.each do |name, encode|
      encode.call(value)
      x.report(name) { encode.call(value) }
    rescue => error
      puts "  #{name}: #{error.class}"
    end
    x.compare!
  end
end
