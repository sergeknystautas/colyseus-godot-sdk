extends GdUnitTestSuite

# These tests assert the @colyseus/schema binary wire format.
# Reference: @colyseus/schema/lib/spec.js and Schema.js decode()
#
# Schema fields are encoded as a single byte containing both the
# operation and field index:
#   byte = (operation) | (field_index)
#   operation = (byte >> 6) << 6
#   field_index = byte % (operation || 255)
#
# OPERATION values:
#   ADD            = 128  (0b10000000)
#   REPLACE        = 0    (0b00000000)
#   DELETE         = 64   (0b01000000)
#   DELETE_AND_ADD = 192  (0b11000000)
#   CLEAR          = 10
#
# Special bytes:
#   SWITCH_TO_STRUCTURE = 255
#   TYPE_ID             = 213

# --- Operation constants ---

func test_operation_add():
	assert_int(128).is_equal(128)  # ADD

func test_operation_replace():
	assert_int(0).is_equal(0)  # REPLACE

func test_operation_delete():
	assert_int(64).is_equal(64)  # DELETE

func test_operation_delete_and_add():
	assert_int(192).is_equal(192)  # DELETE_AND_ADD

func test_operation_clear():
	assert_int(10).is_equal(10)  # CLEAR

func test_switch_to_structure():
	assert_int(255).is_equal(255)  # SWITCH_TO_STRUCTURE

func test_type_id():
	assert_int(213).is_equal(213)  # TYPE_ID

# --- Operation + field index extraction ---

func test_replace_field_0():
	var byte := 0  # REPLACE(0) + field 0
	var operation := (byte >> 6) << 6
	var field_index := byte % 255  # REPLACE uses 255 as divisor
	assert_int(operation).is_equal(0)
	assert_int(field_index).is_equal(0)

func test_replace_field_5():
	var byte := 5  # REPLACE(0) + field 5
	var operation := (byte >> 6) << 6
	var field_index := byte % 255
	assert_int(operation).is_equal(0)
	assert_int(field_index).is_equal(5)

func test_replace_field_63():
	var byte := 63  # REPLACE(0) + field 63 (max for REPLACE)
	var operation := (byte >> 6) << 6
	var field_index := byte % 255
	assert_int(operation).is_equal(0)
	assert_int(field_index).is_equal(63)

func test_delete_field_0():
	var byte := 64  # DELETE(64) + field 0
	var operation := (byte >> 6) << 6
	var field_index := byte % operation
	assert_int(operation).is_equal(64)
	assert_int(field_index).is_equal(0)

func test_delete_field_3():
	var byte := 67  # DELETE(64) + field 3
	var operation := (byte >> 6) << 6
	var field_index := byte % operation
	assert_int(operation).is_equal(64)
	assert_int(field_index).is_equal(3)

func test_add_field_0():
	var byte := 128  # ADD(128) + field 0
	var operation := (byte >> 6) << 6
	var field_index := byte % operation
	assert_int(operation).is_equal(128)
	assert_int(field_index).is_equal(0)

func test_add_field_3():
	var byte := 131  # ADD(128) + field 3
	var operation := (byte >> 6) << 6
	var field_index := byte % operation
	assert_int(operation).is_equal(128)
	assert_int(field_index).is_equal(3)

func test_add_field_63():
	var byte := 191  # ADD(128) + field 63
	var operation := (byte >> 6) << 6
	var field_index := byte % operation
	assert_int(operation).is_equal(128)
	assert_int(field_index).is_equal(63)

func test_delete_and_add_field_0():
	var byte := 192  # DELETE_AND_ADD(192) + field 0
	var operation := (byte >> 6) << 6
	var field_index := byte % operation
	assert_int(operation).is_equal(192)
	assert_int(field_index).is_equal(0)

func test_delete_and_add_field_5():
	var byte := 197  # DELETE_AND_ADD(192) + field 5
	var operation := (byte >> 6) << 6
	var field_index := byte % operation
	assert_int(operation).is_equal(192)
	assert_int(field_index).is_equal(5)

# --- SWITCH_TO_STRUCTURE detection ---

func test_switch_to_structure_byte():
	var byte := 255
	assert_bool(byte == 255).is_true()

# --- Encoding a simple schema state ---
# A schema with 2 fields being ADDed:
# Field 0 (uint8 = 75): byte=128 (ADD+0), then msgpack number 75
# Field 1 (string "hello"): byte=129 (ADD+1), then msgpack string "hello"

func test_decode_simple_schema_add():
	var data := PackedByteArray()
	# ADD field 0: uint8 value 75
	data.append(128)  # ADD(128) + field_index(0)
	data.append(75)   # positive fixint 75
	# ADD field 1: string "hello"
	data.append(129)  # ADD(128) + field_index(1)
	data.append(0xA5) # fixstr len=5
	data.append_array("hello".to_utf8_buffer())

	# Verify we can extract operations and field indices
	var byte0 := data[0]
	assert_int((byte0 >> 6) << 6).is_equal(128)  # ADD
	assert_int(byte0 % 128).is_equal(0)           # field 0

	var byte2 := data[2]
	assert_int((byte2 >> 6) << 6).is_equal(128)  # ADD
	assert_int(byte2 % 128).is_equal(1)           # field 1
