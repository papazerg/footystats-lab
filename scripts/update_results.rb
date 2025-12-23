#!/usr/bin/env ruby
# scripts/update_results.rb
# frozen_string_literal: true

ENV["TZ"] = "UTC"

require "date"
require "csv"
require "fileutils"
require "dotenv/load"

require_relative "../lib/footystats"

def usage!
  puts "Usage: ruby scripts/update_results.rb YYYY-MM-DD [--force]"
  exit 1
end

date_str = ARGV.find { |a| a.match?(/^\d{4}-\d{2}-\d{2}$/) }
force = ARGV.include?("--force")
usage! unless date_str

target_date = Date.parse(date_str).to_s

csv_path = File.expand_path("../data/results/picks.csv", __dir__)
abort "CSV not found: #{csv_path}" unless File.exist?(csv_path)

rows = CSV.table(csv_path)

# Ensure result columns exist
rows.each do |r|
  r[:btts_result] ||= nil
  r[:o25_result]  ||= nil
  r[:final_score] ||= nil
end

client  = FootyStats.new
updated = 0
skipped = 0

rows.each do |row|
  next unless row[:date].to_s == target_date

  market = row[:market].to_s.strip.upcase
  next if market.empty?

  # Skip existing results unless forced
  unless force
    if (market == "BTTS" && row[:btts_result]) ||
       ((market == "O2.5" || market == "O25") && row[:o25_result])
      skipped += 1
      next
    end
  end

  match_id = row[:match_id]
  unless match_id
    skipped += 1
    next
  end

  begin
    match = client.match(match_id: match_id)
  rescue => e
    puts "API ERROR match_id=#{match_id} → #{e.class}: #{e.message}"
    skipped += 1
    next
  end

  # Only finalize completed matches
  unless match["status"] == "complete"
    skipped += 1
    next
  end

  home_goals = match["homeGoalCount"]
  away_goals = match["awayGoalCount"]

  unless home_goals && away_goals
    skipped += 1
    next
  end

  home_goals = home_goals.to_i
  away_goals = away_goals.to_i
  total_goals = home_goals + away_goals

  row[:final_score] = "#{home_goals}-#{away_goals}"

  case market
  when "BTTS"
    row[:btts_result] = (home_goals > 0 && away_goals > 0) ? "W" : "L"
  when "O2.5", "O25"
    row[:o25_result] = (total_goals >= 3) ? "W" : "L"
  else
    skipped += 1
    next
  end

  updated += 1
end

# Atomic write
tmp = "#{csv_path}.tmp"
CSV.open(tmp, "w") do |csv|
  csv << rows.headers
  rows.each { |r| csv << r }
end
FileUtils.mv(tmp, csv_path)

puts "Results updated: #{updated}"
puts "Skipped: #{skipped}"
puts "Force mode: #{force}"
puts "CSV: #{csv_path}"
