#!/usr/bin/env ruby
# scripts/patterns.rb
# frozen_string_literal: true

require "csv"
require "date"

CSV_PATH = File.expand_path("../data/results/picks.csv", __dir__)
abort "CSV not found: #{CSV_PATH}" unless File.exist?(CSV_PATH)

# Optional YYYY-MM-DD argument
date_arg = ARGV.find { |a| a.match?(/^\d{4}-\d{2}-\d{2}$/) }
target_date = date_arg ? Date.parse(date_arg).to_s : nil

# Probability bands
BANDS = [
  [80, 100],
  [75, 79],
  [70, 74],
  [65, 69],
  [60, 64]
]

# Adaptive minimum samples
MIN_SAMPLES_ALL_TIME = 10
MIN_SAMPLES_DAILY = 1
min_samples = target_date ? MIN_SAMPLES_DAILY : MIN_SAMPLES_ALL_TIME

rows = CSV.table(CSV_PATH)

# stats[pattern_key] = { total:, wins: }
stats = Hash.new { |h, k| h[k] = { total: 0, wins: 0 } }

rows.each do |row|
  # Slice by date if provided
  next if target_date && row[:date] != target_date

  market = row[:market].to_s.strip.upcase
  confidence = row[:confidence].to_s.strip.upcase

  prob =
    case market
    when "BTTS"
      row[:model_btts].to_i
    when "O2.5", "O25"
      row[:model_o25].to_i
    else
      nil
    end

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
  next unless prob

  band = BANDS.find { |low, high| prob >= low && prob <= high }
  next unless band

  band_label = "#{band[0]}–#{band[1]}"
  pattern_key = "#{market} | #{confidence} | #{band_label}"

  stats[pattern_key][:total] += 1
  stats[pattern_key][:wins] += 1 if hit == "W"
end

patterns =
  stats.map do |key, data|
    total = data[:total]
    next if total < min_samples

    wins = data[:wins]
    pct = wins.to_f / total * 100

    {
      key: key,
      total: total,
      wins: wins,
      pct: pct
    }
  end.compact

patterns.sort_by! { |p| [-p[:pct], -p[:total]] }

puts
if target_date
  puts "Recommendation Patterns for #{target_date}"
else
  puts "Recommendation Patterns (All Time)"
end
puts "================================================"

if patterns.empty?
  puts
  puts "No qualifying patterns (min samples: #{min_samples})."
else
  patterns.first(5).each_with_index do |p, idx|
    puts
    puts "#{idx + 1}. #{p[:key]}"
    puts format(
      "   %d picks | %d wins | %.1f%%",
      p[:total],
      p[:wins],
      p[:pct]
    )
  end
end

puts
