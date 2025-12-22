#!/usr/bin/env ruby

require "csv"

CSV_PATH = File.expand_path("../data/results/picks.csv", __dir__)

rows = CSV.read(CSV_PATH, headers: true)

fixed = 0

rows.each do |row|
  final_score = row["final_score"].to_s.strip
  result      = row["result"].to_s.strip

  # If no score exists, result must be pending
  if final_score == "" && %w[W L].include?(result)
    row["result"] = "pending"
    fixed += 1
  end
end

CSV.open(CSV_PATH, "w", write_headers: true, headers: rows.headers) do |csv|
  rows.each { |r| csv << r }
end

puts "Cleanup complete"
puts "Rows reset to pending: #{fixed}"
