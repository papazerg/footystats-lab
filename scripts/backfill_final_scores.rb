#!/usr/bin/env ruby

require "csv"
require_relative "../lib/footystats"
require "yaml"

LEAGUES = YAML.load_file(
  File.expand_path("../config/leagues.yml", __dir__)
)

csv_path = File.expand_path("../data/results/picks.csv", __dir__)
rows = CSV.read(csv_path, headers: true)

client = FootyStats.new
added = 0
skipped = 0

rows.each do |row|
  next unless %w[W L].include?(row["result"])
  next unless row["final_score"].to_s.strip == ""

  cfg = LEAGUES.values.find { |l| l["name"] == row["league"] }
  unless cfg
    skipped += 1
    next
  end

  matches = client.matches_for_season(
    country: cfg["country"],
    league_name: cfg["league_name"]
  )

  match = matches.find { |m| m["id"].to_s == row["match_id"].to_s }
  unless match
    skipped += 1
    next
  end

  # ---- CRITICAL FIX ----
  status = match["status"] || match["status_short"]
  next unless status&.to_s&.upcase == "FT"

  home_goals = match["homeGoalCount"]
  away_goals = match["awayGoalCount"]
  next if home_goals.nil? || away_goals.nil?

  row["final_score"] = "#{home_goals}-#{away_goals}"
  added += 1
end

CSV.open(csv_path, "w", write_headers: true, headers: rows.headers) do |csv|
  rows.each { |r| csv << r }
end

puts "Backfill complete"
puts "Final scores added: #{added}"
puts "Skipped: #{skipped}"
