extends SceneTree

func _init() -> void:
	var scene = load("res://scenes/ArcherShowcase.tscn").instantiate()
	root.add_child(scene)
	for i in range(5):
		await process_frame
		
	var player = scene.players[0]
	player.play(ArcherAnims.CHARGED_SHOT)
	
	while player.elapsed < 1.9167:
		await process_frame
		
	var rig = scene.archers[0]
	var bow = rig.get_piece("bow")
	var arm = rig.get_piece("arm")
	print("At impact: bow global_pos=", bow.global_position, " global_rot=", bow.global_rotation, " (deg=", rad_to_deg(bow.global_rotation), ")")
	print("arm global_rot=", arm.global_rotation, " (deg=", rad_to_deg(arm.global_rotation), ")")
	print("rig global_scale=", rig.global_scale)
	quit(0)
