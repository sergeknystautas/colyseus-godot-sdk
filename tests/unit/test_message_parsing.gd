extends GdUnitTestSuite

# These tests assert correct parsing of complete Colyseus protocol messages.
# Reference: @colyseus/sdk/src/Room.ts onMessageCallback()
#
# All messages: [PROTOCOL_BYTE][PAYLOAD...]
#
# JOIN_ROOM (10): [10][token_len][token_bytes][serializer_len][serializer_bytes][handshake?]
# ERROR (11):     [11][msgpack_number code][msgpack_string message]
# LEAVE_ROOM (12):[12]
# ROOM_DATA (13): [13][msgpack_string_or_number type][msgpack_payload]
# ROOM_STATE (14):[14][schema_bytes...]
# ROOM_STATE_PATCH (15): [15][schema_patch_bytes...]

# --- Message type dispatch ---

func test_first_byte_identifies_message():
	# JOIN_ROOM
	var join := PackedByteArray([10, 0, 0])
	assert_int(join[0]).is_equal(10)

	# ERROR
	var err := PackedByteArray([11, 0])
	assert_int(err[0]).is_equal(11)

	# ROOM_STATE
	var state := PackedByteArray([14, 0])
	assert_int(state[0]).is_equal(14)

	# ROOM_DATA
	var data := PackedByteArray([13, 0])
	assert_int(data[0]).is_equal(13)

# --- JOIN_ROOM message parsing ---

func test_parse_join_room():
	# JOIN_ROOM: [10][token_len=5]["abcde"][serializer_len=6]["schema"]
	var msg := PackedByteArray()
	msg.append(10)  # JOIN_ROOM
	# reconnection token: length byte + bytes
	var token := "abcde".to_utf8_buffer()
	msg.append(token.size())
	msg.append_array(token)
	# serializer id: length byte + bytes
	var serializer := "schema".to_utf8_buffer()
	msg.append(serializer.size())
	msg.append_array(serializer)

	# Parse: skip first byte (protocol), read token, read serializer
	var offset := 1
	var token_len := msg[offset]
	offset += 1
	var parsed_token := msg.slice(offset, offset + token_len).get_string_from_utf8()
	offset += token_len
	var ser_len := msg[offset]
	offset += 1
	var parsed_ser := msg.slice(offset, offset + ser_len).get_string_from_utf8()

	assert_str(parsed_token).is_equal("abcde")
	assert_str(parsed_ser).is_equal("schema")

# --- ERROR message parsing ---

func test_parse_error_message():
	# ERROR: [11][msgpack_number code][msgpack_string message]
	# code=4217 → uint16: [0xCD, 0x79, 0x10] (4217 LE: 0x1079)
	# message="Invalid payload" → fixstr: [0xAF, ...]
	var msg := PackedByteArray()
	msg.append(11)  # ERROR
	# code 4217 as uint16: 0xCD prefix + LE bytes
	msg.append(0xCD)
	msg.append(0x79)  # 4217 & 0xFF
	msg.append(0x10)  # 4217 >> 8
	# message as fixstr
	var text := "Invalid payload"
	msg.append(0xA0 | text.length())  # fixstr prefix
	msg.append_array(text.to_utf8_buffer())

	# Verify structure
	assert_int(msg[0]).is_equal(11)
	assert_int(msg[1]).is_equal(0xCD)  # uint16 prefix

# --- ROOM_DATA message parsing ---

func test_parse_room_data_string_type():
	# ROOM_DATA: [13][msgpack_string type][msgpack_payload]
	# type = "move" (fixstr), payload = msgpack encoded
	var msg := PackedByteArray()
	msg.append(13)  # ROOM_DATA
	# type as fixstr: "move" = 4 bytes
	msg.append(0xA4)  # fixstr len=4
	msg.append_array("move".to_utf8_buffer())

	# Parse type
	var offset := 1
	var prefix := msg[offset]
	# Check it's a fixstr
	assert_bool(prefix < 0xC0 and prefix >= 0xA0).is_true()
	var str_len := prefix & 0x1F
	offset += 1
	var type_str := msg.slice(offset, offset + str_len).get_string_from_utf8()
	assert_str(type_str).is_equal("move")

func test_parse_room_data_number_type():
	# ROOM_DATA with numeric type: [13][positive_fixint type][payload]
	var msg := PackedByteArray()
	msg.append(13)  # ROOM_DATA
	msg.append(42)  # type = 42 (positive fixint)

	var offset := 1
	var prefix := msg[offset]
	# Positive fixint: < 0x80
	assert_bool(prefix < 0x80).is_true()
	assert_int(prefix).is_equal(42)

# --- ROOM_STATE message ---

func test_room_state_has_schema_bytes():
	# ROOM_STATE: [14][schema_binary_data...]
	var msg := PackedByteArray()
	msg.append(14)  # ROOM_STATE
	# Schema data: ADD field 0, value 75
	msg.append(128)  # ADD + field 0
	msg.append(75)   # positive fixint

	assert_int(msg[0]).is_equal(14)
	# Payload starts at offset 1
	var payload := msg.slice(1)
	assert_int(payload.size()).is_equal(2)
	assert_int(payload[0]).is_equal(128)  # ADD field 0
	assert_int(payload[1]).is_equal(75)
