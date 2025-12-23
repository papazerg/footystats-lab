#!/usr/bin/env ruby
# scripts/update_results_debug.rb
# frozen_string_literal: true

ENV["TZ"] = "UTC"

require "date"
require "csv"
require "dotenv/load"
require "pp"

require_relative "../lib/footystats"

def usage!
  puts "Usage: ruby scripts/update_results_debug.rb YYYY-MM-DD"
  exit 1
end

date_str = ARGV.find { |a| a.match?(/^\d{4}-\d{2}-\d{2}$/) }
usage! unless date_str

target_date = Date.parse(date_str).to_s

csv_path = File.expand_path("../data/results/picks.csv", __dir__)
abort "CSV not found: #{csv_path}" unless File.exist?(csv_path)

rows = CSV.table(csv_path)

client = FootyStats.new

row = rows.find { |r| r[:date].to_s == target_date }

abort "No rows found for #{target_date}" unless row

match_id = row[:match_id]
abort "Row missing match_id" unless match_id

puts
puts "Inspecting API response for:"
puts "  Date:     #{row[:date]}"
puts "  Match:    #{row[:match]}"
puts "  Match ID: #{match_id}"
puts

begin
  response = client.match(match_id: match_id)
rescue StandardError => e
  puts "API ERROR:"
  puts "#{e.class}: #{e.message}"
  exit 1
end

puts "=== RAW API RESPONSE ==="
pp response
puts "=== END RESPONSE ==="
puts

exit 0
