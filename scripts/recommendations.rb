#!/usr/bin/env ruby

require "csv"
require "date"

CSV_PATH = File.expand_path("../data/results/picks.csv", __dir__)

abort("picks.csv not found") unless File.exist?(CSV_PATH)

date_arg = ARGV[0]
target_date = date_arg ? Date.parse(date_arg) : Date.today

puts "Recommendations for #{target_date} (UTC)"
puts "----------------------------------------"

rows = CSV.read(CSV_PATH, headers: true)

filtered = rows.select do |r|
  r["date"] == target_date.to_s &&
    %w[STRONG MEDIUM].include?(r["confidence"])
end

if filtered.empty?
  puts "No STRONG or MEDIUM recommendations for this date."
  exit
end

filtered
  .sort_by { |r| r["confidence"] == "STRONG" ? 0 : 1 }
  .each_with_index do |r, i|
    puts
    puts "#{i + 1}. #{r['match']}"
    puts "   Kickoff: #{r['kickoff_utc']} UTC"
    puts "   Market:  #{r['market']}"
    puts "   Tier:    #{r['confidence']}"
    puts "   Model:   BTTS #{r['model_btts']}% | O2.5 #{r['model_o25']}%"
  end
