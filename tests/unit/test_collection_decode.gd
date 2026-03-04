extends GdUnitTestSuite

# Tests for decoding ArraySchema and MapSchema from @colyseus/schema binary.
#
# Collection encoding differs from Schema fields:
#   Schema fields: single compressed byte = operation | field_index
#   Collection items: operation = full byte, field_index = separate msgpack number
#
# SWITCH_TO_STRUCTURE (255) switches decode context to a nested ref.
# Each collection/schema gets a unique refId.
#
# ArraySchema ADD: [operation=128][msgpack fieldIndex][value_bytes]
# MapSchema ADD:   [operation=128][msgpack fieldIndex][msgpack key_string][value_bytes]

# --- Test schemas ---

class ArrayState extends Schema:
	var items = null

	func _init():
		super()
		_define_field(0, "items", "array:uint8")

class MapState extends Schema:
	var scores = null

	func _init():
		super()
		_define_field(0, "scores", "map:uint8")

class StringArrayState extends Schema:
	var names = null

	func _init():
		super()
		_define_field(0, "names", "array:string")

class MixedState extends Schema:
	var health: int = 0
	var items = null

	func _init():
		super()
		_define_field(0, "health", "uint8")
		_define_field(1, "items", "array:uint8")

# --- ArraySchema decode ---

func test_array_field_created():
	# ADD field 0 (array): [128, refId=1]
	# SWITCH_TO_STRUCTURE: [255, refId=1]
	# ADD item 0: [128, 0, 42]
	var data := PackedByteArray([
		128, 1,          # ADD field 0, refId=1
		255, 1,          # SWITCH_TO_STRUCTURE, refId=1
		128, 0, 42       # ADD index 0, value 42
	])
	var state := ArrayState.new()
	state.decode(data)
	assert_that(state.items).is_not_null()
	assert_int(state.items.size()).is_equal(1)
	assert_int(state.items.get_item(0)).is_equal(42)

func test_array_multiple_items():
	var data := PackedByteArray([
		128, 1,          # ADD field 0 (array), refId=1
		255, 1,          # SWITCH_TO_STRUCTURE
		128, 0, 10,      # ADD index 0, value 10
		128, 1, 20,      # ADD index 1, value 20
		128, 2, 30       # ADD index 2, value 30
	])
	var state := ArrayState.new()
	state.decode(data)
	assert_int(state.items.size()).is_equal(3)
	assert_int(state.items.get_item(0)).is_equal(10)
	assert_int(state.items.get_item(1)).is_equal(20)
	assert_int(state.items.get_item(2)).is_equal(30)

func test_array_replace_item():
	var data := PackedByteArray([
		128, 1,          # ADD array, refId=1
		255, 1,          # SWITCH_TO_STRUCTURE
		128, 0, 10,      # ADD index 0, value 10
		128, 1, 20       # ADD index 1, value 20
	])
	var state := ArrayState.new()
	state.decode(data)

	# Patch: REPLACE index 0 with 99
	var patch := PackedByteArray([
		255, 1,          # SWITCH_TO_STRUCTURE, refId=1
		0, 0, 99         # REPLACE index 0, value 99
	])
	state.decode(patch)
	assert_int(state.items.get_item(0)).is_equal(99)
	assert_int(state.items.get_item(1)).is_equal(20)

func test_array_delete_item():
	var data := PackedByteArray([
		128, 1,
		255, 1,
		128, 0, 10,
		128, 1, 20
	])
	var state := ArrayState.new()
	state.decode(data)
	assert_int(state.items.size()).is_equal(2)

	# DELETE index 0
	var patch := PackedByteArray([
		255, 1,
		64, 0            # DELETE index 0
	])
	state.decode(patch)
	assert_int(state.items.size()).is_equal(1)

func test_array_of_strings():
	var data := PackedByteArray([128, 1, 255, 1])
	# ADD index 0, value "hello"
	data.append(128)  # ADD
	data.append(0)    # fieldIndex=0
	data.append(0xA5) # fixstr len=5
	data.append_array("hello".to_utf8_buffer())
	# ADD index 1, value "world"
	data.append(128)
	data.append(1)
	data.append(0xA5)
	data.append_array("world".to_utf8_buffer())

	var state := StringArrayState.new()
	state.decode(data)
	assert_int(state.names.size()).is_equal(2)
	assert_str(state.names.get_item(0)).is_equal("hello")
	assert_str(state.names.get_item(1)).is_equal("world")

# --- MapSchema decode ---

func test_map_field_created():
	var data := PackedByteArray([128, 1, 255, 1])
	# ADD index 0, key="alice", value=100
	data.append(128)  # ADD
	data.append(0)    # fieldIndex=0
	data.append(0xA5) # fixstr key "alice"
	data.append_array("alice".to_utf8_buffer())
	data.append(100)  # uint8 value

	var state := MapState.new()
	state.decode(data)
	assert_that(state.scores).is_not_null()
	assert_int(state.scores.size()).is_equal(1)
	assert_int(state.scores.get_item("alice")).is_equal(100)

func test_map_multiple_entries():
	var data := PackedByteArray([128, 1, 255, 1])
	# ADD "alice"=100
	data.append(128)
	data.append(0)
	data.append(0xA5)
	data.append_array("alice".to_utf8_buffer())
	data.append(100)
	# ADD "bob"=200
	data.append(128)
	data.append(1)
	data.append(0xA3)  # fixstr "bob"
	data.append_array("bob".to_utf8_buffer())
	data.append(200)

	var state := MapState.new()
	state.decode(data)
	assert_int(state.scores.size()).is_equal(2)
	assert_int(state.scores.get_item("alice")).is_equal(100)
	assert_int(state.scores.get_item("bob")).is_equal(200)

func test_map_delete_entry():
	var data := PackedByteArray([128, 1, 255, 1])
	data.append(128)
	data.append(0)
	data.append(0xA5)
	data.append_array("alice".to_utf8_buffer())
	data.append(100)

	var state := MapState.new()
	state.decode(data)
	assert_int(state.scores.size()).is_equal(1)

	# DELETE index 0 (which maps to "alice")
	var patch := PackedByteArray([255, 1, 64, 0])
	state.decode(patch)
	assert_int(state.scores.size()).is_equal(0)

# --- Mixed schema + collection ---

func test_mixed_schema_and_array():
	var data := PackedByteArray([
		128, 50,         # ADD health=50
		129, 1,          # ADD items array, refId=1
		255, 1,          # SWITCH_TO_STRUCTURE
		128, 0, 10,      # ADD index 0 = 10
		128, 1, 20       # ADD index 1 = 20
	])
	var state := MixedState.new()
	state.decode(data)
	assert_int(state.health).is_equal(50)
	assert_int(state.items.size()).is_equal(2)
	assert_int(state.items.get_item(0)).is_equal(10)
	assert_int(state.items.get_item(1)).is_equal(20)

# --- SWITCH back to root ---

func test_switch_back_to_root():
	# After decoding collection items, SWITCH back to root for more fields
	var data := PackedByteArray([
		129, 1,          # ADD items array, refId=1
		255, 1,          # SWITCH_TO_STRUCTURE to array
		128, 0, 42,      # ADD index 0 = 42
		255, 0,          # SWITCH_TO_STRUCTURE back to root (refId=0)
		128, 99          # ADD health=99
	])
	var state := MixedState.new()
	state.decode(data)
	assert_int(state.items.size()).is_equal(1)
	assert_int(state.items.get_item(0)).is_equal(42)
	assert_int(state.health).is_equal(99)

# --- SetSchema decode ---

class SetState extends Schema:
	var tags = null

	func _init():
		super()
		_define_field(0, "tags", "set:uint8")

func test_set_field_created():
	var data := PackedByteArray([
		128, 1,          # ADD set field, refId=1
		255, 1,          # SWITCH_TO_STRUCTURE
		128, 0, 10,      # ADD index 0, value 10
		128, 1, 20       # ADD index 1, value 20
	])
	var state := SetState.new()
	state.decode(data)
	assert_that(state.tags).is_not_null()
	assert_int(state.tags.size()).is_equal(2)
	assert_bool(state.tags.has(10)).is_true()
	assert_bool(state.tags.has(20)).is_true()

func test_set_delete_item():
	var data := PackedByteArray([
		128, 1, 255, 1,
		128, 0, 10,
		128, 1, 20
	])
	var state := SetState.new()
	state.decode(data)
	assert_int(state.tags.size()).is_equal(2)

	# DELETE index 0
	var patch := PackedByteArray([255, 1, 64, 0])
	state.decode(patch)
	assert_int(state.tags.size()).is_equal(1)
	assert_bool(state.tags.has(20)).is_true()

func test_set_clear():
	var data := PackedByteArray([
		128, 1, 255, 1,
		128, 0, 10,
		128, 1, 20
	])
	var state := SetState.new()
	state.decode(data)
	assert_int(state.tags.size()).is_equal(2)

	# CLEAR
	var patch := PackedByteArray([255, 1, 10])  # OP_CLEAR = 10
	state.decode(patch)
	assert_int(state.tags.size()).is_equal(0)

# --- CollectionSchema decode ---

class CollectionState extends Schema:
	var items = null

	func _init():
		super()
		_define_field(0, "items", "collection:uint8")

func test_collection_field_created():
	var data := PackedByteArray([
		128, 1,          # ADD collection field, refId=1
		255, 1,          # SWITCH_TO_STRUCTURE
		128, 0, 42,      # ADD index 0, value 42
		128, 1, 99       # ADD index 1, value 99
	])
	var state := CollectionState.new()
	state.decode(data)
	assert_that(state.items).is_not_null()
	assert_int(state.items.size()).is_equal(2)
	assert_int(state.items.get_item(0)).is_equal(42)
	assert_int(state.items.get_item(1)).is_equal(99)

func test_collection_delete_item():
	var data := PackedByteArray([
		128, 1, 255, 1,
		128, 0, 10,
		128, 1, 20
	])
	var state := CollectionState.new()
	state.decode(data)
	assert_int(state.items.size()).is_equal(2)

	var patch := PackedByteArray([255, 1, 64, 0])
	state.decode(patch)
	assert_int(state.items.size()).is_equal(1)
