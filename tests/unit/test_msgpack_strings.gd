extends GdUnitTestSuite

# These tests assert that string encoding matches @colyseus/schema's
# msgpack-based format. The current SDK uses varint-length + raw bytes,
# so these will FAIL until the encoder is rewritten.
#
# Reference: @colyseus/schema/lib/encoding/encode.js string()
#
# Format:
#   fixstr (len < 32):   prefix = 0xA0 | len, then UTF-8 bytes
#   str8 (len < 256):    prefix 0xD9, uint8 len, then UTF-8 bytes
#   str16 (len < 65536): prefix 0xDA, uint16 LE len, then UTF-8 bytes
#   str32:               prefix 0xDB, uint32 LE len, then UTF-8 bytes

# --- Encode ---

func test_encode_string_empty():
	var encoder := Encoder.new()
	encoder.encode_string("")
	var data := encoder.get_data()
	# Empty string: fixstr with len=0 → 0xA0
	assert_int(data.size()).is_equal(1)
	assert_int(data[0]).is_equal(0xA0)

func test_encode_string_short():
	var encoder := Encoder.new()
	encoder.encode_string("hi")
	var data := encoder.get_data()
	# "hi" = 2 bytes → fixstr: 0xA0 | 2 = 0xA2, then 'h', 'i'
	assert_int(data.size()).is_equal(3)
	assert_int(data[0]).is_equal(0xA2)
	assert_int(data[1]).is_equal(0x68)  # 'h'
	assert_int(data[2]).is_equal(0x69)  # 'i'

func test_encode_string_hello():
	var encoder := Encoder.new()
	encoder.encode_string("hello")
	var data := encoder.get_data()
	# "hello" = 5 bytes → fixstr: 0xA0 | 5 = 0xA5
	assert_int(data[0]).is_equal(0xA5)
	assert_str(data.slice(1).get_string_from_utf8()).is_equal("hello")

func test_encode_string_max_fixstr():
	# 31 bytes = max fixstr length
	var s := "abcdefghijklmnopqrstuvwxyz01234"  # 31 chars
	var encoder := Encoder.new()
	encoder.encode_string(s)
	var data := encoder.get_data()
	# fixstr: 0xA0 | 31 = 0xBF
	assert_int(data[0]).is_equal(0xBF)

func test_encode_string_str8():
	# 32 bytes = first str8 length
	var s := "abcdefghijklmnopqrstuvwxyz012345"  # 32 chars
	var encoder := Encoder.new()
	encoder.encode_string(s)
	var data := encoder.get_data()
	# str8: prefix 0xD9, then uint8 length
	assert_int(data[0]).is_equal(0xD9)
	assert_int(data[1]).is_equal(32)
	assert_str(data.slice(2).get_string_from_utf8()).is_equal(s)

# --- Decode ---

func test_decode_string_empty():
	var data := PackedByteArray([0xA0])
	var decoder := Decoder.new(data)
	assert_str(decoder.decode_string()).is_equal("")

func test_decode_string_fixstr():
	# "hi" = [0xA2, 0x68, 0x69]
	var data := PackedByteArray([0xA2, 0x68, 0x69])
	var decoder := Decoder.new(data)
	assert_str(decoder.decode_string()).is_equal("hi")

func test_decode_string_str8():
	# 32-char string with str8 prefix
	var s := "abcdefghijklmnopqrstuvwxyz012345"
	var data := PackedByteArray([0xD9, 32])
	data.append_array(s.to_utf8_buffer())
	var decoder := Decoder.new(data)
	assert_str(decoder.decode_string()).is_equal(s)

func test_encode_decode_roundtrip():
	var encoder := Encoder.new()
	encoder.encode_string("hello world")
	var decoder := Decoder.new(encoder.get_data())
	assert_str(decoder.decode_string()).is_equal("hello world")

func test_encode_string_unicode():
	var encoder := Encoder.new()
	encoder.encode_string("cafe\u0301")  # café with combining accent
	var data := encoder.get_data()
	# Should be fixstr with correct UTF-8 byte length
	var utf8_len := "cafe\u0301".to_utf8_buffer().size()
	assert_int(data[0]).is_equal(0xA0 | utf8_len)

func test_encode_string_str8_boundary():
	# 100-char string should use str8 encoding
	var s := ""
	for i in 100:
		s += "x"
	var encoder := Encoder.new()
	encoder.encode_string(s)
	var data := encoder.get_data()
	assert_int(data[0]).is_equal(0xD9)
	assert_int(data[1]).is_equal(100)
	assert_int(data.size()).is_equal(102)  # prefix + len + 100 chars

func test_decode_string_str8_boundary():
	var s := ""
	for i in 100:
		s += "y"
	var data := PackedByteArray([0xD9, 100])
	data.append_array(s.to_utf8_buffer())
	var decoder := Decoder.new(data)
	assert_str(decoder.decode_string()).is_equal(s)

func test_encode_decode_str8_roundtrip():
	var s := ""
	for i in 200:
		s += "z"
	var encoder := Encoder.new()
	encoder.encode_string(s)
	var decoder := Decoder.new(encoder.get_data())
	assert_str(decoder.decode_string()).is_equal(s)
