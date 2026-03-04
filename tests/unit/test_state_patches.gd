extends GdUnitTestSuite

# Tests for RoomState decoding binary schema data via Schema.decode().

class GameState extends Schema:
	var x: int = 0
	var y: int = 0
	var name: String = ""

	func _init():
		super()
		_define_field(0, "x", "uint8")
		_define_field(1, "y", "uint8")
		_define_field(2, "name", "string")

func test_apply_full_state():
	var room_state := preload("res://addons/colyseus/src/room/RoomState.gd").new()
	var state := GameState.new()
	room_state.set_root(state)

	# ADD x=10, ADD y=20, ADD name="hi"
	var data := PackedByteArray([128, 10, 129, 20, 130])
	data.append(0xA2)
	data.append_array("hi".to_utf8_buffer())

	room_state.apply_full_state(data)

	assert_int(state.x).is_equal(10)
	assert_int(state.y).is_equal(20)
	assert_str(state.name).is_equal("hi")

func test_apply_patch():
	var room_state := preload("res://addons/colyseus/src/room/RoomState.gd").new()
	var state := GameState.new()
	room_state.set_root(state)

	# Initial state
	room_state.apply_full_state(PackedByteArray([128, 10, 129, 20]))
	assert_int(state.x).is_equal(10)

	# Patch: REPLACE x=99
	room_state.apply_patch(PackedByteArray([0, 99]))
	assert_int(state.x).is_equal(99)
	assert_int(state.y).is_equal(20)  # unchanged

func test_field_changed_signal():
	var room_state := preload("res://addons/colyseus/src/room/RoomState.gd").new()
	var state := GameState.new()
	room_state.set_root(state)

	var received_fields := []
	room_state.field_changed.connect(func(field, value): received_fields.append(field))

	room_state.apply_full_state(PackedByteArray([128, 10, 129, 20]))

	assert_int(received_fields.size()).is_equal(2)
	assert_str(received_fields[0]).is_equal("x")
	assert_str(received_fields[1]).is_equal("y")
