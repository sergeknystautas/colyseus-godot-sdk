extends GdUnitTestSuite

# Tests for nested schemas inside collections.
#
# When a collection holds Schema instances (e.g. MapSchema<Player>),
# each nested schema gets a refId. The binary format:
#
# 1. Root schema field ADD: [op|field_index][refId for collection]
# 2. SWITCH_TO_STRUCTURE to collection: [255][refId]
# 3. Collection ADD: [128][fieldIndex][key (maps only)][refId for child schema]
# 4. SWITCH_TO_STRUCTURE to child: [255][child refId]
# 5. Child schema fields: [op|field_index][value bytes]
# 6. SWITCH back as needed

# --- Nested schema types ---

# A schema that can be a child inside a collection
class PlayerSchema extends Schema:
	var name: String = ""
	var x: float = 0.0
	var y: float = 0.0

	func _init():
		super()
		_define_field(0, "name", "string")
		_define_field(1, "x", "float32")
		_define_field(2, "y", "float32")

# Root state with a schema field (direct child, not in collection)
class StateWithChild extends Schema:
	var player = null  # Will be a PlayerSchema
	var score: int = 0

	func _init():
		super()
		_define_field(0, "player", "ref:PlayerSchema")
		_define_field(1, "score", "uint8")

# Root state with a MapSchema of schemas
class StateWithMap extends Schema:
	var players = null  # Will be a MapSchema holding PlayerSchemas
	var tick: int = 0

	func _init():
		super()
		_define_field(0, "players", "map:ref:PlayerSchema")
		_define_field(1, "tick", "uint8")

# Root state with an ArraySchema of schemas
class StateWithArray extends Schema:
	var items = null  # Will be an ArraySchema holding PlayerSchemas

	func _init():
		super()
		_define_field(0, "items", "array:ref:PlayerSchema")

# --- Direct child schema (ref field) ---

func test_decode_ref_field():
	# ADD player field (refId=1), then SWITCH to it and decode fields
	var data := PackedByteArray([
		128, 1,          # ADD field 0 (player), refId=1
		255, 1,          # SWITCH_TO_STRUCTURE to player
		128,             # ADD field 0 (name) in player
	])
	data.append(0xA5)    # fixstr "alice"
	data.append_array("alice".to_utf8_buffer())
	# ADD field 1 (x): float32 = 10.0 → LE [0x00, 0x00, 0x20, 0x41]
	data.append(129)
	data.append_array(PackedByteArray([0x00, 0x00, 0x20, 0x41]))
	# ADD field 2 (y): float32 = 20.0 → LE [0x00, 0x00, 0xA0, 0x41]
	data.append(130)
	data.append_array(PackedByteArray([0x00, 0x00, 0xA0, 0x41]))

	var state := StateWithChild.new()
	# Register schema factory so decode can create PlayerSchema instances
	state.register_schema_type("PlayerSchema", func(): return PlayerSchema.new())
	state.decode(data)

	assert_that(state.player).is_not_null()
	assert_str(state.player.name).is_equal("alice")
	assert_float(state.player.x).is_equal_approx(10.0, 0.01)
	assert_float(state.player.y).is_equal_approx(20.0, 0.01)

func test_decode_ref_and_primitive():
	# ADD player (refId=1), ADD score=42, SWITCH to player, decode name
	var data := PackedByteArray([
		128, 1,          # ADD player, refId=1
		129, 42,         # ADD score=42
		255, 1,          # SWITCH to player
		128,             # ADD name
	])
	data.append(0xA3)
	data.append_array("bob".to_utf8_buffer())

	var state := StateWithChild.new()
	state.register_schema_type("PlayerSchema", func(): return PlayerSchema.new())
	state.decode(data)

	assert_int(state.score).is_equal(42)
	assert_str(state.player.name).is_equal("bob")

# --- MapSchema of schemas ---

func test_decode_map_of_schemas():
	# ADD players map (refId=1)
	# SWITCH to map
	# ADD index 0, key="sess_1", refId=2
	# SWITCH to player refId=2
	# ADD name="alice", ADD x=5.0
	var data := PackedByteArray([
		128, 1,          # ADD players field, refId=1
		255, 1,          # SWITCH to map
		128, 0,          # ADD index 0
	])
	data.append(0xA6)    # fixstr "sess_1"
	data.append_array("sess_1".to_utf8_buffer())
	data.append(2)       # refId=2 for the PlayerSchema
	# SWITCH to PlayerSchema
	data.append(255)
	data.append(2)
	# ADD name
	data.append(128)
	data.append(0xA5)
	data.append_array("alice".to_utf8_buffer())
	# ADD x = 5.0 → float32 LE [0x00, 0x00, 0xA0, 0x40]
	data.append(129)
	data.append_array(PackedByteArray([0x00, 0x00, 0xA0, 0x40]))

	var state := StateWithMap.new()
	state.register_schema_type("PlayerSchema", func(): return PlayerSchema.new())
	state.decode(data)

	assert_that(state.players).is_not_null()
	assert_int(state.players.size()).is_equal(1)
	var player = state.players.get_item("sess_1")
	assert_that(player).is_not_null()
	assert_str(player.name).is_equal("alice")
	assert_float(player.x).is_equal_approx(5.0, 0.01)

func test_decode_map_multiple_schemas():
	# Two players in the map
	var data := PackedByteArray([
		128, 1,          # ADD players map, refId=1
		255, 1,          # SWITCH to map
	])
	# ADD player 1: index=0, key="p1", refId=2
	data.append(128)
	data.append(0)
	data.append(0xA2)    # fixstr "p1"
	data.append_array("p1".to_utf8_buffer())
	data.append(2)       # refId=2

	# ADD player 2: index=1, key="p2", refId=3
	data.append(128)
	data.append(1)
	data.append(0xA2)
	data.append_array("p2".to_utf8_buffer())
	data.append(3)       # refId=3

	# SWITCH to player 1 and set name
	data.append(255)
	data.append(2)
	data.append(128)     # ADD name
	data.append(0xA5)
	data.append_array("alice".to_utf8_buffer())

	# SWITCH to player 2 and set name
	data.append(255)
	data.append(3)
	data.append(128)
	data.append(0xA3)
	data.append_array("bob".to_utf8_buffer())

	var state := StateWithMap.new()
	state.register_schema_type("PlayerSchema", func(): return PlayerSchema.new())
	state.decode(data)

	assert_int(state.players.size()).is_equal(2)
	assert_str(state.players.get_item("p1").name).is_equal("alice")
	assert_str(state.players.get_item("p2").name).is_equal("bob")

func test_decode_map_schema_update():
	# Initial state: one player
	var data := PackedByteArray([128, 1, 255, 1, 128, 0])
	data.append(0xA2)
	data.append_array("p1".to_utf8_buffer())
	data.append(2)
	data.append(255)
	data.append(2)
	data.append(128)
	data.append(0xA5)
	data.append_array("alice".to_utf8_buffer())
	# ADD x = 0.0
	data.append(129)
	data.append_array(PackedByteArray([0x00, 0x00, 0x00, 0x00]))

	var state := StateWithMap.new()
	state.register_schema_type("PlayerSchema", func(): return PlayerSchema.new())
	state.decode(data)
	assert_float(state.players.get_item("p1").x).is_equal_approx(0.0, 0.01)

	# Patch: SWITCH to player, REPLACE x = 15.0
	var patch := PackedByteArray([255, 2])
	# REPLACE field 1 (x)
	patch.append(1)  # REPLACE(0) + field 1
	patch.append_array(PackedByteArray([0x00, 0x00, 0x70, 0x41]))  # 15.0

	state.decode(patch)
	assert_float(state.players.get_item("p1").x).is_equal_approx(15.0, 0.01)

# --- ArraySchema of schemas ---

func test_decode_array_of_schemas():
	# ADD items array (refId=1)
	# SWITCH to array, ADD index 0, refId=2
	# SWITCH to player, decode fields
	var data := PackedByteArray([
		128, 1,          # ADD items field, refId=1
		255, 1,          # SWITCH to array
		128, 0, 2,       # ADD index 0, refId=2
		255, 2,          # SWITCH to player
		128,             # ADD name
	])
	data.append(0xA5)
	data.append_array("alice".to_utf8_buffer())

	var state := StateWithArray.new()
	state.register_schema_type("PlayerSchema", func(): return PlayerSchema.new())
	state.decode(data)

	assert_int(state.items.size()).is_equal(1)
	assert_str(state.items.get_item(0).name).is_equal("alice")

# --- Polymorphic TYPE_ID ---

class NPCSchema extends Schema:
	var name: String = ""
	var hostile: bool = false

	func _init():
		super()
		_define_field(0, "name", "string")
		_define_field(1, "hostile", "boolean")

class StateWithPolyMap extends Schema:
	var entities = null

	func _init():
		super()
		_define_field(0, "entities", "map:ref:PlayerSchema")

func test_decode_polymorphic_type_id_in_map():
	# Map with polymorphic entries: TYPE_ID marker before refId
	# Entity at index 0 is an NPCSchema (type_id=1)
	var data := PackedByteArray([
		128, 1,          # ADD entities map, refId=1
		255, 1,          # SWITCH to map
		128, 0,          # ADD index 0
	])
	data.append(0xA4)    # fixstr "npc1"
	data.append_array("npc1".to_utf8_buffer())
	data.append(213)     # TYPE_ID marker
	data.append(1)       # type_id=1 (NPCSchema)
	data.append(2)       # refId=2
	# SWITCH to NPC and decode fields
	data.append(255)
	data.append(2)
	data.append(128)     # ADD name
	data.append(0xA5)
	data.append_array("guard".to_utf8_buffer())
	data.append(129)     # ADD hostile
	data.append(1)       # true

	var state := StateWithPolyMap.new()
	state.register_schema_type("PlayerSchema", func(): return PlayerSchema.new())
	state.register_schema_type("NPCSchema", func(): return NPCSchema.new(), 1)
	state.decode(data)

	assert_int(state.entities.size()).is_equal(1)
	var entity = state.entities.get_item("npc1")
	assert_that(entity).is_not_null()
	# Should be an NPCSchema, not PlayerSchema
	assert_str(entity.name).is_equal("guard")
	assert_bool(entity.hostile).is_true()

func test_decode_polymorphic_type_id_in_ref():
	# Direct ref field with TYPE_ID
	var data := PackedByteArray([
		128,             # ADD field 0 (player)
	])
	data.append(213)     # TYPE_ID marker
	data.append(1)       # type_id=1 (NPCSchema)
	data.append(1)       # refId=1
	data.append(255)     # SWITCH to ref
	data.append(1)
	data.append(128)     # ADD name
	data.append(0xA3)
	data.append_array("bob".to_utf8_buffer())
	data.append(129)     # ADD hostile
	data.append(0)       # false

	var state := StateWithChild.new()
	state.register_schema_type("PlayerSchema", func(): return PlayerSchema.new())
	state.register_schema_type("NPCSchema", func(): return NPCSchema.new(), 1)
	state.decode(data)

	assert_that(state.player).is_not_null()
	assert_str(state.player.name).is_equal("bob")
