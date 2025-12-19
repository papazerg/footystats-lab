# scripts/normalize_csv_headers.rb
require "csv"

CSV_PATH = File.expand_path("../data/results/picks.csv", __dir__)

rows = CSV.read(CSV_PATH, headers: true)

HEADERS = [
  "date",
  "league",
  "match",
  "kickoff_utc",
  "market",
  "confidence",
  "model_btts",
  "model_o25",
  "match_id",
  "final_score",
  "result"
]

CSV.open(CSV_PATH, "w", write_headers: true, headers: HEADERS) do |csv|
  rows.each do |row|
    csv << HEADERS.map { |h| row[h] }
  end
end

puts "CSV headers normalized"
