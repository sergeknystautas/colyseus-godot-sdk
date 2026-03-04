extends GdUnitTestSuite

# Tests for reactive callback system: Schema.listen(), MapSchema.on_add/on_remove,
# and nested callbacks (listen on schemas inside collections).

# --- Test schema types ---

class PlayerSchema extends Schema:
	var name: String = ""
	var x: float = 0.0

	func _init():
		super()
		_define_field(0, "name", "string")
		_define_field(1, "x", "float32")

class StateWithPrimitive extends Schema:
	var score: int = 0
	var label: String = ""

	func _init():
		super()
		_define_field(0, "score", "uint8")
		_define_field(1, "label", "string")

class StateWithMap extends Schema:
	var players = null

	func _init():
		super()
		_define_field(0, "players", "map:ref:PlayerSchema")

class StateWithArray extends Schema:
	var items = null

	func _init():
		super()
		_define_field(0, "items", "array:uint8")

# --- Schema.listen() ---

func test_listen_fires_immediately_for_existing_value():
	var state := StateWithPrimitive.new()
	state.score = 42

	var received := []
	state.listen("score", func(value, prev): received.append({"value": value, "prev": prev}))

	assert_int(received.size()).is_equal(1)
	assert_int(received[0].value).is_equal(42)
	assert_that(received[0].prev).is_null()

func test_listen_immediate_false_does_not_fire():
	var state := StateWithPrimitive.new()
	state.score = 42

	var received := []
	state.listen("score", func(value, prev): received.append(value), false)

	assert_int(received.size()).is_equal(0)

func test_listen_fires_on_property_change_after_decode():
	var state := StateWithPrimitive.new()
	# First decode: ADD score = 10
	var data1 := PackedByteArray([128, 10])  # ADD field 0, value 10
	state.decode(data1)

	var received := []
	state.listen("score", func(value, prev): received.append({"value": value, "prev": prev}), false)

	# Second decode: REPLACE score = 20
	var data2 := PackedByteArray([0, 20])  # REPLACE field 0, value 20
	var changes := state.decode(data2)

	# Manually trigger callbacks (normally Room does this)
	for change in changes:
		var ref = change.get("ref")
		if ref and not ref.is_collection():
			var field_name: String = change.get("field", "")
			if field_name in ref._prop_callbacks:
				for cb in ref._prop_callbacks[field_name]:
					cb.call(change.get("value"), change.get("previous"))

	assert_int(received.size()).is_equal(1)
	assert_int(received[0].value).is_equal(20)
	assert_int(received[0].prev).is_equal(10)

func test_listen_unregister_stops_callbacks():
	var state := StateWithPrimitive.new()

	var received := []
	var unsub = state.listen("score", func(value, prev): received.append(value), false)

	# Decode: ADD score = 10
	var data := PackedByteArray([128, 10])
	var changes := state.decode(data)

	# Fire callbacks manually
	for change in changes:
		var ref = change.get("ref")
		if ref and not ref.is_collection():
			var field_name: String = change.get("field", "")
			if field_name in ref._prop_callbacks:
				for cb in ref._prop_callbacks[field_name]:
					cb.call(change.get("value"), change.get("previous"))

	assert_int(received.size()).is_equal(1)

	# Unsubscribe
	unsub.call()

	# Decode again: REPLACE score = 20
	var data2 := PackedByteArray([0, 20])
	var changes2 := state.decode(data2)

	for change in changes2:
		var ref = change.get("ref")
		if ref and not ref.is_collection():
			var field_name: String = change.get("field", "")
			if field_name in ref._prop_callbacks:
				for cb in ref._prop_callbacks[field_name]:
					cb.call(change.get("value"), change.get("previous"))

	# Should still be 1 — no new callback fired
	assert_int(received.size()).is_equal(1)

# --- MapSchema.on_add() ---

func test_on_add_fires_for_existing_items():
	var state := StateWithMap.new()
	state.register_schema_type("PlayerSchema", func(): return PlayerSchema.new())

	# Decode: ADD players map (refId=1), SWITCH to map, ADD item at index 0 with key "p1", child refId=2
	# Then SWITCH to child, ADD name="alice"
	var data := PackedByteArray([
		128, 1,          # ADD field 0 (players), refId=1
		255, 1,          # SWITCH_TO_STRUCTURE to map
		128, 0,          # ADD at fieldIndex 0
	])
	data.append(0xA2)    # fixstr "p1"
	data.append_array("p1".to_utf8_buffer())
	data.append(2)       # child refId=2
	data.append_array([
		255, 2,          # SWITCH to child
		128,             # ADD field 0 (name)
	])
	data.append(0xA5)    # fixstr "alice"
	data.append_array("alice".to_utf8_buffer())

	state.decode(data)

	# Now register on_add with trigger_all=true — should fire for "p1"
	var added := []
	state.players.on_add(func(player, key): added.append({"player": player, "key": key}))

	assert_int(added.size()).is_equal(1)
	assert_str(added[0].key).is_equal("p1")
	assert_str(added[0].player.name).is_equal("alice")

func test_on_add_trigger_all_false_does_not_fire():
	var state := StateWithMap.new()
	state.register_schema_type("PlayerSchema", func(): return PlayerSchema.new())

	# Decode a player
	var data := PackedByteArray([
		128, 1, 255, 1, 128, 0,
	])
	data.append(0xA2)
	data.append_array("p1".to_utf8_buffer())
	data.append(2)
	data.append_array([255, 2, 128])
	data.append(0xA5)
	data.append_array("alice".to_utf8_buffer())

	state.decode(data)

	var added := []
	state.players.on_add(func(player, key): added.append(key), false)

	assert_int(added.size()).is_equal(0)

func test_on_add_fires_when_new_item_decoded():
	var state := StateWithMap.new()
	state.register_schema_type("PlayerSchema", func(): return PlayerSchema.new())

	# First decode: create map
	var data1 := PackedByteArray([128, 1])  # ADD field 0 (players), refId=1
	state.decode(data1)

	# Register callback before second decode
	var added := []
	state.players.on_add(func(player, key): added.append({"player": player, "key": key}), false)

	# Second decode: add a player to existing map
	# SWITCH to map (refId=1), ADD item at index 0 with key "p1", child refId=2
	# SWITCH to child (refId=2), ADD name="bob"
	var data2 := PackedByteArray([
		255, 1,          # SWITCH to map
		128, 0,          # ADD at fieldIndex 0
	])
	data2.append(0xA2)   # fixstr "p1"
	data2.append_array("p1".to_utf8_buffer())
	data2.append(2)      # child refId=2
	data2.append_array([
		255, 2,          # SWITCH to child
		128,             # ADD field 0 (name)
	])
	data2.append(0xA3)   # fixstr "bob"
	data2.append_array("bob".to_utf8_buffer())

	var changes := state.decode(data2)

	# Manually fire callbacks (normally Room does this)
	_fire_collection_callbacks(changes)

	assert_int(added.size()).is_equal(1)
	assert_str(added[0].key).is_equal("p1")
	assert_str(added[0].player.name).is_equal("bob")

# --- MapSchema.on_remove() ---

func test_on_remove_fires_when_item_deleted():
	var state := StateWithMap.new()
	state.register_schema_type("PlayerSchema", func(): return PlayerSchema.new())

	# First decode: create map with one player
	var data1 := PackedByteArray([128, 1, 255, 1, 128, 0])
	data1.append(0xA2)
	data1.append_array("p1".to_utf8_buffer())
	data1.append(2)
	data1.append_array([255, 2, 128])
	data1.append(0xA5)
	data1.append_array("alice".to_utf8_buffer())

	state.decode(data1)

	var removed := []
	state.players.on_remove(func(player, key): removed.append({"player": player, "key": key}))

	# Second decode: DELETE item at fieldIndex 0
	# SWITCH to map (refId=1), DELETE(64) fieldIndex 0
	var data2 := PackedByteArray([255, 1, 64, 0])
	var changes := state.decode(data2)

	_fire_collection_callbacks(changes)

	assert_int(removed.size()).is_equal(1)
	assert_str(removed[0].key).is_equal("p1")
	assert_str(removed[0].player.name).is_equal("alice")

# --- Nested: listen on schema inside a map ---

func test_nested_listen_on_schema_inside_map():
	var state := StateWithMap.new()
	state.register_schema_type("PlayerSchema", func(): return PlayerSchema.new())

	# Create map with player
	var data1 := PackedByteArray([128, 1, 255, 1, 128, 0])
	data1.append(0xA2)
	data1.append_array("p1".to_utf8_buffer())
	data1.append(2)
	data1.append_array([255, 2, 128])
	data1.append(0xA5)
	data1.append_array("alice".to_utf8_buffer())
	# Also set x = 5.0
	data1.append(129)  # ADD field 1 (x)
	data1.append_array(PackedByteArray([0x00, 0x00, 0xA0, 0x40]))  # 5.0 LE

	state.decode(data1)

	var player = state.players.get_item("p1")
	assert_that(player).is_not_null()

	# Register listen on nested player's x property
	var x_changes := []
	player.listen("x", func(value, prev): x_changes.append({"value": value, "prev": prev}), false)

	# Decode: update player x to 10.0
	# SWITCH to player (refId=2), REPLACE field 1 (x)
	var data2 := PackedByteArray([255, 2])
	data2.append(1)  # REPLACE field 1 (x)
	data2.append_array(PackedByteArray([0x00, 0x00, 0x20, 0x41]))  # 10.0 LE

	var changes := state.decode(data2)

	# Fire listen callbacks (normally Room does this)
	for change in changes:
		var ref = change.get("ref")
		if ref and not ref.is_collection():
			var field_name: String = change.get("field", "")
			if field_name in ref._prop_callbacks:
				for cb in ref._prop_callbacks[field_name]:
					cb.call(change.get("value"), change.get("previous"))

	assert_int(x_changes.size()).is_equal(1)
	assert_float(x_changes[0].value).is_equal_approx(10.0, 0.01)
	assert_float(x_changes[0].prev).is_equal_approx(5.0, 0.01)

# --- Collection unregister ---

func test_collection_unregister_stops_callbacks():
	var state := StateWithMap.new()
	state.register_schema_type("PlayerSchema", func(): return PlayerSchema.new())

	# Create map
	var data1 := PackedByteArray([128, 1])
	state.decode(data1)

	var added := []
	var unsub = state.players.on_add(func(player, key): added.append(key), false)

	# Unsubscribe immediately
	unsub.call()

	# Decode: add a player
	var data2 := PackedByteArray([255, 1, 128, 0])
	data2.append(0xA2)
	data2.append_array("p1".to_utf8_buffer())
	data2.append(2)
	data2.append_array([255, 2, 128])
	data2.append(0xA3)
	data2.append_array("bob".to_utf8_buffer())

	var changes := state.decode(data2)
	_fire_collection_callbacks(changes)

	assert_int(added.size()).is_equal(0)

# --- ArraySchema.on_add() ---

func test_array_on_add_fires_for_existing_items():
	var state := StateWithArray.new()

	# Decode: ADD items array (refId=1), SWITCH to array, ADD at index 0, value 42
	var data := PackedByteArray([
		128, 1,          # ADD field 0 (items), refId=1
		255, 1,          # SWITCH to array
		128, 0, 42,      # ADD at index 0, value 42
		128, 1, 99,      # ADD at index 1, value 99
	])
	state.decode(data)

	var added := []
	state.items.on_add(func(value, index): added.append({"value": value, "index": index}))

	assert_int(added.size()).is_equal(2)
	assert_int(added[0].value).is_equal(42)
	assert_int(added[0].index).is_equal(0)
	assert_int(added[1].value).is_equal(99)
	assert_int(added[1].index).is_equal(1)

# --- Schema.on_change() ---

func test_on_change_fires_when_property_changes():
	var state := StateWithPrimitive.new()

	var fired := []
	state.on_change(func(): fired.append(true))

	# Decode: ADD score = 10
	var data := PackedByteArray([128, 10])
	var changes := state.decode(data)
	_fire_all_callbacks(changes)

	assert_int(fired.size()).is_equal(1)

func test_on_change_fires_once_per_batch():
	var state := StateWithPrimitive.new()

	var fired := []
	state.on_change(func(): fired.append(true))

	# Decode: ADD score = 10 AND ADD label = "hi" — two fields, one batch
	var data := PackedByteArray([128, 10, 129])  # ADD field 0 (score=10), ADD field 1 (label)
	data.append(0xA2)   # fixstr "hi"
	data.append_array("hi".to_utf8_buffer())
	var changes := state.decode(data)
	_fire_all_callbacks(changes)

	# Should fire exactly once, not twice
	assert_int(fired.size()).is_equal(1)

func test_on_change_unsubscribe():
	var state := StateWithPrimitive.new()

	var fired := []
	var unsub = state.on_change(func(): fired.append(true))
	unsub.call()

	var data := PackedByteArray([128, 10])
	var changes := state.decode(data)
	_fire_all_callbacks(changes)

	assert_int(fired.size()).is_equal(0)

# --- Collection on_change (replace) ---

func test_array_on_change_fires_on_replace():
	var state := StateWithArray.new()

	# First decode: create array with item
	var data1 := PackedByteArray([
		128, 1,          # ADD field 0 (items), refId=1
		255, 1,          # SWITCH to array
		128, 0, 42,      # ADD at index 0, value 42
	])
	state.decode(data1)

	var replaced := []
	state.items.on_change(func(value, key): replaced.append({"value": value, "key": key}))

	# Second decode: REPLACE item at index 0 with value 99
	# SWITCH to array (refId=1), REPLACE(0) at fieldIndex 0, value 99
	var data2 := PackedByteArray([255, 1, 0, 0, 99])
	var changes := state.decode(data2)
	_fire_all_callbacks(changes)

	assert_int(replaced.size()).is_equal(1)
	assert_int(replaced[0].value).is_equal(99)
	assert_int(replaced[0].key).is_equal(0)

func test_map_on_change_fires_on_replace():
	var state := StateWithMap.new()
	state.register_schema_type("PlayerSchema", func(): return PlayerSchema.new())

	# First decode: create map with one player
	var data1 := PackedByteArray([128, 1, 255, 1, 128, 0])
	data1.append(0xA2)
	data1.append_array("p1".to_utf8_buffer())
	data1.append(2)
	data1.append_array([255, 2, 128])
	data1.append(0xA5)
	data1.append_array("alice".to_utf8_buffer())
	state.decode(data1)

	var replaced := []
	state.players.on_change(func(value, key): replaced.append({"value": value, "key": key}))

	# Second decode: REPLACE player's name field (a nested schema change)
	# SWITCH to player (refId=2), REPLACE field 0 (name) = "bob"
	var data2 := PackedByteArray([255, 2, 0])
	data2.append(0xA3)
	data2.append_array("bob".to_utf8_buffer())
	var changes := state.decode(data2)
	_fire_all_callbacks(changes)

	# The replace is on the nested schema, not on the map itself.
	# Map on_change only fires when the map item is replaced (op="replace" on the collection ref).
	# A nested schema field change fires on the schema's on_change, not the parent map's on_change.
	# So replaced should be empty here — this is the correct behavior.
	assert_int(replaced.size()).is_equal(0)

# --- Helper ---

# Mirrors Room._trigger_callbacks() — fires all callback types
func _fire_all_callbacks(changes: Array) -> void:
	var changed_schemas: Array = []

	for change in changes:
		var ref = change.get("ref")
		if ref == null:
			continue
		if not ref.is_collection():
			var field_name: String = change.get("field", "")
			if field_name in ref._prop_callbacks:
				for cb in ref._prop_callbacks[field_name]:
					cb.call(change.get("value"), change.get("previous"))
			if ref._change_callbacks.size() > 0 and ref not in changed_schemas:
				changed_schemas.append(ref)
		else:
			var op: String = change.get("op", "")
			var key = change.get("key", change.get("field_index"))
			if op == "add":
				for cb in ref._add_callbacks:
					cb.call(change.get("value"), key)
			elif op == "delete":
				for cb in ref._remove_callbacks:
					cb.call(change.get("previous"), key)
			elif op == "replace":
				for cb in ref._change_callbacks:
					cb.call(change.get("value"), key)

	for ref in changed_schemas:
		for cb in ref._change_callbacks:
			cb.call()

# Legacy helper used by existing tests
func _fire_collection_callbacks(changes: Array) -> void:
	_fire_all_callbacks(changes)
