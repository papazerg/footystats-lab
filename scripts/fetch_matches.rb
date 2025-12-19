# scripts/fetch_matches.rb

require "dotenv/load"
require "json"
require_relative "../lib/footystats"

SEASON_ID = 136 # Switzerland Super League

api_key = ENV["FOOTYSTATS_API_KEY"]
abort "Missing FOOTYSTATS_API_KEY (check .env)" if api_key.nil?

puts "[#{Time.now}] Fetching Swiss Super League matches..."

client = FootyStats.new(api_key: api_key)
matches = client.league_matches(season_id: SEASON_ID)

puts "Received #{matches.size} matches"

output_path = "data/raw/swiss_super_league_matches.json"
File.write(output_path, JSON.pretty_generate(matches))

puts "Saved raw data to #{output_path}"

puts "\nSample matches:"
matches.first(5).each do |m|
  home = m["home_name"]
  away = m["away_name"]
  hg = m["homeGoalCount"]
  ag = m["awayGoalCount"]
  btts = m["btts"]

  puts "- #{home} vs #{away} | #{hg}-#{ag} | BTTS: #{btts}"
end
