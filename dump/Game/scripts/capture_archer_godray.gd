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
	
	var frames_to_sample = [36, 39, 45, 47, 52, 56, 65, 75, 78, 79, 80, 82, 85, 90, 92]
	
	for n in frames_to_sample:
		var t = float(n - 33) / 24.0
		player.scrub_time(t)
		for i in range(3):
			await process_frame
		var img = root.get_viewport().get_texture().get_image()
		var save_path = "%s/our_frame_%04d.png" % [out_dir, n]
		img.save_png(save_path)
		print("Captured our frame %d (t=%.4f) -> %s" % [n, t, save_path])
		
	quit(0)
