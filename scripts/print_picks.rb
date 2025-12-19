#!/usr/bin/env ruby

require "csv"
require "date"

CSV_PATH = File.expand_path("../data/results/picks.csv", __dir__)

abort("picks.csv not found") unless File.exist?(CSV_PATH)

date_arg = ARGV[0]
target_date = date_arg ? Date.parse(date_arg).to_s : nil

rows = CSV.read(CSV_PATH, headers: true)

if target_date
  rows = rows.select { |r| r["date"] == target_date }
end

if rows.empty?
  puts "No picks found#{target_date ? " for #{target_date}" : ""}."
  exit
end

current_date = nil

rows.each_with_index do |r, i|
  if r["date"] != current_date
    current_date = r["date"]
    puts
    puts "Date: #{current_date}"
    puts "-" * 60
  end

  puts "#{i + 1}. #{r['league']} — #{r['match']}"
  puts "   Kickoff:   #{r['kickoff_utc']} UTC"
  puts "   Market:    #{r['market']}"
  puts "   Confidence #{r['confidence']}"
  puts "   Model:     BTTS #{r['model_btts']}% | O2.5 #{r['model_o25']}%"
  puts "   Result:    #{r['result']}"
end
