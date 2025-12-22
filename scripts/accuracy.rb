#!/usr/bin/env ruby
# scripts/accuracy.rb
# frozen_string_literal: true

require "csv"
require "date"

CSV_PATH = File.expand_path("../data/results/picks.csv", __dir__)
abort "CSV not found: #{CSV_PATH}" unless File.exist?(CSV_PATH)

# Optional YYYY-MM-DD argument
date_arg = ARGV.find { |a| a.match?(/^\d{4}-\d{2}-\d{2}$/) }
target_date = date_arg ? Date.parse(date_arg).to_s : nil

rows = CSV.table(CSV_PATH)

total = 0
wins = 0

rows.each do |row|
  # Slice by date if provided
  next if target_date && row[:date] != target_date

  market = row[:market].to_s.strip.upcase

  hit =
    case market
    when "BTTS"
      row[:btts_result]
    when "O2.5", "O25"
      row[:o25_result]
    else
      nil
    end

  # Only finished rows
  next unless hit == "W" || hit == "L"

  total += 1
  wins += 1 if hit == "W"
end

puts

if total.zero?
  label = target_date ? "accuracy for #{target_date}" : "accuracy"
  puts "#{label}: n/a (0/0)"
else
  pct = (wins.to_f / total * 100).round(1)

  label = target_date ? "accuracy for #{target_date}" : "accuracy"
  puts "#{label}: #{pct}% (#{wins}/#{total})"
end

puts
