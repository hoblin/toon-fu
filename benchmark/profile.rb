# frozen_string_literal: true

require "bundler/setup"
require "memory_profiler"
require "stackprof"
require "toon_fu"
require_relative "workloads"

title = ARGV.first || "table, 1000 rows"
value = WORKLOADS.fetch(title) { abort "unknown workload #{title.inspect}; one of: #{WORKLOADS.keys.join(", ")}" }
ToonFu.encode(value)

puts "CPU, #{title}"
profile = StackProf.run(mode: :cpu, interval: 10, raw: true) { 50.times { ToonFu.encode(value) } }
StackProf::Report.new(profile).print_text(false, 15)

report = MemoryProfiler.report { ToonFu.encode(value) }
puts "\nAllocations per encode: #{report.total_allocated}"
report.allocated_objects_by_location.first(10).each do |site|
  puts format("  %6d  %s", site[:count], site[:data].delete_prefix("#{File.expand_path("..", __dir__)}/"))
end
