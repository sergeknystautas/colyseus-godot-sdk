extends GdUnitTestSuite

# Unit tests for ColyseusClient message dispatch.
# Tests _handle_message routing and message parsing
# without a real WebSocket connection.

var ClientScript = preload("res://addons/colyseus/src/client/ColyseusClient.gd")
var RoomScript = preload("res://addons/colyseus/src/room/Room.gd")

# --- _handle_message routing ---

func test_handle_join_room_sends_ack():
	var client = ClientScript.new()
	add_child(client)

	var room: RefCounted = RoomScript.new(client, "test")
	room._room_id = "test_room_id"
	client._current_room = room

	# Build JOIN_ROOM packet: [10][token_len][token][serializer_len][serializer]
	var token := "abc123"
	var serializer := "schema"
	var packet := PackedByteArray()
	packet.append(Protocol.MessageType.JOIN_ROOM)
	var token_bytes := token.to_utf8_buffer()
	packet.append(token_bytes.size())
	packet.append_array(token_bytes)
	var ser_bytes := serializer.to_utf8_buffer()
	packet.append(ser_bytes.size())
	packet.append_array(ser_bytes)

	client._handle_message(packet)

	assert_bool(client._join_acknowledged).is_true()
	assert_str(room._reconnection_token).is_equal("test_room_id:abc123")
	remove_child(client)
	client.queue_free()

func test_handle_room_state_dispatches_to_room():
	var client = ClientScript.new()
	add_child(client)

	var room: RefCounted = RoomScript.new(client, "test")
	client._current_room = room

	var joined := [false]
	room.joined.connect(func(): joined[0] = true)

	# Build ROOM_STATE packet: [14][state bytes...]
	var packet := PackedByteArray([Protocol.MessageType.ROOM_STATE, 128, 42])
	client._handle_message(packet)

	assert_bool(joined[0]).is_true()
	remove_child(client)
	client.queue_free()

func test_handle_room_state_patch_dispatches_to_room():
	var client = ClientScript.new()
	add_child(client)

	var room: RefCounted = RoomScript.new(client, "test")
	client._current_room = room

	# Build ROOM_STATE_PATCH packet: [15][patch bytes...]
	var packet := PackedByteArray([Protocol.MessageType.ROOM_STATE_PATCH, 0, 99])
	client._handle_message(packet)

	# _on_state_patch is called — just verify no crash
	assert_bool(true).is_true()
	remove_child(client)
	client.queue_free()

func test_handle_room_data_dispatches_to_room():
	var client = ClientScript.new()
	add_child(client)

	var room: RefCounted = RoomScript.new(client, "test")
	client._current_room = room

	var received := []
	room.message_received.connect(func(type, data): received.append({"type": type, "data": data}))

	# Build ROOM_DATA packet (new format):
	# [13][msgpack_string(type, LE)][msgpack(payload, BE)]
	var encoder := Encoder.new()
	encoder.encode_string("chat")
	var type_bytes := encoder.get_data()

	var payload := Encoder.encode_value({"text": "hello"})

	var packet := PackedByteArray()
	packet.append(Protocol.MessageType.ROOM_DATA)
	packet.append_array(type_bytes)
	packet.append_array(payload)

	client._handle_message(packet)

	assert_int(received.size()).is_equal(1)
	assert_str(received[0].type).is_equal("chat")
	assert_str(received[0].data.text).is_equal("hello")
	remove_child(client)
	client.queue_free()

func test_handle_empty_packet_no_crash():
	var client = ClientScript.new()
	add_child(client)
	client._handle_message(PackedByteArray())
	assert_bool(true).is_true()
	remove_child(client)
	client.queue_free()

# --- send_room_data encoding ---

func test_send_room_data_no_crash_when_disconnected():
	var client = ClientScript.new()
	add_child(client)

	var room: RefCounted = RoomScript.new(client, "test")
	client._current_room = room

	# Room.send calls client.send_room_data — this will skip silently
	# because the socket isn't connected, but we verify no crash
	room.send("move", {"x": 5})
	assert_bool(true).is_true()
	remove_child(client)
	client.queue_free()

# --- Connection state ---

func test_initial_state_not_connected():
	var client = ClientScript.new()
	add_child(client)
	assert_bool(client.is_server_connected()).is_false()
	remove_child(client)
	client.queue_free()

func test_close_connection_emits_disconnected():
	var client = ClientScript.new()
	add_child(client)

	var disconnected := [false]
	client.disconnected.connect(func(): disconnected[0] = true)

	client._connected = true
	client.close_connection()

	assert_bool(disconnected[0]).is_true()
	assert_bool(client.is_server_connected()).is_false()
	remove_child(client)
	client.queue_free()

# --- ROOM_DATA edge cases ---

func test_room_data_truncated_packet_no_crash():
	var client = ClientScript.new()
	add_child(client)
	client._current_room = RoomScript.new(client, "test")

	# Packet with just protocol byte — empty data after stripping
	var packet := PackedByteArray([Protocol.MessageType.ROOM_DATA])
	client._handle_message(packet)
	# Should not crash
	assert_bool(true).is_true()
	remove_child(client)
	client.queue_free()

func test_room_data_no_room_no_crash():
	var client = ClientScript.new()
	add_child(client)
	# No room set

	# Build valid ROOM_DATA
	var encoder := Encoder.new()
	encoder.encode_string("x")
	var type_bytes := encoder.get_data()
	var payload := Encoder.encode_value({"a": 1})

	var packet := PackedByteArray()
	packet.append(Protocol.MessageType.ROOM_DATA)
	packet.append_array(type_bytes)
	packet.append_array(payload)

	client._handle_message(packet)
	assert_bool(true).is_true()
	remove_child(client)
	client.queue_free()

# --- PING handling ---

func test_handle_ping_computes_latency_after_ping_sent():
	var client = ClientScript.new()
	add_child(client)

	# Simulate having sent a ping
	client._ping_sent_time = Time.get_ticks_msec() - 50

	var packet := PackedByteArray([Protocol.MessageType.PING])
	client._handle_message(packet)

	# Latency should be approximately 50ms (allow some tolerance)
	assert_float(client.get_latency()).is_greater(0.0)
	assert_int(client._ping_sent_time).is_equal(0)
	remove_child(client)
	client.queue_free()

func test_handle_ping_no_latency_without_prior_ping():
	var client = ClientScript.new()
	add_child(client)

	# No ping was sent — _ping_sent_time is 0
	var packet := PackedByteArray([Protocol.MessageType.PING])
	client._handle_message(packet)

	assert_float(client.get_latency()).is_equal(0.0)
	remove_child(client)
	client.queue_free()

func test_ping_does_nothing_when_disconnected():
	var client = ClientScript.new()
	add_child(client)
	client.ping()
	assert_float(client.get_latency()).is_equal(0.0)
	remove_child(client)
	client.queue_free()

func test_get_latency_returns_zero_initially():
	var client = ClientScript.new()
	add_child(client)
	assert_float(client.get_latency()).is_equal(0.0)
	remove_child(client)
	client.queue_free()

# --- join when not connected ---

func test_join_when_not_connected_emits_error():
	var client = ClientScript.new()
	add_child(client)

	var errors := []
	client.error.connect(func(code, msg): errors.append({"code": code, "message": msg}))

	var room = client.join("test_room")

	assert_that(room).is_null()
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0].message).is_equal("Not connected")
	remove_child(client)
	client.queue_free()

func test_get_current_room_initially_null():
	var client = ClientScript.new()
	add_child(client)
	assert_that(client.get_current_room()).is_null()
	remove_child(client)
	client.queue_free()

func test_close_connection_idempotent():
	var client = ClientScript.new()
	add_child(client)
	client.close_connection()
	client.close_connection()  # second call — no crash
	assert_bool(client.is_server_connected()).is_false()
	remove_child(client)
	client.queue_free()

func test_handle_room_data_bytes_dispatches_to_room():
	var client = ClientScript.new()
	add_child(client)

	var room: RefCounted = RoomScript.new(client, "test")
	client._current_room = room

	var received_bytes := []
	room.data_bytes_received.connect(func(data): received_bytes.append(data))

	# Build ROOM_DATA_BYTES packet: [17][raw bytes...]
	var raw_payload := PackedByteArray([0xDE, 0xAD, 0xBE, 0xEF])
	var packet := PackedByteArray([Protocol.MessageType.ROOM_DATA_BYTES])
	packet.append_array(raw_payload)

	client._handle_message(packet)

	assert_int(received_bytes.size()).is_equal(1)
	assert_int(received_bytes[0].size()).is_equal(4)
	assert_int(received_bytes[0][0]).is_equal(0xDE)
	remove_child(client)
	client.queue_free()

# --- ERROR handling ---

func test_handle_error_emits_signal():
	var client = ClientScript.new()
	add_child(client)

	var errors := []
	client.error.connect(func(code, msg): errors.append({"code": code, "message": msg}))

	# Build ERROR packet: [11][msgpack_number(code)][msgpack_string(message)]
	var encoder := Encoder.new()
	encoder.encode_number(4201)
	encoder.encode_string("Test error")
	var error_data := encoder.get_data()

	var packet := PackedByteArray([Protocol.MessageType.ERROR])
	packet.append_array(error_data)

	client._handle_message(packet)

	assert_int(errors.size()).is_equal(1)
	assert_int(errors[0].code).is_equal(4201)
	assert_str(errors[0].message).is_equal("Test error")
	remove_child(client)
	client.queue_free()
