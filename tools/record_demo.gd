extends SceneTree

# Drives ordinary interface input; combat runs on the normal real-time clock.
func _init() -> void:
	_run()

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func key(code: Key, delay: float = 0.5) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await wait(delay)

func click_button(node: Node, caption: String) -> bool:
	if node is Button and node.text == caption and node.is_visible_in_tree():
		var point: Vector2 = node.get_global_rect().get_center()
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		Input.parse_input_event(event)
		event = InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = false
		Input.parse_input_event(event)
		return true
	for child in node.get_children():
		if click_button(child, caption):
			return true
	return false

func _run() -> void:
	await process_frame
	var game: Node = (load("res://scenes/Premove.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	await wait(1.0)
	FileAccess.open("/tmp/premove-recording.ready", FileAccess.WRITE).store_string("ready")
	while not FileAccess.file_exists("/tmp/premove-recording.start"):
		await process_frame
	await wait(2.0)
	assert(click_button(game, "Couch multiplayer"))
	await wait(1.5)
	await key(KEY_ENTER, 1.2)
	await key(KEY_RIGHT, 1.0)
	await key(KEY_ENTER, 0.7)
	await key(KEY_S, 0.5)
	await key(KEY_ENTER, 0.7)
	await key(KEY_SPACE, 1.0)
	await key(KEY_ENTER, 1.0)
	await key(KEY_LEFT, 0.7)
	await key(KEY_ENTER, 0.7)
	await key(KEY_W, 0.5)
	await key(KEY_ENTER, 0.7)
	await key(KEY_SPACE, 1.0)
	await key(KEY_ENTER, 1.5)
	# Both fighters step left, then trade attacks and guards.
	await key(KEY_A)
	await key(KEY_ENTER)
	await key(KEY_1)
	await key(KEY_DOWN)
	await key(KEY_ENTER)
	await key(KEY_2)
	await key(KEY_ENTER)
	await key(KEY_3)
	await key(KEY_DOWN)
	await key(KEY_ENTER)
	await key(KEY_0)
	await key(KEY_SPACE, 1.0)
	await key(KEY_ENTER, 1.5)
	await key(KEY_A)
	await key(KEY_ENTER)
	await key(KEY_1)
	await key(KEY_UP)
	await key(KEY_ENTER)
	await key(KEY_5)
	await key(KEY_ENTER)
	await key(KEY_2)
	await key(KEY_UP)
	await key(KEY_ENTER)
	await key(KEY_0)
	await key(KEY_SPACE, 11.0)
	print("RECORDING DEMO COMPLETE")
	game.call("QuitGame", 0)
