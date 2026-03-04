extends GdUnitTestSuite

func test_set_schema_add():
	var s := SetSchema.new()
	s.add("item1")
	s.add("item2")
	assert_int(s.size()).is_equal(2)

func test_set_schema_has():
	var s := SetSchema.new()
	s.add("item1")
	assert_bool(s.has("item1")).is_true()
	assert_bool(s.has("item2")).is_false()

func test_set_schema_erase():
	var s := SetSchema.new()
	s.add("item1")
	s.erase("item1")
	assert_bool(s.has("item1")).is_false()

func test_set_is_collection():
	var s := SetSchema.new()
	assert_bool(s.is_collection()).is_true()
	assert_bool(s.is_map_collection()).is_false()

func test_set_child_type():
	var s := SetSchema.new("uint8")
	assert_str(s.get_child_type()).is_equal("uint8")

func test_set_add_duplicate():
	var s := SetSchema.new()
	s.add("item1")
	s.add("item1")
	assert_int(s.size()).is_equal(1)

func test_set_erase_nonexistent():
	var s := SetSchema.new()
	s.erase("nope")  # no crash
	assert_int(s.size()).is_equal(0)

func test_set_set_at_and_delete_at():
	var s := SetSchema.new()
	s.set_at(0, 10)
	s.set_at(1, 20)
	assert_int(s.size()).is_equal(2)
	assert_bool(s.has(10)).is_true()
	s.delete_at(0)
	assert_int(s.size()).is_equal(1)
	assert_bool(s.has(10)).is_false()
	assert_bool(s.has(20)).is_true()

func test_set_clear_items():
	var s := SetSchema.new()
	s.add(1)
	s.add(2)
	s.clear_items()
	assert_int(s.size()).is_equal(0)

func test_set_keys():
	var s := SetSchema.new()
	s.add("a")
	s.add("b")
	var k := s.keys()
	assert_int(k.size()).is_equal(2)
	assert_bool("a" in k).is_true()
	assert_bool("b" in k).is_true()

func test_set_has_empty():
	var s := SetSchema.new()
	assert_bool(s.has("anything")).is_false()
