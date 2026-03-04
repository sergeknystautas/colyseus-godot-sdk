extends GdUnitTestSuite

func test_array_schema_push():
	var arr := ArraySchema.new()
	arr.push(1)
	arr.push(2)
	assert_int(arr.size()).is_equal(2)

func test_array_schema_get():
	var arr := ArraySchema.new()
	arr.push("test")
	assert_str(arr.get_item(0)).is_equal("test")

func test_array_schema_set_at():
	var arr := ArraySchema.new()
	arr.set_at(0, 10)
	arr.set_at(1, 20)
	assert_int(arr.size()).is_equal(2)
	assert_int(arr.get_item(0)).is_equal(10)
	assert_int(arr.get_item(1)).is_equal(20)

func test_array_schema_delete_at():
	var arr := ArraySchema.new()
	arr.push(10)
	arr.push(20)
	arr.delete_at(0)
	assert_int(arr.size()).is_equal(1)
	assert_int(arr.get_item(0)).is_equal(20)

func test_array_is_collection():
	var arr := ArraySchema.new()
	assert_bool(arr.is_collection()).is_true()
	assert_bool(arr.is_map_collection()).is_false()

func test_array_child_type():
	var arr := ArraySchema.new("uint8")
	assert_str(arr.get_child_type()).is_equal("uint8")

func test_array_get_item_out_of_bounds():
	var arr := ArraySchema.new()
	assert_that(arr.get_item(0)).is_null()
	assert_that(arr.get_item(-1)).is_null()
	assert_that(arr.get_item(999)).is_null()

func test_array_set_at_sparse():
	var arr := ArraySchema.new()
	arr.set_at(5, 42)
	assert_int(arr.size()).is_equal(6)
	assert_that(arr.get_item(0)).is_null()
	assert_int(arr.get_item(5)).is_equal(42)

func test_array_delete_at_out_of_bounds():
	var arr := ArraySchema.new()
	arr.push(10)
	arr.delete_at(5)  # no crash
	assert_int(arr.size()).is_equal(1)
	arr.delete_at(-1)  # no crash
	assert_int(arr.size()).is_equal(1)

func test_array_clear_items():
	var arr := ArraySchema.new()
	arr.push(1)
	arr.push(2)
	arr.push(3)
	arr.clear_items()
	assert_int(arr.size()).is_equal(0)
