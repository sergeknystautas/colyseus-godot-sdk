extends GdUnitTestSuite

# Tests for the raw typed encoder methods.
# These methods write values WITHOUT type tag prefixes,
# matching @colyseus/schema's encoder.

func test_encode_boolean_true():
	var encoder := Encoder.new()
	encoder.encode_boolean(true)
	var result := encoder.get_data()
	assert_int(result.size()).is_equal(1)
	assert_int(result[0]).is_equal(1)

func test_encode_boolean_false():
	var encoder := Encoder.new()
	encoder.encode_boolean(false)
	var result := encoder.get_data()
	assert_int(result.size()).is_equal(1)
	assert_int(result[0]).is_equal(0)

func test_encode_string_empty():
	var encoder := Encoder.new()
	encoder.encode_string("")
	var result := encoder.get_data()
	# Empty string: fixstr with len=0 -> 0xA0
	assert_int(result.size()).is_equal(1)
	assert_int(result[0]).is_equal(0xA0)

func test_encode_string():
	var encoder := Encoder.new()
	encoder.encode_string("hello")
	var result := encoder.get_data()
	# "hello" = 5 bytes -> fixstr: 0xA0 | 5 = 0xA5
	assert_int(result[0]).is_equal(0xA5)
	assert_str(result.slice(1).get_string_from_utf8()).is_equal("hello")

func test_encode_string_unicode():
	var encoder := Encoder.new()
	encoder.encode_string("hello world")
	var result := encoder.get_data()
	# "hello world" = 11 bytes -> fixstr: 0xA0 | 11 = 0xAB
	assert_int(result[0]).is_equal(0xAB)
	assert_str(result.slice(1).get_string_from_utf8()).is_equal("hello world")

func test_encode_int8_positive():
	var encoder := Encoder.new()
	encoder.encode_int8(127)
	var result := encoder.get_data()
	assert_int(result.size()).is_equal(1)
	assert_int(result[0]).is_equal(127)

func test_encode_int8_negative():
	var encoder := Encoder.new()
	encoder.encode_int8(-128)
	var result := encoder.get_data()
	assert_int(result.size()).is_equal(1)
	assert_int(result[0]).is_equal(0x80)

func test_encode_int8_zero():
	var encoder := Encoder.new()
	encoder.encode_int8(0)
	var result := encoder.get_data()
	assert_int(result.size()).is_equal(1)
	assert_int(result[0]).is_equal(0)

func test_encode_uint8_max():
	var encoder := Encoder.new()
	encoder.encode_uint8(255)
	var result := encoder.get_data()
	assert_int(result.size()).is_equal(1)
	assert_int(result[0]).is_equal(0xFF)

func test_encode_uint8_zero():
	var encoder := Encoder.new()
	encoder.encode_uint8(0)
	var result := encoder.get_data()
	assert_int(result.size()).is_equal(1)
	assert_int(result[0]).is_equal(0)

func test_encode_int16():
	var encoder := Encoder.new()
	encoder.encode_int16(32767)
	var result := encoder.get_data()
	assert_int(result.size()).is_equal(2)

func test_encode_int16_negative():
	var encoder := Encoder.new()
	encoder.encode_int16(-32768)
	var result := encoder.get_data()
	assert_int(result.size()).is_equal(2)

func test_encode_uint16_max():
	var encoder := Encoder.new()
	encoder.encode_uint16(65535)
	var result := encoder.get_data()
	assert_int(result.size()).is_equal(2)

func test_encode_int32():
	var encoder := Encoder.new()
	encoder.encode_int32(2147483647)
	var result := encoder.get_data()
	assert_int(result.size()).is_equal(4)

func test_encode_int32_negative():
	var encoder := Encoder.new()
	encoder.encode_int32(-2147483648)
	var result := encoder.get_data()
	assert_int(result.size()).is_equal(4)

func test_encode_uint32_max():
	var encoder := Encoder.new()
	encoder.encode_uint32(4294967295)
	var result := encoder.get_data()
	assert_int(result.size()).is_equal(4)

func test_encode_float32():
	var encoder := Encoder.new()
	encoder.encode_float32(3.14)
	var result := encoder.get_data()
	assert_int(result.size()).is_equal(4)

func test_encode_float32_negative():
	var encoder := Encoder.new()
	encoder.encode_float32(-2.5)
	var result := encoder.get_data()
	assert_int(result.size()).is_equal(4)

func test_encode_float64():
	var encoder := Encoder.new()
	encoder.encode_float64(3.14159265359)
	var result := encoder.get_data()
	assert_int(result.size()).is_equal(8)

func test_encode_float64_negative():
	var encoder := Encoder.new()
	encoder.encode_float64(-2.71828182846)
	var result := encoder.get_data()
	assert_int(result.size()).is_equal(8)

func test_multiple_values():
	var encoder := Encoder.new()
	encoder.encode_int8(42)        # 1 byte
	encoder.encode_string("test")  # 1 prefix + 4 = 5 bytes
	encoder.encode_boolean(true)   # 1 byte
	var result := encoder.get_data()
	assert_int(result.size()).is_equal(7)
