#!/usr/bin/env ruby
# frozen_string_literal: true

require "csv"
require "date"
require "json"
require "net/http"
require "uri"

PICKS_CSV = "data/results/picks.csv"

API_KEY = ENV["FOOTYSTATS_API_KEY"]
abort("FOOTYSTATS_API_KEY not set") unless API_KEY && !API_KEY.empty?

TARGET_DATE =
  if ARGV[0]
    Date.parse(ARGV[0])
  else
    Date.today
  end

puts "API KEY PRESENT? YES"
puts "Updating results for #{TARGET_DATE}"

def fetch_match(match_id)
  uri = URI("https://api.football-data-api.com/match?key=#{API_KEY}&match_id=#{match_id}")
  res = Net::HTTP.get_response(uri)
  raise "API error #{res.code}" unless res.is_a?(Net::HTTPSuccess)

  body = JSON.parse(res.body)
  body["data"]
end

rows = CSV.table(PICKS_CSV)

updated = 0
skipped = 0

rows.each do |row|
  # Skip header corruption or malformed rows
  next if row[:date].nil?
  next if row[:date].to_s.strip.downcase == "date"

  row_date =
    begin
      Date.parse(row[:date].to_s.strip)
    rescue
      nil
    end

  next unless row_date == TARGET_DATE
  next unless row[:result].to_s.strip.downcase == "pending"

  match_id = row[:match_id].to_s.strip
  next if match_id.empty?

  begin
    match = fetch_match(match_id)

    # Only process completed matches
    status = match["status"].to_s.downcase
    unless status == "complete"
      skipped += 1
      next
    end

    home_goals = match["homeGoalCount"]
    away_goals = match["awayGoalCount"]
    next if home_goals.nil? || away_goals.nil?

    final_score = "#{home_goals}-#{away_goals}"

    market = row[:market].to_s.upcase
    win =
      case market
      when "BTTS"
        home_goals > 0 && away_goals > 0
      when "O2.5"
        (home_goals + away_goals) >= 3
      else
        false
      end

    row[:final_score] = final_score
    row[:result] = win ? "W" : "L"

    updated += 1
  rescue => e
    puts "ERROR fetching match #{match_id}: #{e.class} – #{e.message}"
    skipped += 1
  end
end

CSV.open(PICKS_CSV, "w") do |csv|
  csv << rows.headers
  rows.each { |r| csv << r }
end

puts "Results updated: #{updated}"
puts "Skipped (not finished / API issues): #{skipped}"
