# scripts/today_swiss_matches.rb
require "json"
require "date"
require "time"

TZ = "America/Phoenix" # used for display only in this script
TODAY = Date.today # your Mac local date

path = "data/raw/swiss_super_league_matches.json"
matches = JSON.parse(File.read(path))

def date_from_unix(unix_ts)
  Time.at(unix_ts.to_i).getlocal.to_date
end

todays = matches.select do |m|
  unix = m["date_unix"] || m["date"] # docs show date_unix in league-matches response :contentReference[oaicite:1]{index=1}
  next false unless unix
  date_from_unix(unix) == TODAY
end

puts "Swiss Super League matches on #{TODAY} (#{TZ})"
puts "Found: #{todays.size}\n\n"

todays.each do |m|
  home = m["home_name"]
  away = m["away_name"]
  ko   = Time.at(m["date_unix"].to_i).getlocal.strftime("%H:%M")

  btts_p = m["btts_potential"]
  o25_p  = m["o25_potential"] || m["o25_potential"] # naming varies in some seasons
  avg_g  = m["avg_potential"]
  corners_p = m["corners_potential"]

  puts "#{ko}  #{home} vs #{away}"
  puts "  BTTS_potential: #{btts_p} | O2.5_potential: #{o25_p} | avg_goals_potential: #{avg_g} | corners_potential: #{corners_p}"
  puts "  match_id: #{m['id']}"
  puts
end
