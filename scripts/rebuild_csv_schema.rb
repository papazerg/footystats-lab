#!/usr/bin/env ruby

require "csv"

CSV_PATH = File.expand_path("../data/results/picks.csv", __dir__)

EXPECTED_HEADERS = [
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

rows = CSV.read(CSV_PATH, headers: true)

fixed = 0

CSV.open(CSV_PATH, "w", write_headers: true, headers: EXPECTED_HEADERS) do |csv|
  rows.each do |row|
    new_row = {}

    EXPECTED_HEADERS.each do |h|
      new_row[h] = row[h]
    end

    # Detect shifted rows: final_score contains W/L and result empty
    if %w[W L].include?(new_row["final_score"]) && new_row["result"].to_s.strip == ""
      new_row["result"] = new_row["final_score"]
      new_row["final_score"] = ""
      fixed += 1
    end

    csv << EXPECTED_HEADERS.map { |h| new_row[h] }
  end
end

puts "CSV rebuilt"
puts "Rows fixed: #{fixed}"
