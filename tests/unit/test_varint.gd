extends GdUnitTestSuite

func test_encode_varint_single_byte():
	var encoder := Encoder.new()
	encoder.encode_varint(127)
	var result := encoder.get_data()
	assert_int(result.size()).is_equal(1)
	assert_int(result[0]).is_equal(127)

func test_encode_varint_two_bytes():
	var encoder := Encoder.new()
	encoder.encode_varint(300)
	var result := encoder.get_data()
	assert_int(result.size()).is_equal(2)
	assert_int(result[0]).is_equal(0b10101100)
	assert_int(result[1]).is_equal(0b00000010)

func test_decode_varint_single_byte():
	var data := PackedByteArray([127])
	var decoder := Decoder.new(data)
	assert_int(decoder.decode_varint()).is_equal(127)

func test_decode_varint_two_bytes():
	var data := PackedByteArray([0b10101100, 0b00000010])
	var decoder := Decoder.new(data)
	assert_int(decoder.decode_varint()).is_equal(300)

func test_encode_varint_zero():
	var encoder := Encoder.new()
	encoder.encode_varint(0)
	assert_int(encoder.get_data()[0]).is_equal(0)

func test_encode_varint_large():
	var encoder := Encoder.new()
	encoder.encode_varint(16384)
	var result := encoder.get_data()
	assert_int(result.size()).is_equal(3)

func test_decode_varint_zero():
	var data := PackedByteArray([0])
	var decoder := Decoder.new(data)
	assert_int(decoder.decode_varint()).is_equal(0)

func test_decode_varint_large():
	var data := PackedByteArray([0x80, 0x80, 0x01])
	var decoder := Decoder.new(data)
	assert_int(decoder.decode_varint()).is_equal(16384)
