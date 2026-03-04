extends GdUnitTestSuite

# Unit tests for Room.gd — signal emissions, state callbacks, session management.
# Uses a mock client node to avoid real WebSocket connections.

var RoomScript = preload("res://addons/colyseus/src/room/Room.gd")

class MockClient extends Node:
	var last_type: String = ""
	var last_data = null
	var leave_called := false

	func send_room_data(type: String, data = null) -> void:
		last_type = type
		last_data = data

	func send_leave_room() -> void:
		leave_called = true

class SimpleState extends Schema:
	var x: int = 0
	var y: int = 0

	func _init():
		super()
		_define_field(0, "x", "uint8")
		_define_field(1, "y", "uint8")

func test_room_id_default_empty():
	var client := MockClient.new()
	var room: RefCounted = RoomScript.new(client, "test_room")
	assert_str(room.get_id()).is_equal("")
	client.free()

func test_room_session_id_default_empty():
	var client := MockClient.new()
	var room: RefCounted = RoomScript.new(client, "test_room")
	assert_str(room.get_session_id()).is_equal("")
	client.free()

func test_set_session_id():
	var client := MockClient.new()
	var room: RefCounted = RoomScript.new(client, "test_room")
	room.set_session_id("abc123")
	assert_str(room.get_session_id()).is_equal("abc123")
	client.free()

func test_set_reconnection_token():
	var client := MockClient.new()
	var room: RefCounted = RoomScript.new(client, "test_room")
	room.set_reconnection_token("room1:token123")
	assert_str(room._reconnection_token).is_equal("room1:token123")
	client.free()

func test_on_room_state_emits_joined():
	var client := MockClient.new()
	var room: RefCounted = RoomScript.new(client, "test_room")

	var joined_count := [0]
	room.joined.connect(func(): joined_count[0] += 1)

	room._on_room_state(PackedByteArray([128, 10]))

	assert_int(joined_count[0]).is_equal(1)
	client.free()

func test_on_message_emits_signal():
	var client := MockClient.new()
	var room: RefCounted = RoomScript.new(client, "test_room")

	var received := []
	room.message_received.connect(func(type, data): received.append({"type": type, "data": data}))

	room._on_message("chat", {"text": "hello"})

	assert_int(received.size()).is_equal(1)
	assert_str(received[0].type).is_equal("chat")
	assert_str(received[0].data.text).is_equal("hello")
	client.free()

func test_on_message_with_null_data():
	var client := MockClient.new()
	var room: RefCounted = RoomScript.new(client, "test_room")

	var received := []
	room.message_received.connect(func(type, data): received.append({"type": type, "data": data}))

	room._on_message("ping")

	assert_int(received.size()).is_equal(1)
	assert_str(received[0].type).is_equal("ping")
	assert_that(received[0].data).is_null()
	client.free()

func test_send_delegates_to_client():
	var client := MockClient.new()
	var room: RefCounted = RoomScript.new(client, "test_room")

	room.send("move", {"x": 10, "y": 20})

	assert_str(client.last_type).is_equal("move")
	assert_int(client.last_data.x).is_equal(10)
	assert_int(client.last_data.y).is_equal(20)
	client.free()

func test_send_without_data():
	var client := MockClient.new()
	var room: RefCounted = RoomScript.new(client, "test_room")

	room.send("ping")

	assert_str(client.last_type).is_equal("ping")
	assert_that(client.last_data).is_null()
	client.free()

# --- State decode through Room ---

func test_on_room_state_decodes_schema():
	var client := MockClient.new()
	var room: RefCounted = RoomScript.new(client, "test_room")
	var state := SimpleState.new()
	room.set_state(state)

	# ADD x=10, ADD y=20
	room._on_room_state(PackedByteArray([128, 10, 129, 20]))

	assert_int(state.x).is_equal(10)
	assert_int(state.y).is_equal(20)
	client.free()

func test_on_room_state_emits_state_changed():
	var client := MockClient.new()
	var room: RefCounted = RoomScript.new(client, "test_room")
	var state := SimpleState.new()
	room.set_state(state)

	var changes_received := []
	room.state_changed.connect(func(changes): changes_received.append(changes))

	room._on_room_state(PackedByteArray([128, 10]))

	assert_int(changes_received.size()).is_equal(1)
	assert_int(changes_received[0].size()).is_equal(1)
	client.free()

func test_on_state_patch_applies_to_schema():
	var client := MockClient.new()
	var room: RefCounted = RoomScript.new(client, "test_room")
	var state := SimpleState.new()
	room.set_state(state)

	# Initial state
	room._on_room_state(PackedByteArray([128, 10, 129, 20]))
	assert_int(state.x).is_equal(10)

	# Patch: REPLACE x=99
	room._on_state_patch(PackedByteArray([0, 99]))
	assert_int(state.x).is_equal(99)
	assert_int(state.y).is_equal(20)  # unchanged
	client.free()

func test_on_state_patch_emits_state_changed():
	var client := MockClient.new()
	var room: RefCounted = RoomScript.new(client, "test_room")
	var state := SimpleState.new()
	room.set_state(state)

	room._on_room_state(PackedByteArray([128, 10]))

	var changes_received := []
	room.state_changed.connect(func(changes): changes_received.append(changes))

	room._on_state_patch(PackedByteArray([0, 99]))

	assert_int(changes_received.size()).is_equal(1)
	client.free()

func test_get_state_returns_schema():
	var client := MockClient.new()
	var room: RefCounted = RoomScript.new(client, "test_room")
	var state := SimpleState.new()
	room.set_state(state)
	assert_that(room.get_state()).is_same(state)
	client.free()

# --- leave() ---

func test_leave_emits_left_signal():
	var client := MockClient.new()
	var room: RefCounted = RoomScript.new(client, "test_room")

	var left_count := [0]
	room.left.connect(func(_code, _reason): left_count[0] += 1)

	room.leave()

	assert_int(left_count[0]).is_equal(1)
	client.free()

func test_leave_calls_client():
	var client := MockClient.new()
	var room: RefCounted = RoomScript.new(client, "test_room")

	room.leave()

	assert_bool(client.leave_called).is_true()
	client.free()

# --- Edge cases ---

func test_on_room_state_without_schema_no_crash():
	var client := MockClient.new()
	var room: RefCounted = RoomScript.new(client, "test_room")
	# No state set — should still emit joined without crashing
	var joined := [false]
	room.joined.connect(func(): joined[0] = true)
	room._on_room_state(PackedByteArray([128, 10]))
	assert_bool(joined[0]).is_true()
	client.free()

func test_on_state_patch_without_schema_no_crash():
	var client := MockClient.new()
	var room: RefCounted = RoomScript.new(client, "test_room")
	# No state set — should not crash
	room._on_state_patch(PackedByteArray([0, 99]))
	assert_bool(true).is_true()
	client.free()

func test_on_state_patch_no_changes_no_signal():
	var client := MockClient.new()
	var room: RefCounted = RoomScript.new(client, "test_room")
	var state := SimpleState.new()
	room.set_state(state)
	room._on_room_state(PackedByteArray([128, 10]))

	var changes_count := [0]
	room.state_changed.connect(func(_c): changes_count[0] += 1)

	# Empty patch — no bytes to decode beyond what's already set
	room._on_state_patch(PackedByteArray())
	assert_int(changes_count[0]).is_equal(0)
	client.free()

func test_data_bytes_received_signal():
	var client := MockClient.new()
	var room: RefCounted = RoomScript.new(client, "test_room")

	var received := []
	room.data_bytes_received.connect(func(data): received.append(data))

	room._on_data_bytes(PackedByteArray([0xDE, 0xAD]))

	assert_int(received.size()).is_equal(1)
	assert_int(received[0][0]).is_equal(0xDE)
	assert_int(received[0][1]).is_equal(0xAD)
	client.free()
