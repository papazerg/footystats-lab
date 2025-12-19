#!/usr/bin/env ruby

require "csv"
require "date"
require_relative "../lib/footystats"
require "yaml"

abort("Usage: update_results.rb YYYY-MM-DD") unless ARGV[0]

LEAGUES = YAML.load_file(
  File.expand_path("../config/leagues.yml", __dir__)
)

target_date = Date.parse(ARGV[0]).to_s
csv_path = File.expand_path("../data/results/picks.csv", __dir__)

abort("picks.csv not found") unless File.exist?(csv_path)

client = FootyStats.new
rows   = CSV.read(csv_path, headers: true)

updated = 0
skipped = 0

# Cache matches per league so we don’t re-fetch
league_cache = {}

def fetch_matches(client, league_cache, cfg)
  league_cache[cfg["name"]] ||= begin
    season_id = client.current_season_id(
      country: cfg["country"],
      league_name: cfg["league_name"]
    )
    client.matches_for_season(season_id)
  end
end

rows.each do |row|
  # Only update pending rows for the target date
  next unless row["date"] == target_date
  next unless row["result"] == "pending"

  cfg = LEAGUES.find { |l| l["name"] == row["league"] }
  unless cfg
    skipped += 1
    next
  end

  matches = fetch_matches(client, league_cache, cfg)

  api_match = matches.find do |m|
    m["id"].to_s == row["match_id"].to_s
  end

  unless api_match
    skipped += 1
    next
  end

  home_goals = api_match["homeGoalCount"]
  away_goals = api_match["awayGoalCount"]

  # Match not finished yet
  if home_goals.nil? || away_goals.nil?
    skipped += 1
    next
  end

  # Record final score for transparency
  final_score = "#{home_goals}-#{away_goals}"
  row["final_score"] = final_score

  # Grade result by market
  case row["market"]
  when "BTTS"
    row["result"] = (home_goals > 0 && away_goals > 0) ? "W" : "L"
  when "O2.5"
    row["result"] = (home_goals + away_goals >= 3) ? "W" : "L"
  else
    skipped += 1
    next
  end

  updated += 1
end

# Ensure final_score column exists in output
headers = rows.headers
unless headers.include?("final_score")
  headers.insert(headers.index("match_id") + 1, "final_score")
end

CSV.open(csv_path, "w", write_headers: true, headers: headers) do |csv|
  rows.each { |r| csv << r }
end

puts "📅 Updating results for #{target_date}"
puts "✅ Results updated: #{updated}"
puts "⏭️ Skipped (not finished / not found): #{skipped}"
