# frozen_string_literal: true

# This class will process a block chain in a given file
class Blockchain
  def initialize(file_name)
    @file_name = file_name
  end

  def run
    line_number = 0
    # Map with the userID => amount
    users = {}
    # Map with the UTF-8 characters => total calculated
    utf_vals = {}
    last_block_info = ['0', nil]

    File.open(@file_name).each do |line|
      last_block_info = process_line(line, line_number, users, last_block_info, utf_vals)
      line_number += 1
    end
    unless line_number.positive?
      print_err('The file is empty, you need at least one ' \
        'block in the block chain', line_number)
    end

    users.sort.each do |key, val|
      next unless val.positive?

      puts "#{key}: #{val} billcoins"
    end
  rescue Errno::ENOENT # We must be able to catch ALL errors
    puts "ERROR:  File '#{@file_name}' does not exist."
  end

  # Takes the blockchain string from a single line in the input file
  def process_line(line, line_number, users, last_block_info, utf_vals)
    tokens = line.split('|')
    unless tokens.length == 5
      print_err("Could not parse block chain string '#{line}'" \
        'as it requires exactly 5 elements', line_number)
      return false
    end
    # Block number is just like an index number (for arrays) in the block chain
    # Ex: 0, 1, 2, ... n
    block_number = tokens[0]
    # previous hash is the hash of the previous block in the chain
    previous_hash = tokens[1]
    # The series of transactions between users recorded on this block chain
    transaction_string = tokens[2]
    # The time of the block creation.  Calculated since epoch, in the format:
    # <seconds since epoch> . <nanoseconds>
    timestamp_string = tokens[3]
    # The next hash in the block chain which is calculated from the values in the current block
    next_hash = tokens[4]
    hash_input = "#{block_number}|#{previous_hash}|#{transaction_string}|#{timestamp_string}"
    check_block_number(block_number, line_number)
    check_user_transactions(transaction_string, line_number, users)
    check_user_values(users, line_number)

    res = check_timestamp(timestamp_string, line_number, last_block_info[1])
    if res == -1
      print_err("Previous timestamp #{last_block_info[1]} >= new timestamp #{timestamp_string}", line_number)
    elsif res.zero?
      print_err("Timestamp #{timestamp_string} invalid. Seconds and nanosesconds must be positive", line_number)
    end

    check_next_hash(next_hash.delete!("\n"), hash_input, line_number, utf_vals)
    check_prev_hash(previous_hash, last_block_info[0], line_number)
    [next_hash, timestamp_string]
  end

  # Checks that the valid block number is used
  def check_block_number(block_number, line_number)
    return true unless block_number.to_i != line_number

    print_err("Invalid block number #{block_number}, should be #{line_number}", line_number)
    false
  end

  # Ensures the block chain string will hash correctly to the recorded next hash
  def check_next_hash(next_hash, hash_input, line_number, utf_vals)
    real_next = calc_hash(hash_input, utf_vals)
    return true unless real_next != next_hash

    print_err("String '#{hash_input}' hash set to #{next_hash}, should be #{real_next}", line_number)
    false
  end

  # The second element of the block string (prev hash) should equal the LAST next hash
  def check_prev_hash(expected_prev_hash, prev_hash, line_number)
    if line_number.zero?
      unless expected_prev_hash == '0'
        print_err('The first block should have a previous hash ' \
          "value of 0 and not '#{expected_prev_hash}'", line_number)
        false
      end
    end

    return true unless expected_prev_hash != prev_hash

    print_err("Previous hash was #{expected_prev_hash}, should be #{prev_hash}", line_number)
    false
  end

  # passes along individual transactions from the transaction string
  def check_user_transactions(transactions, line_number, users)
    if transactions.nil? || transactions == ''
      print_err('There is no transaction string.  It requires at least one from the SYSTEM', line_number)
      return -1
    end

    tokens = transactions.split(':')
    len = tokens.length
    # Last transaction should be the "reward" from the SYSTEM
    count = 1
    tokens.each do |transaction|
      verify_transaction(transaction, line_number, users, count, len)
      count += 1
    end
    count
  end

  # Checks that the timestamp is valid
  def check_timestamp(timestamp_string, line_number, previous_timestamp_string)
    return 2 unless line_number != 0 # return value 2 does nothing

    tokens = timestamp_string.split('.')
    seconds = tokens[0].to_i
    nanos = tokens[1].to_i

    tokens = previous_timestamp_string.split('.')
    previous_seconds = tokens[0].to_i
    previous_nanos = tokens[1].to_i

    return 0 unless !seconds.negative? && !nanos.negative? # if either are negative, return 0
    # if prev is later than curr, return -1. Else, 1
    return 1 unless (previous_seconds > seconds) || (previous_seconds == seconds && previous_nanos >= nanos)

    -1
  end

  # Takes the transaction string from each blockchain and verifies its characters
  def verify_transaction(transaction, line_number, users, count, len)
    tokens = transaction.split('>')
    # You need to make sure that there is a to/from address
    unless tokens.length == 2
      print_err("Could not parse transaction list '#{transaction}'", line_number)
      return -1
    end

    from_address = tokens[0]
    to_address = tokens[1].split('(')[0]
    # Ensures the value is contained in parenthesis
    amount = tokens[1][/\(.*?\)/]
    if amount.nil?
      print_err("ERROR: On line #{line_number} you must contain the " \
        'value of the transaction in parenthesis', line_number)
      return -2
    end
    # Remove the parenthesis
    amount = amount.gsub(/[()]/, '(' => '', ')' => '')
    unless number?(amount)
      print_err("ERROR: The amount '#{amount}' shown " \
        "at line #{line_number} is not numeric", line_number)
      return -3
    end

    amount = amount.to_i
    # Ensure that the last element in the transaction list is the SYSTEM transaction
    if count == len && !transaction.include?('SYSTEM')
      print_err('The SYSTEM transaction must be the last transaction in ' \
        "the string instead of '#{transaction}'", line_number)
      return -4
    end

    process_transaction(from_address, to_address, amount, users, line_number)
  end

  # Takes the tokens from the transaction string and updates users balances
  def process_transaction(from_address, to_address, amount, users, line_number)
    # Guard for checking a 6-digit number address
    unless from_address.length == 6 && to_address.length == 6
      print_err("The address at line #{line_number} is not 6 digits long", line_number)
      return -1
    end
    # Guard for checking a numeric number address (could also be 'SYSTEM')
    unless (number?(from_address) && number?(to_address)) || (from_address == 'SYSTEM' && number?(to_address))
      print_err("The address at line #{line_number} is not a number", line_number)
      return -2
    end
    # Guard for a negative amount
    unless amount.positive?
      print_err("The amount '#{amount}' given at line #{line_number} cannot be negative", line_number)
      return -3
    end
    # Initialize the userID keys in the map
    users[to_address] = 0 unless users.key?(to_address)
    users[to_address] += amount
    return -4 if from_address == 'SYSTEM'

    users[from_address] = 0 unless users.key?(from_address)
    users[from_address] -= amount
    0
  end

  # Calculates the hash value with a given hash input (first four elements of the block)
  def calc_hash(hash_input, utf_vals)
    total = 0
    hash_input.split('').each do |char|
      utf_value = char.ord # Get the UTF-8 integer value of the character
      if utf_vals.key?(utf_value)
        total += utf_vals[utf_value]
      else
        res = ((utf_value**3000) + (utf_value**utf_value) - (3**utf_value)) * (7**utf_value)
        total += res
        utf_vals[utf_value] = res
      end
    end
    total = total % 65_536
    total.to_s(16) # Converts integer to HEX string
  end

  # Make sure after each block is processed the values are valid
  def check_user_values(users, line_number)
    users.each do |key, val|
      # The value of the system does not matter :'(
      next if key == 'SYSTEM'

      if val.negative?
        print_err("Invalid block, address #{key} has #{val} billcoins!", line_number)
        return -1
      end
    end
  end

  # Check if the given input string is a number
  def number?(str)
    true if Float(str)
  rescue ArgumentError
    false
  end

  # Print the error and exit
  def print_err(msg, line_number)
    return -1 unless msg.is_a?(String) && line_number.is_a?(Integer)

    puts "Line #{line_number}: #{msg}\nBLOCKCHAIN INVALID"
    exit(1)
  end
end
