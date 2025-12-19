# scripts/find_swiss_current_season.rb
require "dotenv/load"
require "httparty"
require "json"

API_KEY = ENV["FOOTYSTATS_API_KEY"]
abort "Missing FOOTYSTATS_API_KEY" if API_KEY.nil?

# League list returns leagues + seasons (you already saw "season": [{"id":..., "year":...}])
resp = HTTParty.get("https://api.footystats.org/league-list", query: { key: API_KEY })
abort "API error #{resp.code}" unless resp.code == 200

leagues = resp.parsed_response["data"] || resp.parsed_response

swiss = leagues.find do |l|
  (l["country"] == "Switzerland") &&
  (l["name"] == "Switzerland Super League" || l["league_name"] == "Super League")
end

abort "Could not find Switzerland Super League in league-list" if swiss.nil?

seasons = swiss["season"] || []
abort "No seasons found for Switzerland Super League" if seasons.empty?

latest = seasons.max_by { |s| s["year"].to_i }  # picks highest year (e.g., 20252026)
puts "Swiss Super League latest season:"
puts JSON.pretty_generate(latest)
puts "Use season_id=#{latest['id']} (year=#{latest['year']})"
