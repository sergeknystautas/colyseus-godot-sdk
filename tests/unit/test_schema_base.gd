extends GdUnitTestSuite

class TestSchema extends Schema:
	var health: int = 100
	var name: String = "default"

	func _init():
		super()
		_define_field(0, "health", "uint8")
		_define_field(1, "name", "string")

func test_schema_instantiation():
	var schema := TestSchema.new()
	assert_int(schema.health).is_equal(100)
	assert_str(schema.name).is_equal("default")

func test_schema_field_definitions():
	var schema := TestSchema.new()
	assert_int(schema._fields_by_index.size()).is_equal(2)
	assert_str(schema._fields_by_index[0].name).is_equal("health")
	assert_str(schema._fields_by_index[0].type).is_equal("uint8")
	assert_str(schema._fields_by_index[1].name).is_equal("name")
	assert_str(schema._fields_by_index[1].type).is_equal("string")

func test_schema_defaults_tracked():
	var schema := TestSchema.new()
	assert_int(schema._defaults.get("health")).is_equal(100)
	assert_str(schema._defaults.get("name")).is_equal("default")

func test_schema_is_not_collection():
	var schema := TestSchema.new()
	assert_bool(schema.is_collection()).is_false()
	assert_bool(schema.is_map_collection()).is_false()

func test_schema_register_type():
	var schema := TestSchema.new()
	schema.register_schema_type("TestSchema", func(): return TestSchema.new())
	assert_bool(schema._schema_types.has("TestSchema")).is_true()

func test_schema_register_type_with_id():
	var schema := TestSchema.new()
	schema.register_schema_type("TestSchema", func(): return TestSchema.new(), 5)
	assert_bool(schema._schema_type_ids.has(5)).is_true()
	assert_str(schema._schema_type_ids[5]).is_equal("TestSchema")
