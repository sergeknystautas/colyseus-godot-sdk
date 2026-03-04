extends GdUnitTestSuite

const SERVER_URL := "ws://localhost:2570"
const TIMEOUT_MS := 5000

func test_echo_message():
	var client := preload("res://addons/colyseus/src/client/ColyseusClient.gd").new()
	add_child(client)

	client.connect_to_server(SERVER_URL)
	await assert_signal(client).wait_until(TIMEOUT_MS).is_emitted("connected")

	var room := client.join("echo")
	await assert_signal(room).wait_until(TIMEOUT_MS).is_emitted("joined")

	var received := []
	room.message_received.connect(func(type, data): received.append({"type": type, "data": data}))

	room.send("echo", {"text": "hello", "num": 42})
	await __awaiter.await_millis(2000)

	assert_int(received.size()).is_equal(1)
	assert_str(received[0].type).is_equal("echo")
	assert_str(received[0].data.text).is_equal("hello")
	assert_int(received[0].data.num).is_equal(42)

	client.close_connection()
	remove_child(client)
	client.queue_free()

func test_echo_multiple_messages():
	var client := preload("res://addons/colyseus/src/client/ColyseusClient.gd").new()
	add_child(client)

	client.connect_to_server(SERVER_URL)
	await assert_signal(client).wait_until(TIMEOUT_MS).is_emitted("connected")

	var room := client.join("echo")
	await assert_signal(room).wait_until(TIMEOUT_MS).is_emitted("joined")

	var received := []
	room.message_received.connect(func(type, data): received.append(data))

	room.send("echo", {"seq": 1})
	room.send("echo", {"seq": 2})
	room.send("echo", {"seq": 3})

	# Wait for all three to arrive
	await __awaiter.await_millis(2000)

	assert_int(received.size()).is_equal(3)

	client.close_connection()
	remove_child(client)
	client.queue_free()
