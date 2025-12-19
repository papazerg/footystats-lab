#!/usr/bin/env ruby

require "csv"

CSV_PATH = File.expand_path("../data/results/picks.csv", __dir__)

abort("❌ picks.csv not found") unless File.exist?(CSV_PATH)

league_stats = Hash.new { |h, k| h[k] = [] }

CSV.foreach(CSV_PATH, headers: true) do |row|
  next unless %w[W L].include?(row["result"])

  league  = row["league"]
  promise = [row["model_btts"].to_i, row["model_o25"].to_i].max
  actual  = row["result"] == "W" ? 100 : 0

  lie = (promise - actual).abs
  league_stats[league] << lie
end

puts "🤥 League-Specific Lie Index"
puts "━━━━━━━━━━━━━━━━━━━━━━━━━━"

if league_stats.empty?
  puts "No graded matches yet"
  exit
end

league_stats
  .sort_by { |_, lies| lies.sum.to_f / lies.size }
  .each do |league, lies|
    avg = (lies.sum.to_f / lies.size).round(2)
    puts "#{league.ljust(30)} → #{avg}"
  end
