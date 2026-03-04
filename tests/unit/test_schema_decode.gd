extends GdUnitTestSuite

# Tests for Schema.decode() — decoding @colyseus/schema binary state.
#
# The binary format for schema fields:
#   byte = operation | field_index
#   operation = (byte >> 6) << 6
#   field_index = byte % (operation || 255)
#
# Primitive types are decoded as RAW bytes (not msgpack):
#   uint8:   1 byte
#   int8:    1 byte (signed)
#   uint16:  2 bytes LE
#   int16:   2 bytes LE
#   uint32:  4 bytes LE
#   int32:   4 bytes LE
#   float32: 4 bytes LE
#   float64: 8 bytes LE
#   boolean: 1 byte (0 or 1)
#
# "string" and "number" use msgpack encoding (self-describing prefix).

# --- Test schema definition ---

class SimpleState extends Schema:
	var x: int = 0
	var y: int = 0
	var name: String = ""

	func _init():
		super()
		_define_field(0, "x", "uint8")
		_define_field(1, "y", "uint8")
		_define_field(2, "name", "string")

class TypedState extends Schema:
	var health: int = 0
	var score: int = 0
	var speed: float = 0.0
	var alive: bool = false
	var label: String = ""

	func _init():
		super()
		_define_field(0, "health", "int16")
		_define_field(1, "score", "uint32")
		_define_field(2, "speed", "float32")
		_define_field(3, "alive", "boolean")
		_define_field(4, "label", "string")

class NumberState extends Schema:
	var value = 0

	func _init():
		super()
		_define_field(0, "value", "number")

# --- ADD operations ---

func test_decode_add_uint8():
	# ADD field 0 (uint8 = 42): [128, 42]
	var data := PackedByteArray([128, 42])
	var state := SimpleState.new()
	state.decode(data)
	assert_int(state.x).is_equal(42)

func test_decode_add_two_uint8_fields():
	# ADD field 0 (x=10), ADD field 1 (y=20)
	var data := PackedByteArray([128, 10, 129, 20])
	var state := SimpleState.new()
	state.decode(data)
	assert_int(state.x).is_equal(10)
	assert_int(state.y).is_equal(20)

func test_decode_add_string():
	# ADD field 2 (name="hello"): [130, 0xA5, h, e, l, l, o]
	var data := PackedByteArray([130])
	data.append(0xA5)  # fixstr len=5
	data.append_array("hello".to_utf8_buffer())
	var state := SimpleState.new()
	state.decode(data)
	assert_str(state.name).is_equal("hello")

func test_decode_add_all_fields():
	# ADD x=10, ADD y=20, ADD name="hi"
	var data := PackedByteArray([128, 10, 129, 20, 130])
	data.append(0xA2)  # fixstr len=2
	data.append_array("hi".to_utf8_buffer())
	var state := SimpleState.new()
	state.decode(data)
	assert_int(state.x).is_equal(10)
	assert_int(state.y).is_equal(20)
	assert_str(state.name).is_equal("hi")

# --- REPLACE operations ---

func test_decode_replace_uint8():
	# First ADD field 0 = 10, then REPLACE field 0 = 99
	var state := SimpleState.new()
	state.decode(PackedByteArray([128, 10]))  # ADD x=10
	assert_int(state.x).is_equal(10)
	state.decode(PackedByteArray([0, 99]))    # REPLACE x=99
	assert_int(state.x).is_equal(99)

func test_decode_replace_string():
	var state := SimpleState.new()
	# ADD name="hi"
	var add_data := PackedByteArray([130])
	add_data.append(0xA2)
	add_data.append_array("hi".to_utf8_buffer())
	state.decode(add_data)
	assert_str(state.name).is_equal("hi")

	# REPLACE name="bye"
	var replace_data := PackedByteArray([2])  # REPLACE field 2
	replace_data.append(0xA3)  # fixstr len=3
	replace_data.append_array("bye".to_utf8_buffer())
	state.decode(replace_data)
	assert_str(state.name).is_equal("bye")

# --- DELETE operations ---

func test_decode_delete_field():
	var state := SimpleState.new()
	state.decode(PackedByteArray([128, 42]))  # ADD x=42
	assert_int(state.x).is_equal(42)
	state.decode(PackedByteArray([64]))       # DELETE field 0
	# After delete, field should be reset to default
	assert_int(state.x).is_equal(0)

# --- Typed fields ---

func test_decode_int16():
	# ADD field 0 (health): int16 = 300 → LE bytes [0x2C, 0x01]
	var data := PackedByteArray([128, 0x2C, 0x01])
	var state := TypedState.new()
	state.decode(data)
	assert_int(state.health).is_equal(300)

func test_decode_int16_negative():
	# int16 = -100 → LE bytes: 0xFF9C → [0x9C, 0xFF]
	var data := PackedByteArray([128, 0x9C, 0xFF])
	var state := TypedState.new()
	state.decode(data)
	assert_int(state.health).is_equal(-100)

func test_decode_uint32():
	# ADD field 1 (score): uint32 = 100000
	# 100000 = 0x000186A0 → LE [0xA0, 0x86, 0x01, 0x00]
	var data := PackedByteArray([129, 0xA0, 0x86, 0x01, 0x00])
	var state := TypedState.new()
	state.decode(data)
	assert_int(state.score).is_equal(100000)

func test_decode_float32():
	# ADD field 2 (speed): float32 = 1.0
	# 1.0 as float32 LE: [0x00, 0x00, 0x80, 0x3F]
	var data := PackedByteArray([130, 0x00, 0x00, 0x80, 0x3F])
	var state := TypedState.new()
	state.decode(data)
	assert_float(state.speed).is_equal_approx(1.0, 0.0001)

func test_decode_boolean_true():
	# ADD field 3 (alive): boolean = true (1)
	var data := PackedByteArray([131, 1])
	var state := TypedState.new()
	state.decode(data)
	assert_bool(state.alive).is_true()

func test_decode_boolean_false():
	var data := PackedByteArray([131, 0])
	var state := TypedState.new()
	state.decode(data)
	assert_bool(state.alive).is_false()

func test_decode_string_field():
	# ADD field 4 (label): string = "test"
	var data := PackedByteArray([132])
	data.append(0xA4)  # fixstr len=4
	data.append_array("test".to_utf8_buffer())
	var state := TypedState.new()
	state.decode(data)
	assert_str(state.label).is_equal("test")

# --- number type (msgpack-encoded) ---

func test_decode_number_positive_fixint():
	# ADD field 0 (value): number = 42
	# Msgpack: positive fixint = just 42
	var data := PackedByteArray([128, 42])
	var state := NumberState.new()
	state.decode(data)
	assert_int(state.value).is_equal(42)

func test_decode_number_uint16():
	# ADD field 0 (value): number = 300
	# Msgpack: uint16 prefix [0xCD, 0x2C, 0x01]
	var data := PackedByteArray([128, 0xCD, 0x2C, 0x01])
	var state := NumberState.new()
	state.decode(data)
	assert_int(state.value).is_equal(300)

func test_decode_number_negative():
	# ADD field 0 (value): number = -1
	# Msgpack: negative fixint 0xFF
	var data := PackedByteArray([128, 0xFF])
	var state := NumberState.new()
	state.decode(data)
	assert_int(state.value).is_equal(-1)

# --- Multi-type full state ---

func test_decode_full_typed_state():
	# ADD health=100, ADD score=50000, ADD speed=2.5, ADD alive=true, ADD label="hero"
	var data := PackedByteArray()

	# health (int16 = 100): [128, 0x64, 0x00]
	data.append(128)
	data.append(0x64)  # 100 low byte
	data.append(0x00)  # 100 high byte

	# score (uint32 = 50000): [129, 0x50, 0xC3, 0x00, 0x00]
	data.append(129)
	data.append(0x50)  # 50000 & 0xFF
	data.append(0xC3)  # (50000 >> 8) & 0xFF
	data.append(0x00)
	data.append(0x00)

	# speed (float32 = 2.5): [130, LE bytes of 2.5]
	data.append(130)
	# 2.5 as float32 = 0x40200000 → LE: [0x00, 0x00, 0x20, 0x40]
	data.append(0x00)
	data.append(0x00)
	data.append(0x20)
	data.append(0x40)

	# alive (boolean = true): [131, 1]
	data.append(131)
	data.append(1)

	# label (string = "hero"): [132, 0xA4, h, e, r, o]
	data.append(132)
	data.append(0xA4)
	data.append_array("hero".to_utf8_buffer())

	var state := TypedState.new()
	state.decode(data)

	assert_int(state.health).is_equal(100)
	assert_int(state.score).is_equal(50000)
	assert_float(state.speed).is_equal_approx(2.5, 0.0001)
	assert_bool(state.alive).is_true()
	assert_str(state.label).is_equal("hero")

# --- Changes tracking ---

func test_decode_returns_changes():
	var data := PackedByteArray([128, 10, 129, 20])
	var state := SimpleState.new()
	var changes = state.decode(data)
	assert_int(changes.size()).is_equal(2)

# --- Empty state ---

func test_decode_empty_bytes():
	var state := SimpleState.new()
	var changes = state.decode(PackedByteArray())
	assert_int(changes.size()).is_equal(0)
	assert_int(state.x).is_equal(0)
	assert_int(state.y).is_equal(0)

# --- Offset tracking ---

func test_decode_tracks_offset():
	var it := {"offset": 0}
	var data := PackedByteArray([128, 10, 129, 20])
	var state := SimpleState.new()
	state.decode(data, it)
	assert_int(it.offset).is_equal(4)

func test_decode_with_initial_offset():
	# Skip first 2 bytes, decode from offset 2
	var data := PackedByteArray([0xFF, 0xFF, 128, 42])
	var it := {"offset": 2}
	var state := SimpleState.new()
	state.decode(data, it)
	assert_int(state.x).is_equal(42)

# --- Unknown field index ---

func test_decode_unknown_field_ignored():
	# Field index 5 doesn't exist on SimpleState (only 0,1,2)
	# operation ADD (128) | field_index 5 = 133
	# Followed by a byte that would be the "value"
	var data := PackedByteArray([133, 99])
	var state := SimpleState.new()
	var changes = state.decode(data)
	# Unknown field should be skipped (though value parsing is undefined)
	assert_int(state.x).is_equal(0)

# --- Changes array content ---

func test_changes_contain_op_and_field():
	var data := PackedByteArray([128, 10])
	var state := SimpleState.new()
	var changes = state.decode(data)
	assert_int(changes.size()).is_equal(1)
	assert_str(changes[0].op).is_equal("add")
	assert_str(changes[0].field).is_equal("x")
	assert_int(changes[0].value).is_equal(10)

func test_replace_changes_include_previous():
	var state := SimpleState.new()
	state.decode(PackedByteArray([128, 10]))
	var changes = state.decode(PackedByteArray([0, 20]))
	assert_str(changes[0].op).is_equal("replace")
	assert_int(changes[0].value).is_equal(20)
	assert_int(changes[0].previous).is_equal(10)

func test_delete_changes_include_previous():
	var state := SimpleState.new()
	state.decode(PackedByteArray([128, 10]))
	# DELETE field 0: operation 64 | field_index 0 = 64
	var changes = state.decode(PackedByteArray([64]))
	assert_str(changes[0].op).is_equal("delete")
	assert_int(changes[0].previous).is_equal(10)
	assert_int(state.x).is_equal(0)  # reset to default
