extends GdUnitTestSuite

# These tests assert that multi-byte values are encoded LITTLE-ENDIAN,
# matching @colyseus/schema.

# --- Encoder: little-endian byte order ---

func test_int16_little_endian():
	var encoder := Encoder.new()
	encoder.encode_int16(0x0102)  # 258 decimal
	var data := encoder.get_data()
	assert_int(data[0]).is_equal(0x02).override_failure_message("int16 low byte should be first (little-endian)")
	assert_int(data[1]).is_equal(0x01).override_failure_message("int16 high byte should be second")

func test_uint16_little_endian():
	var encoder := Encoder.new()
	encoder.encode_uint16(0x0102)
	var data := encoder.get_data()
	assert_int(data[0]).is_equal(0x02).override_failure_message("uint16 low byte first")
	assert_int(data[1]).is_equal(0x01).override_failure_message("uint16 high byte second")

func test_int32_little_endian():
	var encoder := Encoder.new()
	encoder.encode_int32(0x01020304)
	var data := encoder.get_data()
	assert_int(data[0]).is_equal(0x04).override_failure_message("int32 byte 0 (lowest)")
	assert_int(data[1]).is_equal(0x03).override_failure_message("int32 byte 1")
	assert_int(data[2]).is_equal(0x02).override_failure_message("int32 byte 2")
	assert_int(data[3]).is_equal(0x01).override_failure_message("int32 byte 3 (highest)")

func test_uint32_little_endian():
	var encoder := Encoder.new()
	encoder.encode_uint32(0x01020304)
	var data := encoder.get_data()
	assert_int(data[0]).is_equal(0x04).override_failure_message("uint32 byte 0 (lowest)")
	assert_int(data[1]).is_equal(0x03).override_failure_message("uint32 byte 1")
	assert_int(data[2]).is_equal(0x02).override_failure_message("uint32 byte 2")
	assert_int(data[3]).is_equal(0x01).override_failure_message("uint32 byte 3 (highest)")

# --- Decoder: little-endian byte order ---

func test_decode_int16_little_endian():
	# 0x0102 in little-endian = [0x02, 0x01]
	var data := PackedByteArray([0x02, 0x01])
	var decoder := Decoder.new(data)
	assert_int(decoder.decode_int16()).is_equal(0x0102)

func test_decode_uint16_little_endian():
	var data := PackedByteArray([0x02, 0x01])
	var decoder := Decoder.new(data)
	assert_int(decoder.decode_uint16()).is_equal(0x0102)

func test_decode_int32_little_endian():
	# 0x01020304 in little-endian = [0x04, 0x03, 0x02, 0x01]
	var data := PackedByteArray([0x04, 0x03, 0x02, 0x01])
	var decoder := Decoder.new(data)
	assert_int(decoder.decode_int32()).is_equal(0x01020304)

func test_decode_uint32_little_endian():
	var data := PackedByteArray([0x04, 0x03, 0x02, 0x01])
	var decoder := Decoder.new(data)
	assert_int(decoder.decode_uint32()).is_equal(0x01020304)

# --- Float: little-endian ---
# float32(1.0) = 0x3F800000 -> LE bytes: [0x00, 0x00, 0x80, 0x3F]

func test_decode_float32_little_endian():
	var data := PackedByteArray([0x00, 0x00, 0x80, 0x3F])
	var decoder := Decoder.new(data)
	assert_float(decoder.decode_float32()).is_equal_approx(1.0, 0.0001)

func test_decode_float64_little_endian():
	# 1.0 as float64 LE: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x3F]
	var data := PackedByteArray([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x3F])
	var decoder := Decoder.new(data)
	assert_float(decoder.decode_float64()).is_equal_approx(1.0, 0.0001)
