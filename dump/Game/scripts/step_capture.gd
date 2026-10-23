extends SceneTree

func _init() -> void:
	var scene = load("res://scenes/ArcherShowcase.tscn").instantiate()
	root.add_child(scene)
	for i in range(5):
		await process_frame
		
	var player = scene.players[0]
	player.play(ArcherAnims.CHARGED_SHOT)
	
	var out_dir = "/home/stark/.gemini/antigravity/brain/9c327554-3d68-4656-8b31-6be9c7767fc3/archer_godray_comparison"
	DirAccess.make_dir_recursive_absolute(out_dir)
	
	var sample_frames = [36, 45, 52, 65, 78, 79, 80, 85, 92]
	var current_idx = 0
	
	while current_idx < sample_frames.size():
		var target_f = sample_frames[current_idx]
		var target_t = float(target_f - 33) / 24.0
		
		# Wait until player.elapsed reaches target_t
		while player.elapsed < target_t and player.is_playing:
			await process_frame
			
		var img = root.get_viewport().get_texture().get_image()
		var save_path = "%s/new_frame_%04d.png" % [out_dir, target_f]
		img.save_png(save_path)
		print("Captured frame %d at elapsed=%.4f (target=%.4f) -> %s" % [target_f, player.elapsed, target_t, save_path])
		current_idx += 1
		
	quit(0)
