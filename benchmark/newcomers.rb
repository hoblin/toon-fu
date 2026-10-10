# frozen_string_literal: true

require "json"
require "net/http"

since = ARGV.fetch(0) { abort "usage: ruby benchmark/newcomers.rb <ISO date of our previous release>" }

JSON.parse(Net::HTTP.get(URI("https://rubygems.org/api/v1/search.json?query=toon"))).each do |gem|
  versions = JSON.parse(Net::HTTP.get(URI("https://rubygems.org/api/v1/versions/#{gem["name"]}.json")))
  fresh = versions.select { |version| version["created_at"] > since }
  next if fresh.empty?

  puts "#{gem["name"]} #{fresh.map { |version| version["number"] }.join(", ")} (#{gem["downloads"]} downloads): #{gem["info"].lines.first.strip}"
end
