# frozen_string_literal: true

require 'flamegraph'
require_relative 'blockchain'

if ARGV[0].nil?
  puts "Usage: ruby verifier.rb <name_of_file>\n\tname_of_file = name of file to verify"
  exit(1)
end

Flamegraph.generate('flamegrapher.html') do
  my_blockchain = Blockchain.new(ARGV[0])
  my_blockchain.run
end
