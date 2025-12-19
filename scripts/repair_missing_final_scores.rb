#!/usr/bin/env ruby

require "csv"

CSV_PATH = File.expand_path("../data/results/picks.csv", __dir__)

rows = CSV.read(CSV_PATH, headers: true)

fixed = 0

rows.each do |row|
  # We only fix rows where:
  # - result is W or L
  # - final_score is empty
  next unless %w[W L].include?(row["result"])
  next unless row["final_score"].nil? || row["final_score"].strip == ""

  # We cannot guess score, so mark clearly for backfill
  row["final_score"] = "BACKFILL"
  fixed += 1
end

CSV.open(CSV_PATH, "w", write_headers: true, headers: rows.headers) do |csv|
  rows.each { |r| csv << r }
end

puts "Repair complete"
puts "Rows marked for backfill: #{fixed}"
