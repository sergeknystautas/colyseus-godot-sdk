extends GdUnitTestSuite

func test_map_schema_add():
	var map := MapSchema.new()
	map.add_item("key1", "value1")
	assert_str(map.get_item("key1")).is_equal("value1")

func test_map_schema_remove():
	var map := MapSchema.new()
	map.add_item("key1", "value1")
	map.erase("key1")
	assert_that(map.get_item("key1")).is_null()

func test_map_schema_has():
	var map := MapSchema.new()
	map.add_item("key1", 100)
	assert_bool(map.has("key1")).is_true()
	assert_bool(map.has("key2")).is_false()

func test_map_schema_size():
	var map := MapSchema.new()
	assert_int(map.size()).is_equal(0)
	map.add_item("key1", "value1")
	map.add_item("key2", "value2")
	assert_int(map.size()).is_equal(2)

func test_map_schema_keys():
	var map := MapSchema.new()
	map.add_item("key1", "value1")
	map.add_item("key2", "value2")
	assert_int(map.keys().size()).is_equal(2)

func test_map_schema_index_tracking():
	var map := MapSchema.new()
	map.set_index(0, "player_1")
	map.set_by_index(0, 100)
	assert_int(map.get_item("player_1")).is_equal(100)

func test_map_schema_delete_by_index():
	var map := MapSchema.new()
	map.set_index(0, "player_1")
	map.set_by_index(0, 100)
	map.delete_by_index(0)
	assert_int(map.size()).is_equal(0)

func test_map_is_collection():
	var map := MapSchema.new()
	assert_bool(map.is_collection()).is_true()
	assert_bool(map.is_map_collection()).is_true()

func test_map_child_type():
	var map := MapSchema.new("string")
	assert_str(map.get_child_type()).is_equal("string")

func test_map_get_item_missing():
	var map := MapSchema.new()
	assert_that(map.get_item("nonexistent")).is_null()

func test_map_add_item_overwrite():
	var map := MapSchema.new()
	map.add_item("key", "first")
	map.add_item("key", "second")
	assert_str(map.get_item("key")).is_equal("second")
	assert_int(map.size()).is_equal(1)

func test_map_clear_items():
	var map := MapSchema.new()
	map.set_index(0, "a")
	map.set_by_index(0, 1)
	map.set_index(1, "b")
	map.set_by_index(1, 2)
	map.clear_items()
	assert_int(map.size()).is_equal(0)
	assert_that(map.get_item("a")).is_null()

func test_map_get_index():
	var map := MapSchema.new()
	map.set_index(0, "player_1")
	assert_str(map.get_index(0)).is_equal("player_1")
	assert_str(map.get_index(99)).is_equal("")

func test_map_set_by_index_missing_key():
	var map := MapSchema.new()
	# No index set — set_by_index should be a no-op
	map.set_by_index(0, 42)
	assert_int(map.size()).is_equal(0)

func test_map_delete_by_index_missing():
	var map := MapSchema.new()
	# No crash when deleting non-existent index
	map.delete_by_index(99)
	assert_int(map.size()).is_equal(0)

func test_map_erase_nonexistent():
	var map := MapSchema.new()
	map.erase("nope")  # no crash
	assert_int(map.size()).is_equal(0)
