extends SceneTree


func _init() -> void:
	_run()


func _run() -> void:
	await process_frame
	var fighter := Node2D.new()
	fighter.set_script(load("res://scripts/Game/FighterVisual.gd"))
	root.add_child(fighter)
	fighter.call("configure", 2)
	fighter.call("show_direction", 4)
	fighter.call("fit_tile", 128.0)
	await process_frame

	var rigs: Dictionary = fighter.get("rigs")
	var rig: ModularRig = rigs["right"]
	var bow: Sprite2D = rig.get_piece("bow")
	var bow_center := bow.to_global(bow.get_rect().get_center())
	if not fighter.call("get_archer_nock_global_position").is_equal_approx(bow_center):
		print("Archer idle nock is not centered on the bow.")
		quit(1)
		return

	ArcherShot.fire_basic_attack(root, bow.global_position, Vector2.RIGHT, 1000.0, 0.0, 1.0, bow)
	var shot: ArrowProjectile
	for child in root.get_children():
		if child is ArrowProjectile:
			shot = child
			break
	if shot == null or not shot.global_position.is_equal_approx(bow_center):
		print("Arrow did not spawn at the bowstring nock.")
		quit(1)
		return
	shot.queue_free()

	fighter.call("perform", -4, 4, Vector2.ZERO, Vector2(400, 180), 2.6)
	await create_timer(1.65).timeout
	var draw_strength: float = fighter.call("get_archer_draw_strength")
	var drawn_nock: Vector2 = fighter.call("get_archer_nock_global_position")
	var string: Line2D = fighter.get("bowstring_upper")
	if draw_strength < 0.8 or drawn_nock.x >= bow.to_global(bow.get_rect().get_center()).x \
			or not string.visible or string.points.size() != 2:
		print("Archer did not pull the bowstring back before release.")
		quit(1)
		return

	fighter.queue_free()
	await process_frame
	print("Archer bowstring draw and nock positioning passed.")
	quit(0)
