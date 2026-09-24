# frozen_string_literal: true

require "bundler/setup"
require "benchmark/ips"
require "json"
require "toon_fu"
require "toon"
require "sorbet/toon"
require "toon_my_json"
require "toon_format"
require_relative "workloads"

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

puts "Spec conformance: #{FIXTURES.size} encode fixtures of spec #{ToonFu::VERSION[/\A\d+\.\d+/]} that use default options"
ENCODERS.each do |name, encode|
  passed = FIXTURES.count do |fixture|
    encode.call(fixture["input"]) == fixture["expected"]
  rescue
    false
  end
  puts format("  %-14s %3d / %d", name, passed, FIXTURES.size)
end

speeds = Hash.new { |hash, name| hash[name] = [] }
WORKLOADS.each do |title, value|
  puts "\n#{title}"
  report = Benchmark.ips do |x|
    x.config(time: 2, warmup: 1)
    ENCODERS.each do |name, encode|
      encode.call(value)
      x.report(name) { encode.call(value) }
    rescue => error
      puts "  #{name}: #{error.class}"
    end
    x.compare!
  end
  baseline = report.entries.find { |entry| entry.label == "toon-fu" }.ips
  report.entries.each { |entry| speeds[entry.label] << entry.ips / baseline }
end

puts "\nSpeed relative to toon-fu, geometric mean over #{WORKLOADS.size} workloads"
speeds.each do |name, ratios|
  puts format("  %-14s %.2fx", name, ratios.map { |ratio| Math.log(ratio) }.sum.then { |sum| Math.exp(sum / ratios.size) })
end
