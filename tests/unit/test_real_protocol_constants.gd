extends GdUnitTestSuite

# These tests assert the REAL Colyseus protocol constants from
# @colyseus/shared-types/src/Protocol.ts. The current SDK has
# invented values, so these will FAIL until Protocol.gd is fixed.

func test_join_room():
	assert_int(Protocol.MessageType.JOIN_ROOM).is_equal(10)

func test_error():
	assert_int(Protocol.MessageType.ERROR).is_equal(11)

func test_leave_room():
	assert_int(Protocol.MessageType.LEAVE_ROOM).is_equal(12)

func test_room_data():
	assert_int(Protocol.MessageType.ROOM_DATA).is_equal(13)

func test_room_state():
	assert_int(Protocol.MessageType.ROOM_STATE).is_equal(14)

func test_room_state_patch():
	assert_int(Protocol.MessageType.ROOM_STATE_PATCH).is_equal(15)

# These don't exist in current Protocol.gd but should:

#func test_room_data_bytes():
#	assert_int(Protocol.MessageType.ROOM_DATA_BYTES).is_equal(17)

#func test_ping():
#	assert_int(Protocol.MessageType.PING).is_equal(18)
