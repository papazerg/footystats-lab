#!/usr/bin/env ruby

ENV["TZ"] = "UTC"

require "date"
require "time"
require "yaml"
require "csv"
require "set"
require "fileutils"
require "dotenv/load"

require_relative "../lib/footystats"
require_relative "../lib/form"

# -----------------------------
# CONSTANTS
# -----------------------------
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
  result
]

CONFIDENCE_WEIGHT = {
  "🔥 STRONG" => 3,
  "⚠️ MEDIUM" => 2,
  "❌ PASS"   => 1
}

# -----------------------------
# FLAGS
# -----------------------------
include_form = ARGV.include?("--form")
run_all      = ARGV.include?("--all")

# -----------------------------
# LOAD LEAGUES
# -----------------------------
LEAGUES = YAML.load_file(
  File.expand_path("../config/leagues.yml", __dir__)
)

league_keys =
  if run_all
    LEAGUES.keys
  else
    key = ARGV.find { |a| !a.start_with?("--") }
    abort("❌ League key required") unless key && LEAGUES[key]
    [key]
  end

# -----------------------------
# DATE (UTC)
# -----------------------------
date_arg = ARGV.find { |a| a.match?(/^\d{4}-\d{2}-\d{2}$/) }

target_date =
  if date_arg
    Date.parse(date_arg)
  else
    Date.today
  end

display_date = target_date.strftime("%a %d %b %Y")

# -----------------------------
# INIT CLIENT
# -----------------------------
client = FootyStats.new

# -----------------------------
# CSV SETUP (IDEMPOTENT)
# -----------------------------
results_dir = File.expand_path("../data/results", __dir__)
FileUtils.mkdir_p(results_dir)

csv_path = File.join(results_dir, "picks.csv")
existing_keys = Set.new

if File.exist?(csv_path)
  CSV.foreach(csv_path, headers: true) do |row|
    next unless row["date"] == target_date.to_s

    key = [
      row["date"],
      row["league"],
      row["match_id"]
    ].join("|")

    existing_keys << key
  end
else
  CSV.open(csv_path, "w") { |csv| csv << CSV_HEADERS }
end

# -----------------------------
# HELPERS
# -----------------------------
def kickoff_utc(match)
  Time.at(match["date_unix"].to_i).utc.strftime("%H:%M")
end

def confidence_label(btts, o25)
  return "🔥 STRONG" if btts >= 70 || o25 >= 70
  return "⚠️ MEDIUM" if btts >= 60 || o25 >= 60
  "❌ PASS"
end

# -----------------------------
# MAIN LOOP
# -----------------------------
league_keys.each do |key|
  league = LEAGUES[key]

  season_id =
    begin
      client.current_season_id(
        country: league["country"],
        league_name: league["league_name"]
      )
    rescue
      next
    end

  matches =
    begin
      client.matches_for_season(season_id)
    rescue
      next
    end

  todays = matches.select do |m|
    m["date_unix"] &&
      Time.at(m["date_unix"].to_i).utc.to_date == target_date
  end

  todays.each do |m|
    home = m["home_name"]
    away = m["away_name"]
    match_name = "#{home} vs #{away}"

    btts = m["btts_potential"].to_i
    o25  = m["o25_potential"].to_i

    label  = confidence_label(btts, o25)
    market = btts >= o25 ? "BTTS" : "O2.5"

    key_id = [
      target_date.to_s,
      league["name"],
      m["id"]
    ].join("|")

    next if existing_keys.include?(key_id)

    CSV.open(csv_path, "a") do |csv|
      csv << [
        target_date.to_s,
        league["name"],
        match_name,
        kickoff_utc(m),
        market,
        label.gsub(/[^A-Z]/, ""),
        btts,
        o25,
        m["id"],
        "pending"
      ]
    end

    existing_keys << key_id
  end
end

puts "✅ Slate locked for #{target_date}"
puts "📄 CSV rows: #{CSV.read(csv_path).size - 1}"
