extends GdUnitTestSuite

func test_collection_schema_add():
	var col := CollectionSchema.new()
	col.add("item1")
	col.add("item2")
	assert_int(col.size()).is_equal(2)

func test_collection_schema_has():
	var col := CollectionSchema.new()
	col.add("item1")
	assert_bool(col.has("item1")).is_true()

func test_collection_is_collection():
	var col := CollectionSchema.new()
	assert_bool(col.is_collection()).is_true()
	assert_bool(col.is_map_collection()).is_false()

func test_collection_child_type():
	var col := CollectionSchema.new("string")
	assert_str(col.get_child_type()).is_equal("string")

func test_collection_get_item():
	var col := CollectionSchema.new()
	col.add(42)
	assert_int(col.get_item(0)).is_equal(42)

func test_collection_get_item_out_of_bounds():
	var col := CollectionSchema.new()
	assert_that(col.get_item(0)).is_null()
	assert_that(col.get_item(-1)).is_null()

func test_collection_set_at():
	var col := CollectionSchema.new()
	col.set_at(0, 10)
	col.set_at(1, 20)
	assert_int(col.size()).is_equal(2)
	assert_int(col.get_item(0)).is_equal(10)

func test_collection_set_at_sparse():
	var col := CollectionSchema.new()
	col.set_at(3, 99)
	assert_int(col.size()).is_equal(4)
	assert_that(col.get_item(0)).is_null()
	assert_int(col.get_item(3)).is_equal(99)

func test_collection_delete_at():
	var col := CollectionSchema.new()
	col.add(10)
	col.add(20)
	col.delete_at(0)
	assert_int(col.size()).is_equal(1)
	assert_int(col.get_item(0)).is_equal(20)

func test_collection_clear_items():
	var col := CollectionSchema.new()
	col.add(1)
	col.add(2)
	col.clear_items()
	assert_int(col.size()).is_equal(0)

func test_collection_has_empty():
	var col := CollectionSchema.new()
	assert_bool(col.has("anything")).is_false()
