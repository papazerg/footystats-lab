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
unless rows.headers.include?(:btts_result)
  rows.each { |r| r[:btts_result] = nil }
end

unless rows.headers.include?(:o25_result)
  rows.each { |r| r[:o25_result] = nil }
end

updated = 0
skipped = 0

rows.each do |row|
  # Only process rows for the requested date
  next unless row[:date] == target_date

  market = row[:market].to_s.strip.upcase
  next if market.empty?

  # Skip rows that already have results unless forcing
  unless force
    if (market == "BTTS" && row[:btts_result]) ||
       ((market == "O2.5" || market == "O25") && row[:o25_result])
      skipped += 1
      next
    end
  end

  home_goals = nil
  away_goals = nil

  # Prefer final_score if present
  if row[:final_score].to_s.include?("-")
    home_goals, away_goals = row[:final_score].split("-").map(&:to_i)
  else
    match_id = row[:match_id]
    unless match_id
      skipped += 1
      next
    end

    begin
      match = Footystats.match(match_id)
    rescue StandardError
      skipped += 1
      next
    end

    hg = match["home_goals"]
    ag = match["away_goals"]

    unless hg && ag
      skipped += 1
      next
    end

    home_goals = hg.to_i
    away_goals = ag.to_i
    row[:final_score] = "#{home_goals}-#{away_goals}"
  end

  total_goals = home_goals + away_goals

  case market
  when "BTTS"
    row[:btts_result] =
      home_goals > 0 && away_goals > 0 ? "W" : "L"
  when "O2.5", "O25"
    row[:o25_result] =
      total_goals >= 3 ? "W" : "L"
  else
    skipped += 1
    next
  end

  updated += 1
end

# Write back atomically
tmp = csv_path + ".tmp"
CSV.open(tmp, "w") do |csv|
  csv << rows.headers
  rows.each { |r| csv << r }
end
FileUtils.mv(tmp, csv_path)

puts "Results updated: #{updated}"
puts "Skipped: #{skipped}"
puts "Force mode: #{force}"
puts "CSV: #{csv_path}"
puts
