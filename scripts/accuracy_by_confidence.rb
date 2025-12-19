#!/usr/bin/env ruby

require "csv"

CSV_PATH = File.expand_path("../data/results/picks.csv", __dir__)

abort("❌ picks.csv not found") unless File.exist?(CSV_PATH)

stats = Hash.new { |h, k| h[k] = { wins: 0, losses: 0 } }

CSV.foreach(CSV_PATH, headers: true) do |row|
  next unless %w[W L].include?(row["result"])
  next unless %w[STRONG MEDIUM].include?(row["confidence"])

  if row["result"] == "W"
    stats[row["confidence"]][:wins] += 1
  else
    stats[row["confidence"]][:losses] += 1
  end
end

puts "🎯 Accuracy by Confidence"
puts "━━━━━━━━━━━━━━━━━━━━━━"

stats.each do |confidence, s|
  total = s[:wins] + s[:losses]
  accuracy = (s[:wins].to_f / total * 100).round(2)
  puts "#{confidence.ljust(7)} → #{accuracy}% (#{s[:wins]}/#{total})"
end
