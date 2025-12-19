#!/usr/bin/env ruby

require "csv"

CSV_PATH = File.expand_path("../data/results/picks.csv", __dir__)

abort("❌ picks.csv not found") unless File.exist?(CSV_PATH)

total_lie = 0
count = 0
by_confidence = Hash.new { |h, k| h[k] = [] }

CSV.foreach(CSV_PATH, headers: true) do |row|
  next unless %w[W L].include?(row["result"])

  promise = [row["model_btts"].to_i, row["model_o25"].to_i].max
  actual  = row["result"] == "W" ? 100 : 0

  lie = (promise - actual).abs

  total_lie += lie
  count += 1

  by_confidence[row["confidence"]] << lie
end

puts "🤥 Lie Index Report"
puts "━━━━━━━━━━━━━━━━━━"

if count.zero?
  puts "No graded matches yet"
  exit
end

puts "Overall Lie Index: #{(total_lie.to_f / count).round(2)}"

puts "\nBy Confidence:"
by_confidence.each do |conf, lies|
  avg = (lies.sum.to_f / lies.size).round(2)
  puts "#{conf.ljust(7)} → #{avg}"
end
