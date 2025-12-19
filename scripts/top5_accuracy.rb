#!/usr/bin/env ruby

require "csv"
require "date"

CSV_PATH = File.expand_path("../data/results/picks.csv", __dir__)

abort("picks.csv not found") unless File.exist?(CSV_PATH)

date_arg = ARGV[0]
abort("Usage: top5_accuracy.rb YYYY-MM-DD") unless date_arg

target_date = Date.parse(date_arg).to_s

rows = CSV.read(CSV_PATH, headers: true)

# Filter graded rows for the date
daily = rows.select do |r|
  r["date"] == target_date && %w[W L].include?(r["result"])
end

if daily.size < 6
  puts "Not enough graded matches for #{target_date}"
  exit
end

# Confidence weight
CONF_WEIGHT = {
  "STRONG" => 3,
  "MEDIUM" => 2,
  "PASS"   => 1
}

# Sort by confidence, model promise, kickoff
sorted = daily.sort_by do |r|
  [
    -CONF_WEIGHT[r["confidence"]],
    -[r["model_btts"].to_i, r["model_o25"].to_i].max,
    r["kickoff_utc"]
  ]
end

top5 = sorted.first(5)
rest = sorted.drop(5)

def accuracy(rows)
  wins = rows.count { |r| r["result"] == "W" }
  ((wins.to_f / rows.size) * 100).round(1)
end

top5_acc = accuracy(top5)
rest_acc = accuracy(rest)
overall_acc = accuracy(daily)

puts "Date: #{target_date}"
puts "--------------------------------"
puts "Top 5 accuracy:     #{top5_acc} (#{top5.count { |r| r['result'] == 'W' }}/5)"
puts "Rest accuracy:      #{rest_acc} (#{rest.count { |r| r['result'] == 'W' }}/#{rest.size})"
puts "Overall accuracy:   #{overall_acc} (#{daily.count { |r| r['result'] == 'W' }}/#{daily.size})"
