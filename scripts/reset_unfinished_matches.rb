#!/usr/bin/env ruby

require "csv"
require "time"

csv_path = File.expand_path("../data/results/picks.csv", __dir__)
rows = CSV.read(csv_path, headers: true)

now = Time.now.utc
reset = 0

rows.each do |row|
  next unless %w[W L].include?(row["result"])

  kickoff = Time.parse("#{row['date']} #{row['kickoff_utc']} UTC") rescue nil
  next unless kickoff

  # If kickoff hasn't happened yet, result must be pending
  if kickoff > now
    row["result"] = "pending"
    row["final_score"] = ""
    reset += 1
  end
end

CSV.open(csv_path, "w", write_headers: true, headers: rows.headers) do |csv|
  rows.each { |r| csv << r }
end

puts "Reset complete"
puts "Rows reverted to pending (future kickoff): #{reset}"
