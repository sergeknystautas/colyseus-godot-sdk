extends GdUnitTestSuite

const SERVER_URL := "ws://localhost:2570"
const TIMEOUT_MS := 5000

func test_connect_to_server():
	var client := preload("res://addons/colyseus/src/client/ColyseusClient.gd").new()
	add_child(client)

	client.connect_to_server(SERVER_URL)
	await assert_signal(client).wait_until(TIMEOUT_MS).is_emitted("connected")
	assert_bool(client.is_server_connected()).is_true()

	client.close_connection()
	remove_child(client)
	client.queue_free()

func test_disconnect_emits_signal():
	var client := preload("res://addons/colyseus/src/client/ColyseusClient.gd").new()
	add_child(client)

	client.connect_to_server(SERVER_URL)
	await assert_signal(client).wait_until(TIMEOUT_MS).is_emitted("connected")

	client.close_connection()
	await assert_signal(client).wait_until(TIMEOUT_MS).is_emitted("disconnected")
	assert_bool(client.is_server_connected()).is_false()

	remove_child(client)
	client.queue_free()

func test_connect_to_invalid_url():
	var client := preload("res://addons/colyseus/src/client/ColyseusClient.gd").new()
	add_child(client)

	var errors := []
	client.error.connect(func(code, msg): errors.append(msg))

	client.connect_to_server("ws://localhost:59999")
	await __awaiter.await_millis(3000)

	assert_int(errors.size()).is_greater(0)
	assert_bool(client.is_server_connected()).is_false()

	remove_child(client)
	client.queue_free()

func test_join_room():
	var client := preload("res://addons/colyseus/src/client/ColyseusClient.gd").new()
	add_child(client)

	client.connect_to_server(SERVER_URL)
	await assert_signal(client).wait_until(TIMEOUT_MS).is_emitted("connected")

	var room := client.join("state")
	assert_that(room).is_not_null()
	await assert_signal(room).wait_until(TIMEOUT_MS).is_emitted("joined")

	var session_id: String = room.get_session_id()
	assert_str(session_id).is_not_empty()

	client.close_connection()
	remove_child(client)
	client.queue_free()
