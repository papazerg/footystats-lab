#!/usr/bin/env ruby

require "csv"

CSV_PATH = File.expand_path("../data/results/picks.csv", __dir__)

abort("❌ picks.csv not found") unless File.exist?(CSV_PATH)

stats = Hash.new { |h, k| h[k] = Hash.new { |hh, kk| hh[kk] = [] } }

CSV.foreach(CSV_PATH, headers: true) do |row|
  next unless %w[W L].include?(row["result"])
  next unless %w[STRONG MEDIUM].include?(row["confidence"])

  league     = row["league"]
  confidence = row["confidence"]

  promise = [row["model_btts"].to_i, row["model_o25"].to_i].max
  actual  = row["result"] == "W" ? 100 : 0

  lie = (promise - actual).abs
  stats[league][confidence] << lie
end

puts "🤥 Lie Index by League × Confidence"
puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if stats.empty?
  puts "No graded matches yet"
  exit
end

stats.each do |league, confs|
  puts "\n#{league}"
  confs.each do |conf, lies|
    avg = (lies.sum.to_f / lies.size).round(2)
    puts "  #{conf.ljust(7)} → #{avg} (#{lies.size} picks)"
  end
end
