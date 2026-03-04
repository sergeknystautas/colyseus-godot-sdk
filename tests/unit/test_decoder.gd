extends GdUnitTestSuite

# Tests for raw typed decoder methods and roundtrips.

func test_decode_boolean_true():
	var data := PackedByteArray([1])
	var decoder := Decoder.new(data)
	assert_bool(decoder.decode_boolean()).is_true()

func test_decode_boolean_false():
	var data := PackedByteArray([0])
	var decoder := Decoder.new(data)
	assert_bool(decoder.decode_boolean()).is_false()

func test_decode_string_empty():
	# fixstr with len=0: 0xA0
	var data := PackedByteArray([0xA0])
	var decoder := Decoder.new(data)
	assert_str(decoder.decode_string()).is_equal("")

func test_decode_string():
	# "hello" as fixstr: 0xA5 + bytes
	var data := PackedByteArray([0xA5])
	data.append_array("hello".to_utf8_buffer())
	var decoder := Decoder.new(data)
	assert_str(decoder.decode_string()).is_equal("hello")

func test_decode_string_unicode():
	# "hello world" = 11 bytes -> fixstr 0xAB
	var data := PackedByteArray([0xAB])
	data.append_array("hello world".to_utf8_buffer())
	var decoder := Decoder.new(data)
	assert_str(decoder.decode_string()).is_equal("hello world")

func test_decode_int8_positive():
	var data := PackedByteArray([127])
	var decoder := Decoder.new(data)
	assert_int(decoder.decode_int8()).is_equal(127)

func test_decode_int8_negative():
	var data := PackedByteArray([0x80])
	var decoder := Decoder.new(data)
	assert_int(decoder.decode_int8()).is_equal(-128)

func test_decode_int8_zero():
	var data := PackedByteArray([0])
	var decoder := Decoder.new(data)
	assert_int(decoder.decode_int8()).is_equal(0)

func test_decode_uint8_max():
	var data := PackedByteArray([0xFF])
	var decoder := Decoder.new(data)
	assert_int(decoder.decode_uint8()).is_equal(255)

func test_decode_uint8_zero():
	var data := PackedByteArray([0])
	var decoder := Decoder.new(data)
	assert_int(decoder.decode_uint8()).is_equal(0)

func test_decode_roundtrip_boolean():
	var encoder := Encoder.new()
	encoder.encode_boolean(true)
	encoder.encode_boolean(false)
	var decoder := Decoder.new(encoder.get_data())
	assert_bool(decoder.decode_boolean()).is_true()
	assert_bool(decoder.decode_boolean()).is_false()

func test_decode_roundtrip_float32():
	var encoder := Encoder.new()
	encoder.encode_float32(3.14)
	var decoder := Decoder.new(encoder.get_data())
	assert_float(decoder.decode_float32()).is_equal_approx(3.14, 0.001)

func test_decode_roundtrip_float32_negative():
	var encoder := Encoder.new()
	encoder.encode_float32(-2.5)
	var decoder := Decoder.new(encoder.get_data())
	assert_float(decoder.decode_float32()).is_equal_approx(-2.5, 0.001)

func test_decode_roundtrip_float64():
	var encoder := Encoder.new()
	encoder.encode_float64(3.14159265359)
	var decoder := Decoder.new(encoder.get_data())
	assert_float(decoder.decode_float64()).is_equal_approx(3.14159265359, 0.000001)

func test_decode_roundtrip_float64_negative():
	var encoder := Encoder.new()
	encoder.encode_float64(-2.71828182846)
	var decoder := Decoder.new(encoder.get_data())
	assert_float(decoder.decode_float64()).is_equal_approx(-2.71828182846, 0.000001)

func test_decode_roundtrip_int8():
	var encoder := Encoder.new()
	encoder.encode_int8(-100)
	var decoder := Decoder.new(encoder.get_data())
	assert_int(decoder.decode_int8()).is_equal(-100)

func test_decode_roundtrip_uint8():
	var encoder := Encoder.new()
	encoder.encode_uint8(200)
	var decoder := Decoder.new(encoder.get_data())
	assert_int(decoder.decode_uint8()).is_equal(200)

func test_decode_roundtrip_int16():
	var encoder := Encoder.new()
	encoder.encode_int16(-10000)
	var decoder := Decoder.new(encoder.get_data())
	assert_int(decoder.decode_int16()).is_equal(-10000)

func test_decode_roundtrip_uint16():
	var encoder := Encoder.new()
	encoder.encode_uint16(50000)
	var decoder := Decoder.new(encoder.get_data())
	assert_int(decoder.decode_uint16()).is_equal(50000)

func test_decode_roundtrip_int32():
	var encoder := Encoder.new()
	encoder.encode_int32(-1000000)
	var decoder := Decoder.new(encoder.get_data())
	assert_int(decoder.decode_int32()).is_equal(-1000000)

func test_decode_roundtrip_uint32():
	var encoder := Encoder.new()
	encoder.encode_uint32(3000000000)
	var decoder := Decoder.new(encoder.get_data())
	assert_int(decoder.decode_uint32()).is_equal(3000000000)

func test_decode_boolean_nonzero_is_true():
	# Any nonzero byte should decode as true
	var data := PackedByteArray([255])
	var decoder := Decoder.new(data)
	assert_bool(decoder.decode_boolean()).is_true()

func test_decode_int16_direct():
	# -1000 = 0xFC18 LE: [0x18, 0xFC]
	var data := PackedByteArray([0x18, 0xFC])
	var decoder := Decoder.new(data)
	assert_int(decoder.decode_int16()).is_equal(-1000)

func test_decode_uint16_direct():
	# 1000 = 0x03E8 LE: [0xE8, 0x03]
	var data := PackedByteArray([0xE8, 0x03])
	var decoder := Decoder.new(data)
	assert_int(decoder.decode_uint16()).is_equal(1000)

func test_decode_int32_direct():
	# -100000 LE
	var encoder := Encoder.new()
	encoder.encode_int32(-100000)
	var decoder := Decoder.new(encoder.get_data())
	assert_int(decoder.decode_int32()).is_equal(-100000)

func test_decode_uint32_direct():
	# 100000 LE
	var encoder := Encoder.new()
	encoder.encode_uint32(100000)
	var decoder := Decoder.new(encoder.get_data())
	assert_int(decoder.decode_uint32()).is_equal(100000)

func test_decode_float32_zero():
	var data := PackedByteArray([0x00, 0x00, 0x00, 0x00])
	var decoder := Decoder.new(data)
	assert_float(decoder.decode_float32()).is_equal_approx(0.0, 0.001)

func test_decode_float64_zero():
	var data := PackedByteArray([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
	var decoder := Decoder.new(data)
	assert_float(decoder.decode_float64()).is_equal_approx(0.0, 0.001)

func test_decode_u8_alias():
	var data := PackedByteArray([200])
	var decoder := Decoder.new(data)
	assert_int(decoder.decode_u8()).is_equal(200)

func test_decode_multiple_sequential_values():
	var encoder := Encoder.new()
	encoder.encode_uint8(42)
	encoder.encode_int16(-500)
	encoder.encode_float32(1.5)
	var decoder := Decoder.new(encoder.get_data())
	assert_int(decoder.decode_uint8()).is_equal(42)
	assert_int(decoder.decode_int16()).is_equal(-500)
	assert_float(decoder.decode_float32()).is_equal_approx(1.5, 0.001)
