#!/usr/bin/env ruby
# scripts/top5_accuracy.rb
# frozen_string_literal: true

require "csv"
require "date"

CSV_PATH = File.expand_path("../data/results/picks.csv", __dir__)

abort "CSV not found: #{CSV_PATH}" unless File.exist?(CSV_PATH)

# Optional date argument
date_arg = ARGV.find { |a| a.match?(/^\d{4}-\d{2}-\d{2}$/) }
target_date = date_arg ? Date.parse(date_arg).to_s : nil

rows = CSV.table(CSV_PATH)

# stats[market][pattern] = { total: X, wins: Y }
# pattern here is confidence (can be expanded later)
stats = Hash.new do |h, market|
  h[market] = Hash.new { |h2, pattern| h2[pattern] = { total: 0, wins: 0 } }
end

rows.each do |row|
  # If a date is provided, only include that day's recommendations
  next if target_date && row[:date] != target_date

  market = row[:market].to_s.strip.upcase
  confidence = row[:confidence].to_s.strip.upcase

  hit =
    case market
    when "BTTS"
      row[:btts_result]
    when "O2.5", "O25"
      row[:o25_result]
    else
      nil
    end

  # Skip unfinished rows
  next unless hit == "W" || hit == "L"

  stats[market][confidence][:total] += 1
  stats[market][confidence][:wins] += 1 if hit == "W"
end

puts
if target_date
  puts "Top Accuracy for #{target_date}"
else
  puts "Top Accuracy (All Time)"
end
puts "========================"

stats.each do |market, patterns|
  ranked =
    patterns.map do |pattern, data|
      total = data[:total]
      next if total.zero?

      wins = data[:wins]
      pct = wins.to_f / total * 100

      {
        pattern: pattern,
        total: total,
        wins: wins,
        pct: pct
      }
    end.compact

  ranked.sort_by! { |r| [-r[:pct], -r[:total]] }

  puts
  puts "Market: #{market}"

  ranked.first(5).each_with_index do |r, idx|
    puts format(
      "  %d. %-7s → %4d picks | %4d wins | %5.1f%%",
      idx + 1,
      r[:pattern],
      r[:total],
      r[:wins],
      r[:pct]
    )
  end
end

puts
