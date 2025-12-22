#!/usr/bin/env ruby
# scripts/accuracy_by_confidence.rb
# frozen_string_literal: true

require "csv"

CSV_PATH = File.expand_path("../data/results/picks.csv", __dir__)

abort "CSV not found: #{CSV_PATH}" unless File.exist?(CSV_PATH)

rows = CSV.table(CSV_PATH)

# stats[market][confidence] = { total: X, wins: Y }
stats = Hash.new do |h, market|
  h[market] = Hash.new { |h2, conf| h2[conf] = { total: 0, wins: 0 } }
end

CONFIDENCE_ORDER = ["STRONG", "MEDIUM", "PASS"]

rows.each do |row|
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

  # Skip unfinished or invalid rows
  next unless hit == "W" || hit == "L"

  stats[market][confidence][:total] += 1
  stats[market][confidence][:wins] += 1 if hit == "W"
end

puts
puts "Accuracy by Confidence"
puts "======================"

stats.each do |market, confs|
  puts
  puts "Market: #{market}"

  CONFIDENCE_ORDER.each do |confidence|
    next unless confs.key?(confidence)

    data = confs[confidence]
    total = data[:total]
    wins = data[:wins]
    pct = (wins.to_f / total * 100).round(1)

    puts format(
      "  %-7s → %4d picks | %4d wins | %5.1f%%",
      confidence,
      total,
      wins,
      pct
    )
  end
end

puts
