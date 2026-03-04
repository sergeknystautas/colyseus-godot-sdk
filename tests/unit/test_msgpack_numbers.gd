extends GdUnitTestSuite

# These tests assert that number encoding matches @colyseus/schema's
# msgpack-based format. The current SDK uses a completely different
# encoding (LEB128 varint + custom type tags), so these will ALL FAIL
# until the encoder is rewritten.
#
# Reference: @colyseus/schema/lib/encoding/encode.js
#
# Format:
#   positive fixint:  0x00-0x7F (value as-is, 1 byte)
#   uint8:            0xCC + 1 byte
#   uint16:           0xCD + 2 bytes (LE)
#   uint32:           0xCE + 4 bytes (LE)
#   uint64:           0xCF + 8 bytes (LE)
#   int8:             0xD0 + 1 byte
#   int16:            0xD1 + 2 bytes (LE)
#   int32:            0xD2 + 4 bytes (LE)
#   int64:            0xD3 + 8 bytes (LE)
#   float32:          0xCA + 4 bytes (LE)
#   float64:          0xCB + 8 bytes (LE)
#   negative fixint:  0xE0 | (value + 0x20) for -1 to -32

# --- Positive fixint (0-127): value as single byte, no prefix ---

func test_encode_number_zero():
	var encoder := Encoder.new()
	encoder.encode_number(0)
	var data := encoder.get_data()
	assert_int(data.size()).is_equal(1)
	assert_int(data[0]).is_equal(0)

func test_encode_number_1():
	var encoder := Encoder.new()
	encoder.encode_number(1)
	var data := encoder.get_data()
	assert_int(data.size()).is_equal(1)
	assert_int(data[0]).is_equal(1)

func test_encode_number_127():
	var encoder := Encoder.new()
	encoder.encode_number(127)
	var data := encoder.get_data()
	assert_int(data.size()).is_equal(1)
	assert_int(data[0]).is_equal(127)

# --- uint8: prefix 0xCC ---

func test_encode_number_128():
	var encoder := Encoder.new()
	encoder.encode_number(128)
	var data := encoder.get_data()
	assert_int(data.size()).is_equal(2)
	assert_int(data[0]).is_equal(0xCC)
	assert_int(data[1]).is_equal(128)

func test_encode_number_255():
	var encoder := Encoder.new()
	encoder.encode_number(255)
	var data := encoder.get_data()
	assert_int(data.size()).is_equal(2)
	assert_int(data[0]).is_equal(0xCC)
	assert_int(data[1]).is_equal(255)

# --- uint16: prefix 0xCD + 2 LE bytes ---

func test_encode_number_256():
	var encoder := Encoder.new()
	encoder.encode_number(256)
	var data := encoder.get_data()
	assert_int(data.size()).is_equal(3)
	assert_int(data[0]).is_equal(0xCD)
	assert_int(data[1]).is_equal(0x00)  # low byte
	assert_int(data[2]).is_equal(0x01)  # high byte

func test_encode_number_300():
	var encoder := Encoder.new()
	encoder.encode_number(300)
	var data := encoder.get_data()
	assert_int(data.size()).is_equal(3)
	assert_int(data[0]).is_equal(0xCD)
	assert_int(data[1]).is_equal(0x2C)  # 300 & 0xFF = 44 = 0x2C
	assert_int(data[2]).is_equal(0x01)  # 300 >> 8 = 1

func test_encode_number_65535():
	var encoder := Encoder.new()
	encoder.encode_number(65535)
	var data := encoder.get_data()
	assert_int(data.size()).is_equal(3)
	assert_int(data[0]).is_equal(0xCD)
	assert_int(data[1]).is_equal(0xFF)
	assert_int(data[2]).is_equal(0xFF)

# --- uint32: prefix 0xCE + 4 LE bytes ---

func test_encode_number_65536():
	var encoder := Encoder.new()
	encoder.encode_number(65536)
	var data := encoder.get_data()
	assert_int(data.size()).is_equal(5)
	assert_int(data[0]).is_equal(0xCE)
	assert_int(data[1]).is_equal(0x00)
	assert_int(data[2]).is_equal(0x00)
	assert_int(data[3]).is_equal(0x01)
	assert_int(data[4]).is_equal(0x00)

# --- Negative fixint: 0xE0 | (value + 0x20) ---

func test_encode_number_neg1():
	var encoder := Encoder.new()
	encoder.encode_number(-1)
	var data := encoder.get_data()
	assert_int(data.size()).is_equal(1)
	assert_int(data[0]).is_equal(0xFF)  # 0xE0 | (-1 + 0x20) = 0xE0 | 0x1F = 0xFF

func test_encode_number_neg32():
	var encoder := Encoder.new()
	encoder.encode_number(-32)
	var data := encoder.get_data()
	assert_int(data.size()).is_equal(1)
	assert_int(data[0]).is_equal(0xE0)  # 0xE0 | (-32 + 0x20) = 0xE0 | 0 = 0xE0

# --- int8: prefix 0xD0 ---

func test_encode_number_neg33():
	var encoder := Encoder.new()
	encoder.encode_number(-33)
	var data := encoder.get_data()
	assert_int(data.size()).is_equal(2)
	assert_int(data[0]).is_equal(0xD0)
	assert_int(data[1]).is_equal((-33) & 0xFF)  # 0xDF

func test_encode_number_neg128():
	var encoder := Encoder.new()
	encoder.encode_number(-128)
	var data := encoder.get_data()
	assert_int(data.size()).is_equal(2)
	assert_int(data[0]).is_equal(0xD0)
	assert_int(data[1]).is_equal(0x80)

# --- int16: prefix 0xD1 + 2 LE bytes ---

func test_encode_number_neg129():
	var encoder := Encoder.new()
	encoder.encode_number(-129)
	var data := encoder.get_data()
	assert_int(data.size()).is_equal(3)
	assert_int(data[0]).is_equal(0xD1)
	# -129 = 0xFF7F in LE: [0x7F, 0xFF]
	assert_int(data[1]).is_equal(0x7F)
	assert_int(data[2]).is_equal(0xFF)

# --- float64: prefix 0xCB + 8 LE bytes ---
# @colyseus/schema encodes all non-integer numbers as float64

func test_encode_number_float():
	var encoder := Encoder.new()
	encoder.encode_number(3.14)
	var data := encoder.get_data()
	assert_int(data.size()).is_equal(9)
	assert_int(data[0]).is_equal(0xCB)  # float64 prefix

# --- Decode ---

func test_decode_number_positive_fixint():
	var data := PackedByteArray([42])
	var decoder := Decoder.new(data)
	assert_int(decoder.decode_number()).is_equal(42)

func test_decode_number_uint8():
	var data := PackedByteArray([0xCC, 200])
	var decoder := Decoder.new(data)
	assert_int(decoder.decode_number()).is_equal(200)

func test_decode_number_uint16():
	# 300 = [0xCD, 0x2C, 0x01]
	var data := PackedByteArray([0xCD, 0x2C, 0x01])
	var decoder := Decoder.new(data)
	assert_int(decoder.decode_number()).is_equal(300)

func test_decode_number_negative_fixint():
	# -1 = 0xFF
	var data := PackedByteArray([0xFF])
	var decoder := Decoder.new(data)
	assert_int(decoder.decode_number()).is_equal(-1)

func test_decode_number_int8():
	# -100 = [0xD0, 0x9C]
	var data := PackedByteArray([0xD0, 0x9C])
	var decoder := Decoder.new(data)
	assert_int(decoder.decode_number()).is_equal(-100)

func test_decode_number_float64():
	# 1.0 as float64: [0xCB, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x3F]
	var data := PackedByteArray([0xCB, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x3F])
	var decoder := Decoder.new(data)
	assert_float(decoder.decode_number()).is_equal_approx(1.0, 0.0001)

func test_decode_number_uint32():
	# 100000 = 0x000186A0 LE: [0xA0, 0x86, 0x01, 0x00]
	var data := PackedByteArray([0xCE, 0xA0, 0x86, 0x01, 0x00])
	var decoder := Decoder.new(data)
	assert_int(decoder.decode_number()).is_equal(100000)

func test_decode_number_int16():
	# -1000 = 0xFC18 LE: [0x18, 0xFC]
	var data := PackedByteArray([0xD1, 0x18, 0xFC])
	var decoder := Decoder.new(data)
	assert_int(decoder.decode_number()).is_equal(-1000)

func test_decode_number_int32():
	# -100000 = 0xFFFE7960 LE: [0x60, 0x79, 0xFE, 0xFF]
	var data := PackedByteArray([0xD2, 0x60, 0x79, 0xFE, 0xFF])
	var decoder := Decoder.new(data)
	assert_int(decoder.decode_number()).is_equal(-100000)

func test_decode_number_float32():
	# 3.14 as float32 LE: [0xC3, 0xF5, 0x48, 0x40]
	var data := PackedByteArray([0xCA, 0xC3, 0xF5, 0x48, 0x40])
	var decoder := Decoder.new(data)
	assert_float(decoder.decode_number()).is_equal_approx(3.14, 0.01)

func test_encode_decode_number_roundtrip_large_positive():
	var encoder := Encoder.new()
	encoder.encode_number(1000000)
	var decoder := Decoder.new(encoder.get_data())
	assert_int(decoder.decode_number()).is_equal(1000000)

func test_encode_decode_number_roundtrip_large_negative():
	var encoder := Encoder.new()
	encoder.encode_number(-50000)
	var decoder := Decoder.new(encoder.get_data())
	assert_int(decoder.decode_number()).is_equal(-50000)

func test_encode_decode_number_roundtrip_float():
	var encoder := Encoder.new()
	encoder.encode_number(2.718)
	var decoder := Decoder.new(encoder.get_data())
	assert_float(decoder.decode_number()).is_equal_approx(2.718, 0.001)
