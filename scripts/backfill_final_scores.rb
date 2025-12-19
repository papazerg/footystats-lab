#!/usr/bin/env ruby

require "csv"
require "yaml"
require_relative "../lib/footystats"

CSV_PATH = File.expand_path("../data/results/picks.csv", __dir__)
LEAGUES  = YAML.load_file(
  File.expand_path("../config/leagues.yml", __dir__)
)

abort("picks.csv not found") unless File.exist?(CSV_PATH)

client = FootyStats.new
rows   = CSV.read(CSV_PATH, headers: true)

updated = 0
skipped = 0

# Cache matches per league
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
  # Only backfill completed rows missing final_score
  next unless %w[W L].include?(row["result"])
  next if row["final_score"] && !row["final_score"].empty?

  cfg = LEAGUES.values.find { |l| l["name"] == row["league"] }

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

  if home_goals.nil? || away_goals.nil?
    skipped += 1
    next
  end

  row["final_score"] = "#{home_goals}-#{away_goals}"
  updated += 1
end

# Ensure header exists
headers = rows.headers
unless headers.include?("final_score")
  headers.insert(headers.index("match_id") + 1, "final_score")
end

CSV.open(CSV_PATH, "w", write_headers: true, headers: headers) do |csv|
  rows.each { |r| csv << r }
end

puts "Backfill complete"
puts "Final scores added: #{updated}"
puts "Skipped: #{skipped}"
