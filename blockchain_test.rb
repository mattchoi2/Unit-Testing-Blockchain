require 'minitest/autorun'
require_relative 'blockchain'

# The test program for the blockchain class
class BlockchainTest < Minitest::Test

  def setup
    @my_bc = Blockchain.new('sample.txt')
  end

  def test_constructor
    refute_nil @my_bc
    assert_kind_of Blockchain, @my_bc
  end

  # UNIT TESTS FOR METHOD process_line(line, line_number, users, last_block_info, utf_vals)

  def test_process_line_wrong_length
    bad_line = "3|4d25|561180>444100(1):SYSTEM>569274(100)|1553184699.663411000"
    users = {}
    utf_vals = {}
    last_block_info = ['0', nil]
    def @my_bc.print_err(msg, line_number); 1; end
    assert_equal false, @my_bc.process_line(bad_line, 3, users, last_block_info, utf_vals)
  end

  def test_process_line_success
    line = "9|a91|402207>794343(10):SYSTEM>689881(100):402207>780971(13):794343>236340(16):717802>717802(1)|1553184699.691433000|676e"
    users = {}
    utf_vals = {}
    last_block_info = ['0', nil]
    # An altar to the stubbing gods
    def @my_bc.print_err(msg, line_number); 1; end
    def @my_bc.check_timestamp(timestamp_string, line_number, previous_timestamp_string); 1; end
    def @my_bc.check_block_number(block_number, line_number); 1; end
    def @my_bc.check_user_transactions(transactions, line_number, users); 1; end
    def @my_bc.check_user_values(users, line_number); 1; end
    def @my_bc.check_next_hash(next_hash, hash_input, line_number, utf_vals); 1; end
    def @my_bc.check_prev_hash(expected_prev_hash, prev_hash, line_number); 1; end

    assert_equal ["676e", "1553184699.691433000"], @my_bc.process_line(line, 0, users, last_block_info, utf_vals)
  end

  # UNIT TESTS FOR METHOD check_block_number(block_number, line_number)
  # Equivalence classes:
  # block_number == line_number -> True
  # block_number != line_number -> False

  # Tests whether block number is verified correctly with equal inputs
  def test_check_block_number_equal
    def @my_bc.print_err(msg, line_number); 1; end
    assert_equal true, @my_bc.check_block_number('1', 1)
  end

  # Tests whether block number is verified correctly with equal inputs
  def test_check_block_number_not_equal
    def @my_bc.print_err(msg, line_number); 1; end
    assert_equal false, @my_bc.check_block_number('0', 1)
  end

  # UNIT TESTS FOR METHOD check_next_hash()
  # Equivalence classes:
  # Rantly random strings of length 6 == the calculated hash value
  # Rantly random string of length 6 != the calculated hash value

  def test_check_next_hash_correct
    property_of { # A little bit of rantly
      [string, integer]
    }.check(100) { |args|
      def @my_bc.print_err(msg, line_number); 1; end
      # Simply return what hash_input was passed in
      def @my_bc.calc_hash(hash_input, utf_vals); hash_input; end
      # Note the next_hash and hash_input are the SAME
      assert_equal @my_bc.check_next_hash(args[0], args[0], args[1], {}), true
    }
  end

  def test_check_next_hash_incorrect
    property_of { # A little bit of rantly
      [string, string, integer]
    }.check(100) { |args|
      def @my_bc.print_err(msg, line_number); 1; end
      # Simply return the hash value passed in
      def @my_bc.calc_hash(hash_input, utf_vals); hash_input; end
      # Note the next_hash and hash_input are the NOT THE SAME
      assert_equal @my_bc.check_next_hash(args[0], args[1], args[2], {}), false
    }
  end

  # UNIT TESTS FOR METHOD check_prev_hash(expected_prev_hash, prev_hash, line_number)
  # Equivalence classes:
  # Line num = 0 and expected_prev_hash != '0' -> false
  # Line num != 0 and expected_prev_hash = prev_hash -> true
  # Line num != 0 and expected_prev_hash != prev_hash -> false

  def test_check_prev_hash_zero_line_number_zero
    def @my_bc.print_err(msg, line_number); 1; end

    res = @my_bc.check_prev_hash('0', '1', 0)
    assert_equal false, res
  end

 # Tests returns false if expected prev is not the same as prev hash
  def test_check_prev_not_eq
    def @my_bc.print_err(msg, line_number); 1; end

    res = @my_bc.check_prev_hash('0', '1', 1)
    assert_equal false, res
  end

  # Tests returns true if expected prev is the same as prev hash
  def test_check_prev_eq
    def @my_bc.print_err(msg, line_number); 1; end

    res = @my_bc.check_prev_hash('1', '1', 1)
    assert_equal true, res
  end

  # UNIT TESTS FOR METHOD check_user_transactions(transactions, line_number, users)
  # Equivalence classes:
  # transactions -> 'test:another:final'
  # transactions -> nil
  # transactions -> ''

  def test_check_user_transactions_three
    transactions = 'test:another:final'
    def @my_bc.print_err(msg, line_number); 1; end
    def @my_bc.verify_transaction(transaction, line_number, users, count, len); true; end
    assert_equal @my_bc.check_user_transactions(transactions, 0, {}), 4
  end

  def test_check_user_transactions_nil
    transactions = nil
    def @my_bc.print_err(msg, line_number); 1; end
    def @my_bc.verify_transaction(transaction, line_number, users, count, len); true; end
    assert_equal @my_bc.check_user_transactions(transactions, 0, {}), -1
  end

  def test_check_user_transactions_empty
    transactions = ''
    def @my_bc.print_err(msg, line_number); 1; end
    def @my_bc.verify_transaction(transaction, line_number, users, count, len); true; end
    assert_equal @my_bc.check_user_transactions(transactions, 0, {}), -1
  end

  # UNIT TESTS FOR METHOD verify_transaction(transaction, line_number, users, count, len)
  # Equivalence classes:
  # transaction -> '569274~577469(9)' for the transfer symbol (should be >)
  # transaction -> '569274>577469|9|' as it should be (9) for the amount
  # transcation -> '569274>577469(9d4)' as the amount should be numeric
  # transaction -> '569274>577469()' as there is no amount here
  # transaction -> '569274>577469(12)' AND count == len, so the SYSTEM should be within the transaction

  def test_verify_transaction_wrong_transfer_symbol
    transaction = '569274~577469(9)'
    def @my_bc.print_err(msg, line_number); true; end
    def @my_bc.process_transaction(from_address, to_address, amount, users, line_number); true; end
    assert_equal -1, @my_bc.verify_transaction(transaction, 0, {}, 3, 5)
  end

  def test_verify_transaction_no_parens
    transaction = '569274>577469|9|'
    def @my_bc.print_err(msg, line_number); true; end
    def @my_bc.process_transaction(from_address, to_address, amount, users, line_number); true; end
    assert_equal -2, @my_bc.verify_transaction(transaction, 0, {}, 3, 5)
  end

  def test_verify_transaction_non_numeric_amount
    transaction = '569274>577469(9d4)'
    def @my_bc.print_err(msg, line_number); true; end
    def @my_bc.process_transaction(from_address, to_address, amount, users, line_number); true; end
    assert_equal -3, @my_bc.verify_transaction(transaction, 0, {}, 3, 5)
  end

  # EDGE CASE
  def test_verify_transaction_empty_amount
    transaction = '569274>577469()'
    def @my_bc.print_err(msg, line_number); true; end
    def @my_bc.process_transaction(from_address, to_address, amount, users, line_number); true; end
    assert_equal -3, @my_bc.verify_transaction(transaction, 0, {}, 3, 5)
  end

  def test_verify_transaction_system_not_at_end
    transaction = '569274>577469(12)'
    def @my_bc.print_err(msg, line_number); true; end
    def @my_bc.process_transaction(from_address, to_address, amount, users, line_number); true; end
    assert_equal -4, @my_bc.verify_transaction(transaction, 0, {}, 5, 5)
  end

  # UNIT TESTS FOR METHOD check_timestamp(timestamp_string, line_number, previous_timestamp_string)
  # Equivalence classes:
  # timestamp_string > previous_timestamp_string -> True
  # timestamp_string <= previous_timestamp_string -> False

  # EDGE CASE
  # Tests that if current timestamp is more recent that previous timestamp , returns true
  def test_timestamp_valid_nanos
    b = @my_bc.check_timestamp("1000.0001", 1, "1000.0000")
    assert_equal 1, b
  end

  # Tests that seconds difference works, returns true
  def test_timestamp_valid_seconds
    b = @my_bc.check_timestamp("1000.0000", 1, "100.0000")
    assert_equal 1, b
  end

  # EDGE CASE
  # Tests that if previous timestamp is more recent that current timestamp, returns false
  def test_timestamp_invalid_unequal
    b = @my_bc.check_timestamp("1000.0000", 1, "1000.0001")
    assert_equal -1, b
  end

  # EDGE CASE
  # Tests that equal timestamps are not valid
  def test_timestamp_invalid_equal
    b = @my_bc.check_timestamp("1000.0000", 1, "1000.0000")
    assert_equal -1, b
  end

  # UNIT TESTS FOR METHOD process_transaction(from_address, to_address, amount, users, line_number)
  # Equivalence classes:
  # NOTE: Each equivalence class only specifies input parameters that are INCORRECT
  # from_address = '12345'
  # to_address = '123456789'
  # from_address = 'SY$TEM'
  # to_address = '3l33ti'
  # amount = -12
  # from_address = 'SYSTEM' (makes sure that SYSTEM does not get balance deducted)
  # test with all parameters good

  def test_process_transaction_from_adr_length
    def @my_bc.print_err(msg, line_number); true; end
    from_address = '12345'
    to_address = '123456'
    amount = 12
    assert_equal @my_bc.process_transaction(from_address, to_address, amount, {}, 0), -1
  end

  def test_process_transaction_to_adr_length
    def @my_bc.print_err(msg, line_number); true; end
    from_address = '123456'
    to_address = '123456789'
    amount = 12
    assert_equal @my_bc.process_transaction(from_address, to_address, amount, {}, 0), -1
  end

  def test_process_transaction_from_non_system
    def @my_bc.print_err(msg, line_number); true; end
    from_address = 'SY$TEM'
    to_address = '123456'
    amount = 12
    assert_equal @my_bc.process_transaction(from_address, to_address, amount, {}, 0), -2
  end

  def test_process_transaction_from_sys_to_nonumeric
    def @my_bc.print_err(msg, line_number); true; end
    from_address = 'SYSTEM'
    to_address = '3l33ti'
    amount = 12
    assert_equal @my_bc.process_transaction(from_address, to_address, amount, {}, 0), -2
  end

  def test_process_transaction_neg_amount
    def @my_bc.print_err(msg, line_number); true; end
    from_address = 'SYSTEM'
    to_address = '123456'
    amount = -12
    assert_equal @my_bc.process_transaction(from_address, to_address, amount, {}, 0), -3
  end

  # This is because we don't want to deduct coins from the 'system'
  def test_process_transaction_early_system_return
    def @my_bc.print_err(msg, line_number); true; end
    from_address = 'SYSTEM'
    to_address = '123456'
    amount = 12
    assert_equal @my_bc.process_transaction(from_address, to_address, amount, {}, 0), -4
  end

  def test_process_transaction_completely_successful
    def @my_bc.print_err(msg, line_number); true; end
    from_address = '123456'
    to_address = '123456'
    amount = 12
    assert_equal @my_bc.process_transaction(from_address, to_address, amount, {}, 0), 0
  end

  # UNIT TESTS FOR METHOD calc_hash(hash_input, utf_vals)

  # Tests that the correct hex hash is returned for a given character
  def test_calc_hash
    utf_vals = {}
    hash_input = 'A'
    res = @my_bc.calc_hash(hash_input, utf_vals)
    assert_equal "78b9", res
  end

  # UNIT TESTS FOR METHOD check_user_values(users, line_number)
  # Equivalence classes:
  # Rantly -> a hash map of random negative integer values

  def test_check_user_values_negative
    property_of {
      key = integer.abs % 999999
      value = -(integer.abs) # Fancy ruby to ensure all negative values
      users = {}
      users[key] = value
      users
    }.check(100) { |users|
      def @my_bc.print_err(msg, line_number); 1; end
      assert_equal @my_bc.check_user_values(users, 0), -1
    }
  end

  # UNIT TESTS FOR METHOD number?()
  # Equivalence classes:
  # String in form of a float (0.43523, 435.24363, 45, 0, etc.) -> True
  # String not in form of a float (hello, 1.1.1.1, *(&#92, etc. )) -> False

  # Tests if a string in the form of a number returns true
  def test_number_float
    b = @my_bc.number?("123.123456789")
    assert_equal true, b
  end

  def test_number_integer
    b = @my_bc.number?("111")
    assert_equal true, b
  end

  # Tests if a string not in the form of a number returns false
  def test_number_not_float
    b = @my_bc.number?("hello")
    assert_equal false, b
  end

  # Tests that an invalid number returns falses
  def test_number_two_decimals
    b = @my_bc.number?("987.654.321")
    assert_equal false, b
  end

  # UNIT TESTS FOR METHOD print_err(msg, line_number)
  # Equivalence classes:
  # line_number = '12'
  # msg = 12345

  def test_print_err_line_number_string
    assert_equal @my_bc.print_err("Hello world!", "12"), -1
  end

  def test_print_err_msg_integer
    assert_equal @my_bc.print_err(12345, 12), -1
  end

end
