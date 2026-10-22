extends SceneTree

const KnightIslandScript = preload("res://scripts/KnightIslandController.gd")
const IslandCameraScript = preload("res://scripts/IslandCameraController.gd")

func _init() -> void:
	print("==================================================================")
	print("🧪 STARTING SKY ISLAND 90° CAMERA ROTATION & PERSPECTIVE TEST")
	print("==================================================================")
	
	var scene_res = load("res://scenes/SkyIslandMain.tscn")
	assert(scene_res != null, "SkyIslandMain.tscn must load successfully")
	
	var main = scene_res.instantiate()
	assert(main != null, "SkyIslandMain must instantiate successfully")
	root.add_child(main)
	
	# Allow ready to trigger
	main._ready()
	
	var knight = main.knight
	var camera = main.camera
	var grid: SkyIslandGrid = main.grid
	
	assert(knight != null, "Knight must exist in SkyIslandMain")
	assert(camera != null, "Camera must exist in SkyIslandMain")
	assert(grid != null, "SkyIslandGrid must exist in SkyIslandMain")
	print("✅ PASS: All scene nodes instantiated and bound.")
	
	# TEST 1: Initial perspective is FRONT at 0 degrees
	print("\n[TEST 1] Verifying Initial Perspective (0°):")
	assert(abs(camera.current_angle_deg) < 0.01, "Initial camera angle must be 0°")
	assert(knight.current_perspective == KnightIslandScript.Perspective.FRONT, "Knight must start in FRONT perspective")
	assert(knight.sprite.texture == knight.tex_front, "Knight texture must be Warrior_front")
	assert(knight.get_perspective_name() == "FRONT", "get_perspective_name must return 'FRONT'")
	print("  ✅ PASS: Knight initialized in FRONT view at 0°.")
	
	# TEST 2: Courtyard Spawn
	print("\n[TEST 2] Verifying Courtyard Spawn Location:")
	var tile = grid.world_to_tile(knight.position)
	assert(grid.is_tile_walkable(tile), "Knight spawn tile (%s) must be walkable!" % str(tile))
	print("  ✅ PASS: Knight spawned at walkable tile (%d, %d)." % [tile.x, tile.y])
	
	# TEST 3: 90° Clockwise Rotation -> RIGHT view
	print("\n[TEST 3] Testing 90° Clockwise Rotation:")
	camera.set_angle_degrees(90.0)
	knight.set_perspective_from_angle(90.0)
	assert(knight.current_perspective == KnightIslandScript.Perspective.RIGHT, "Knight perspective must be RIGHT at +90°")
	assert(knight.sprite.texture == knight.tex_right, "Knight texture must be Warrior_right")
	assert(knight.get_perspective_name() == "RIGHT", "get_perspective_name must return 'RIGHT'")
	print("  ✅ PASS: Rotated +90° -> Knight switched to RIGHT view.")
	
	# TEST 4: 90° Counter-Clockwise Rotation -> LEFT view
	print("\n[TEST 4] Testing 90° Counter-Clockwise Rotation:")
	camera.set_angle_degrees(-90.0)
	knight.set_perspective_from_angle(-90.0)
	assert(knight.current_perspective == KnightIslandScript.Perspective.LEFT, "Knight perspective must be LEFT at -90°")
	assert(knight.sprite.texture == knight.tex_left, "Knight texture must be Warrior_left")
	assert(knight.get_perspective_name() == "LEFT", "get_perspective_name must return 'LEFT'")
	print("  ✅ PASS: Rotated -90° -> Knight switched to LEFT view.")
	
	# TEST 5: 180° Rear Rotation -> BACK view
	print("\n[TEST 5] Testing 180° Rear Rotation:")
	camera.set_angle_degrees(180.0)
	knight.set_perspective_from_angle(180.0)
	assert(knight.current_perspective == KnightIslandScript.Perspective.BACK, "Knight perspective must be BACK at 180°")
	assert(knight.sprite.texture == knight.tex_back, "Knight texture must be Warrior_back")
	assert(knight.get_perspective_name() == "BACK", "get_perspective_name must return 'BACK'")
	print("  ✅ PASS: Rotated 180° -> Knight switched to BACK view.")
	
	# TEST 6: Return to 0° Reset -> FRONT view
	print("\n[TEST 6] Testing Reset to 0° Front View:")
	camera.set_angle_degrees(0.0)
	knight.set_perspective_from_angle(0.0)
	assert(knight.current_perspective == KnightIslandScript.Perspective.FRONT, "Knight perspective must return to FRONT at 0°")
	assert(knight.sprite.texture == knight.tex_front, "Knight texture must return to Warrior_front")
	print("  ✅ PASS: Reset to 0° -> Knight restored to FRONT view.")
	
	# TEST 7: Screen Upright Billboarding
	print("\n[TEST 7] Testing Screen-Upright Billboarding:")
	camera.rotation = deg_to_rad(90.0)
	knight._process(0.016)
	var cam = knight.get_viewport().get_camera_2d() if knight.get_viewport() else null
	var expected_rot = cam.global_rotation if cam else 0.0
	assert(abs(knight.visual_root.global_rotation - expected_rot) < 0.001, "Visual root must track camera rotation to remain upright on screen")
	print("  ✅ PASS: Knight maintains upright screen-relative angle across camera rotations.")
	
	print("\n==================================================================")
	print("🎉 ALL 7 SKY ISLAND ROTATION & PERSPECTIVE TESTS PASSED!")
	print("==================================================================")
	quit(0)
