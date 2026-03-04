extends GdUnitTestSuite

const SERVER_URL := "ws://localhost:2570"
const TIMEOUT_MS := 5000

# GDScript mirror of server's PlayerSchema
class PlayerState extends Schema:
	var sessionId: String = ""
	var name: String = ""
	var x: float = 0.0

	func _init():
		super()
		_define_field(0, "sessionId", "string")
		_define_field(1, "name", "string")
		_define_field(2, "x", "float32")

# GDScript mirror of server's StateRoomSchema
class TestState extends Schema:
	var scoreU8: int = 0
	var scoreI32: int = 0
	var speed: float = 0.0
	var label: String = ""
	var active: bool = false
	var players = null  # MapSchema<PlayerState>
	var tags = null     # ArraySchema<string>

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

func _create_connected_client() -> Node:
	var client := preload("res://addons/colyseus/src/client/ColyseusClient.gd").new()
	add_child(client)
	client.connect_to_server(SERVER_URL)
	await assert_signal(client).wait_until(TIMEOUT_MS).is_emitted("connected")
	return client

func test_decode_initial_state_primitives():
	var client := await _create_connected_client()
	var state := TestState.new()

	var room = client.join("state")
	room.set_state(state)
	await assert_signal(room).wait_until(TIMEOUT_MS).is_emitted("joined")

	assert_int(state.scoreU8).is_equal(10)
	assert_int(state.scoreI32).is_equal(-42)
	assert_float(state.speed).is_equal_approx(3.14, 0.01)
	assert_str(state.label).is_equal("hello")
	assert_bool(state.active).is_true()

	client.close_connection()
	remove_child(client)
	client.queue_free()

func test_decode_initial_state_array():
	var client := await _create_connected_client()
	var state := TestState.new()

	var room = client.join("state")
	room.set_state(state)
	await assert_signal(room).wait_until(TIMEOUT_MS).is_emitted("joined")

	assert_that(state.tags).is_not_null()
	assert_int(state.tags.size()).is_equal(2)
	assert_str(state.tags.get_item(0)).is_equal("alpha")
	assert_str(state.tags.get_item(1)).is_equal("beta")

	client.close_connection()
	remove_child(client)
	client.queue_free()

func test_decode_initial_state_map():
	var client := await _create_connected_client()
	var state := TestState.new()

	var room = client.join("state")
	room.set_state(state)
	await assert_signal(room).wait_until(TIMEOUT_MS).is_emitted("joined")

	assert_that(state.players).is_not_null()
	assert_int(state.players.size()).is_equal(1)

	# The server adds a player with the client's sessionId on join
	var session_id: String = room.get_session_id()
	assert_bool(state.players.has(session_id)).is_true()

	var player = state.players.get_item(session_id)
	assert_str(player.sessionId).is_equal(session_id)
	assert_float(player.x).is_equal(100.0)

	client.close_connection()
	remove_child(client)
	client.queue_free()

func test_state_patch_updates_values():
	var client := await _create_connected_client()
	var state := TestState.new()

	var room = client.join("state")
	room.set_state(state)
	await assert_signal(room).wait_until(TIMEOUT_MS).is_emitted("joined")

	assert_int(state.scoreU8).is_equal(10)

	# Connect to state_changed before sending mutate
	var changes_received := []
	room.state_changed.connect(func(changes): changes_received.append(changes))

	room.send("mutate", {"scoreU8": 99})
	await __awaiter.await_millis(2000)

	assert_int(state.scoreU8).is_equal(99)

	client.close_connection()
	remove_child(client)
	client.queue_free()

func test_two_clients_see_each_other():
	var client_a := await _create_connected_client()
	var state_a := TestState.new()
	var room_a = client_a.join("state")
	room_a.set_state(state_a)
	await assert_signal(room_a).wait_until(TIMEOUT_MS).is_emitted("joined")

	var client_b := await _create_connected_client()
	var state_b := TestState.new()
	var room_b = client_b.join("state")
	room_b.set_state(state_b)
	await assert_signal(room_b).wait_until(TIMEOUT_MS).is_emitted("joined")

	# Wait for client_a to receive the state patch with client_b's player
	await __awaiter.await_millis(2000)

	assert_int(state_a.players.size()).is_equal(2)

	client_a.close_connection()
	client_b.close_connection()
	remove_child(client_a)
	remove_child(client_b)
	client_a.queue_free()
	client_b.queue_free()
