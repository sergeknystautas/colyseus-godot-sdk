extends GdUnitTestSuite

const SERVER_URL := "ws://localhost:2570"
const TIMEOUT_MS := 5000

# Minimal schema mirror for reconnect test
class PlayerState extends Schema:
	var sessionId: String = ""
	var name: String = ""
	var x: float = 0.0

	func _init():
		super()
		_define_field(0, "sessionId", "string")
		_define_field(1, "name", "string")
		_define_field(2, "x", "float32")

class TestState extends Schema:
	var scoreU8: int = 0
	var scoreI32: int = 0
	var speed: float = 0.0
	var label: String = ""
	var active: bool = false
	var players = null
	var tags = null

	func _init():
		super()
		_define_field(0, "scoreU8", "uint8")
		_define_field(1, "scoreI32", "int32")
		_define_field(2, "speed", "float32")
		_define_field(3, "label", "string")
		_define_field(4, "active", "boolean")
		_define_field(5, "players", "map:ref:PlayerState")
		_define_field(6, "tags", "array:string")
		register_schema_type("PlayerState", func(): return PlayerState.new(), 0)

func test_server_kick_emits_disconnect():
	var client := preload("res://addons/colyseus/src/client/ColyseusClient.gd").new()
	add_child(client)

	client.connect_to_server(SERVER_URL)
	await assert_signal(client).wait_until(TIMEOUT_MS).is_emitted("connected")

	var room := client.join("error")
	await assert_signal(room).wait_until(TIMEOUT_MS).is_emitted("joined")

	# Ask the server to kick us
	room.send("kick", {})
	await assert_signal(client).wait_until(TIMEOUT_MS).is_emitted("disconnected")

	assert_bool(client.is_server_connected()).is_false()

	remove_child(client)
	client.queue_free()

func test_join_rejected_room():
	var client := preload("res://addons/colyseus/src/client/ColyseusClient.gd").new()
	add_child(client)

	client.connect_to_server(SERVER_URL)
	await assert_signal(client).wait_until(TIMEOUT_MS).is_emitted("connected")

	# Join with reject option — ErrorRoom.onAuth throws if options.reject is truthy
	# Auth rejection happens during WS connection (onAuth), not HTTP matchmaking.
	# The server sends an ERROR protocol message, which our client emits as error(message).
	var errors := []
	client.error.connect(func(code, msg): errors.append(msg))

	var room := client.join("error", {"reject": true})

	await __awaiter.await_millis(3000)

	assert_int(errors.size()).is_greater(0)

	client.close_connection()
	remove_child(client)
	client.queue_free()

func test_reconnect_with_token():
	var client := preload("res://addons/colyseus/src/client/ColyseusClient.gd").new()
	add_child(client)

	client.connect_to_server(SERVER_URL)
	await assert_signal(client).wait_until(TIMEOUT_MS).is_emitted("connected")

	var state := TestState.new()
	var room = client.join("state")
	room.set_state(state)
	await assert_signal(room).wait_until(TIMEOUT_MS).is_emitted("joined")

	# Verify initial state
	assert_int(state.scoreU8).is_equal(10)
	assert_str(state.label).is_equal("hello")

	# Save reconnection token and session ID before disconnecting
	var token: String = room.get_reconnection_token()
	var original_session_id: String = room.get_session_id()
	assert_str(token).is_not_empty()

	# Disconnect without consent (simulates network drop)
	# close_connection emits disconnected but doesn't send LEAVE_ROOM gracefully
	# We need to close the WS without sending leave so the server keeps the seat
	client._socket.close()
	client._socket = null
	client._ws_connected = false
	client._join_acknowledged = false
	client._current_room = null
	await __awaiter.await_millis(500)

	# Reconnect using the saved token
	var state2 := TestState.new()
	var room2 = client.reconnect(token)
	room2.set_state(state2)
	await assert_signal(room2).wait_until(TIMEOUT_MS).is_emitted("joined")

	# Session ID should be preserved
	assert_str(room2.get_session_id()).is_equal(original_session_id)

	# State should be intact after reconnection
	assert_int(state2.scoreU8).is_equal(10)
	assert_str(state2.label).is_equal("hello")

	# Send LEAVE_ROOM so server does a consented leave (won't hold the seat)
	room2.leave()
	await __awaiter.await_millis(500)
	client.close_connection()
	remove_child(client)
	client.queue_free()
