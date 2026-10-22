extends SceneTree


func _init() -> void:
	_run()


func _run() -> void:
	await process_frame
	var destination := Vector2(320, 180)
	for character_class in [0, 1, 2]:
		var fighter := Node2D.new()
		fighter.set_script(load("res://scripts/Game/FighterVisual.gd"))
		root.add_child(fighter)
		fighter.call("configure", character_class)
		fighter.call("fit_tile", 128.0)
		await process_frame

		fighter.call("perform", 5, 4, Vector2.ZERO, destination, 1.0)
		if fighter.get("active_clip") != "mage_teleport":
			print("Teleport did not start the shared vanish animation for class ", character_class, ".")
			quit(1)
			return
		await create_timer(1.25).timeout
		if not fighter.position.is_equal_approx(destination) or fighter.get("active_clip") != "mage_teleport_reappear":
			print("Class ", character_class, " did not land at the target between teleport phases.")
			quit(1)
			return
		await create_timer(1.25).timeout
		if fighter.get("active_clip") != "":
			print("Teleport ended on unexpected clip: ", fighter.get("active_clip"))
			quit(1)
			return
		fighter.queue_free()
		await process_frame

	print("Shared teleport animation passed for Mage, Knight, and Archer.")
	quit(0)
