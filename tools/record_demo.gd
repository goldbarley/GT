extends SceneTree

# Sends ordinary interface input; combat uses the normal real-time clock.
var recording_started: int
var events: FileAccess

func _init() -> void:
	_run()

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func caption(title: String, detail: String, active_key: String = "") -> void:
	events.store_line(JSON.stringify({"time": (Time.get_ticks_msec() - recording_started) / 1000.0,
		"title": title, "detail": detail, "key": active_key}))
	events.flush()

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

func click_button(node: Node, text: String) -> bool:
	if node is Button and node.text == text and node.is_visible_in_tree():
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
		if click_button(child, text):
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
	recording_started = Time.get_ticks_msec()
	events = FileAccess.open("/tmp/premove-recording-events.jsonl", FileAccess.WRITE)
	caption("PREMOVE / MOVEMENT TUTORIAL", "Choose a direction. Confirm your route. Watch both plans execute together.")
	await wait(2.5)
	assert(click_button(game, "Couch multiplayer"))
	caption("SET UP A LOCAL MATCH", "Couch multiplayer lets two players plan privately on one computer.")
	await wait(1.5)
	await key(KEY_ENTER, 1.0)
	await key(KEY_RIGHT, 0.8)
	await key(KEY_ENTER, 0.6)
	caption("DEPLOY YOUR FIGHTER", "During deployment, WASD moves the placement marker; Enter places the fighter.", "S")
	await key(KEY_S, 0.8)
	await key(KEY_ENTER, 0.8)
	await key(KEY_SPACE, 0.7)
	await key(KEY_ENTER, 0.7)
	await key(KEY_LEFT, 0.6)
	await key(KEY_ENTER, 0.6)
	await key(KEY_W, 0.6)
	await key(KEY_ENTER, 0.6)
	await key(KEY_SPACE, 0.7)
	await key(KEY_ENTER, 1.8)

	# Use the normal camera option so movement is visible against a fixed grid.
	caption("READ THE GRID", "A fixed whole-map view makes each queued step easy to follow.")
	await key(KEY_ESCAPE, 0.4)
	assert(click_button(game, "Camera: follow fighters"))
	await wait(0.4)
	assert(click_button(game, "Resume"))
	await wait(0.8)

	caption("01 / PREVIEW A MOVE", "W = up, A = left, S = down, D = right. Press A to preview one tile left.", "A")
	await key(KEY_A, 3.0)
	caption("02 / CONFIRM THE MOVE", "Press Enter to queue the step. The planning view previews your route; combat executes it.", "ENTER")
	await key(KEY_ENTER, 3.0)
	caption("03 / EXTEND YOUR ROUTE", "Press W to preview one tile up from the planned position.", "W")
	await key(KEY_W, 2.5)
	caption("04 / ADD THE NEXT STEP", "Press Enter again. Your route is now LEFT, then UP.", "ENTER")
	await key(KEY_ENTER, 2.5)
	caption("05 / ADD AN ATTACK", "Press 1 to select a skill. Arrow keys aim skills; WASD chooses movement.", "1")
	await key(KEY_1, 1.0)
	await key(KEY_DOWN, 0.8)
	caption("CONFIRM THE ATTACK", "Enter adds the aimed skill after the two movement steps.", "ENTER")
	await key(KEY_ENTER, 1.5)
	caption("06 / END THE SEQUENCE", "Press 0 to end your plan after the queued moves and attack.", "0")
	await key(KEY_0, 1.5)
	caption("07 / LOCK YOUR PLAN", "Press Space when ready. Your fighter moves after both players lock their plans.", "SPACE")
	await key(KEY_SPACE, 1.0)
	caption("OPPONENT PLANS PRIVATELY", "The second player queues a route and an attack behind the handoff screen.")
	await key(KEY_ENTER, 1.2)
	await key(KEY_A, 0.35)
	await key(KEY_ENTER, 0.35)
	await key(KEY_W, 0.35)
	await key(KEY_ENTER, 0.35)
	await key(KEY_1, 0.35)
	await key(KEY_UP, 0.35)
	await key(KEY_ENTER, 0.35)
	await key(KEY_0, 0.35)
	caption("08 / BOTH PLANS LOCKED", "Watch the fighters: first LEFT, then UP, then their attacks.", "SPACE")
	await key(KEY_SPACE, 1.5)
	caption("EXECUTION / LEFT, THEN UP", "The queued moves now execute at normal speed. Both players act together.")
	await wait(7.0)
	caption("PLAN. CONFIRM. RESOLVE.", "WASD previews movement | Enter adds each step | 0 ends | Space locks")
	await wait(3.0)
	caption("END", "")
	events.close()
	print("RECORDING DEMO COMPLETE")
	game.call("QuitGame", 0)
