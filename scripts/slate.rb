#!/usr/bin/env ruby
# frozen_string_literal: true

ENV["TZ"] = "UTC"

require "date"
require "time"
require "yaml"
require "csv"
require "set"
require "fileutils"
require "dotenv/load"

require_relative "../lib/footystats"

# -----------------------------
# CONFIG
# -----------------------------
LEAGUES_PATH = File.expand_path("../config/leagues.yml", __dir__)
RESULTS_DIR  = File.expand_path("../data/results", __dir__)
CSV_PATH     = File.join(RESULTS_DIR, "picks.csv")

CSV_HEADERS = %w[
  date
  league
  match
  kickoff_utc
  market
  confidence
  model_btts
  model_o25
  match_id
  final_score
  result
].freeze

CONFIDENCE_WEIGHT = {
  "STRONG" => 3,
  "MEDIUM" => 2,
  "PASS"   => 1
}.freeze

# -----------------------------
# ARGS
# -----------------------------
include_form = ARGV.include?("--form") # kept for CLI compatibility; not used in this minimal version
run_all      = ARGV.include?("--all")
quiet        = ARGV.include?("--quiet")

date_arg = ARGV.find { |a| a.match?(/^\d{4}-\d{2}-\d{2}$/) }
target_date = date_arg ? Date.parse(date_arg) : Date.today
target_date_str = target_date.to_s

# league key: first non-flag, non-date arg
league_key_arg = ARGV.find { |a| !a.start_with?("--") && !a.match?(/^\d{4}-\d{2}-\d{2}$/) }

puts
puts "Generating slate for #{target_date_str} (UTC)"
puts

# -----------------------------
# LOAD LEAGUES (existing structure)
# -----------------------------
unless File.exist?(LEAGUES_PATH)
  abort("Missing config/leagues.yml at #{LEAGUES_PATH}")
end

leagues_yml = YAML.load_file(LEAGUES_PATH)
unless leagues_yml.is_a?(Hash)
  abort("config/leagues.yml must be a Hash keyed by league key (e.g. australia_a_league: ...)")
end

selected_keys =
  if run_all
    leagues_yml.keys
  else
    abort("League key required unless using --all") unless league_key_arg
    abort("Unknown league key: #{league_key_arg}") unless leagues_yml.key?(league_key_arg)
    [league_key_arg]
  end

selected_leagues = selected_keys.map { |k| [k, leagues_yml[k]] }.to_h

# Build competition_id -> display name map (this is the ONLY matching method)
competition_map = {}
missing_competitions = []

selected_leagues.each do |key, cfg|
  comp_id = cfg["competition_id"]
  if comp_id.nil? || comp_id.to_s.strip.empty?
    missing_competitions << cfg["name"] || key
    next
  end

  competition_map[comp_id.to_i] = {
    "key"  => key,
    "name" => (cfg["name"] || key)
  }
end

if competition_map.empty?
  msg = "No competition_id configured for selected leagues.\n" \
        "Add competition_id to config/leagues.yml for the leagues you want to track.\n"
  msg += "Missing competition_id for: #{missing_competitions.join(', ')}\n" unless missing_competitions.empty?
  abort(msg)
end

# -----------------------------
# CSV SETUP (idempotent)
# -----------------------------
FileUtils.mkdir_p(RESULTS_DIR)

existing_keys = Set.new

if File.exist?(CSV_PATH)
  CSV.foreach(CSV_PATH, headers: true) do |row|
    next unless row["date"] == target_date_str
    # uniqueness by date + match_id (league name can change)
    existing_keys << "#{row['date']}|#{row['match_id']}"
  end
else
  CSV.open(CSV_PATH, "w") { |csv| csv << CSV_HEADERS }
end

# -----------------------------
# HELPERS
# -----------------------------
def kickoff_utc_from_unix(unix)
  Time.at(unix.to_i).utc.strftime("%H:%M")
end

def confidence_for(btts, o25)
  b = btts.to_i
  o = o25.to_i
  return "STRONG" if b >= 70 || o >= 70
  return "MEDIUM" if b >= 60 || o >= 60
  "PASS"
end

def market_for(btts, o25)
  b = btts.to_i
  o = o25.to_i
  b >= o ? "BTTS" : "O2.5"
end

def parse_match_date_utc(unix)
  Time.at(unix.to_i).utc.to_date
end

# -----------------------------
# FETCH TODAY’S MATCHES (single endpoint)
# -----------------------------
client = FootyStats.new

todays =
  begin
    client.todays_matches(date: target_date_str, timezone: "Etc/UTC")
  rescue => e
    abort("Failed to fetch todays_matches: #{e.class} - #{e.message}")
  end

# Filter by tracked competition_id only
tracked = todays.select do |m|
  cid = m["competition_id"]
  cid && competition_map.key?(cid.to_i)
end

# Extra safety: ensure match date matches target_date (in case API returns timezone-shifted edge cases)
tracked.select! do |m|
  unix = m["date_unix"]
  unix && parse_match_date_utc(unix) == target_date
end

if tracked.empty?
  puts "No tracked matches found for #{target_date_str}"
  exit 0
end

# -----------------------------
# WRITE PICKS + COLLECT OUTPUT
# -----------------------------
rows_written = 0
printed = []

CSV.open(CSV_PATH, "a") do |csv|
  tracked.each do |m|
    match_id = m["id"].to_i
    key = "#{target_date_str}|#{match_id}"
    next if existing_keys.include?(key)

    league_info = competition_map[m["competition_id"].to_i]
    league_name = league_info["name"]

    home = m["home_name"].to_s.strip
    away = m["away_name"].to_s.strip
    match_name = "#{home} vs #{away}"

    kickoff = kickoff_utc_from_unix(m["date_unix"])
    btts = m["btts_potential"].to_i
    o25  = m["o25_potential"].to_i

    confidence = confidence_for(btts, o25)
    market     = market_for(btts, o25)

    csv << [
      target_date_str,
      league_name,
      match_name,
      kickoff,
      market,
      confidence,
      btts,
      o25,
      match_id,
      "",        # final_score
      "pending"  # result
    ]

    existing_keys << key
    rows_written += 1

    printed << {
      league: league_name,
      match: match_name,
      kickoff: kickoff,
      market: market,
      confidence: confidence,
      btts: btts,
      o25: o25
    }
  end
end

# If nothing new appended, still show what exists for the day is handled by print_picks script.
# Here we print only what we appended in this run (keeps cron output small).
if rows_written == 0
  puts "Slate already locked for #{target_date_str} (no new rows)"
  exit 0
end

# -----------------------------
# PRINT RECOMMENDATIONS (plain text)
# -----------------------------
unless quiet
  # Sort by confidence, then kickoff time
  printed.sort_by! do |r|
    [
      -CONFIDENCE_WEIGHT.fetch(r[:confidence], 0),
      r[:kickoff]
    ]
  end

  # Group by league for readability
  by_league = printed.group_by { |r| r[:league] }

  by_league.keys.sort.each do |league|
    puts "#{league} — #{target_date_str}"
    puts "-" * (league.length + 13)
    by_league[league].each_with_index do |r, idx|
      # Match name first (your preference), then time
      puts "#{idx + 1}. #{r[:match]} | #{r[:kickoff]} UTC"
      puts "   BTTS=#{r[:btts]}  O2.5=#{r[:o25]}  Market=#{r[:market]}  Confidence=#{r[:confidence]}"
      puts
    end
    puts
  end
end

puts "Slate locked for #{target_date_str}"
puts "CSV rows added: #{rows_written}"
