extends SceneTree

func _init() -> void:
	print("--- BEGINNING MAIN WORKBENCH & SLIDERS INTERACTIVE TEST ---")
	
	var main_scene = load("res://scenes/Main.tscn").instantiate()
	assert(main_scene != null, "Failed to instantiate Main.tscn")
	root.add_child(main_scene)
	main_scene._ready()
	
	print("[TEST 1] Perspective Initialisation:")
	assert(main_scene.knight_back != null, "KnightBack must exist in Main")
	assert(main_scene.knight_right != null, "KnightRight must exist in Main")
	assert(main_scene.active_knight == main_scene.knight_back, "Default active knight should be KnightBack")
	assert(main_scene.knight_back.visible == true, "KnightBack must be visible")
	assert(main_scene.knight_right.visible == false, "KnightRight must be hidden")
	print("  PASS: Back perspective loaded as active.")
	
	print("\n[TEST 2] Perspective Switching:")
	main_scene.set_perspective(false)
	assert(main_scene.active_knight == main_scene.knight_right, "Active knight should now be KnightRight")
	assert(main_scene.knight_right.visible == true, "KnightRight must be visible")
	assert(main_scene.knight_back.visible == false, "KnightBack must be hidden")
	
	main_scene.set_perspective(true)
	assert(main_scene.active_knight == main_scene.knight_back, "Active knight should be back to KnightBack")
	assert(main_scene.knight_back.visible == true, "KnightBack must be visible")
	assert(main_scene.knight_right.visible == false, "KnightRight must be hidden")
	print("  PASS: Perspective toggles seamlessly between Right and Back.")
	
	print("\n[TEST 3] Tuning Sliders Integration:")
	# Jump to F3 (Overhead peak)
	main_scene._on_frame_button_pressed(3)
	assert(abs(main_scene.slider_sh_rot.value - (-160.0)) < 0.1, "F3 shoulder rotation slider should sync to -160°")
	assert(abs(main_scene.slider_wr_rot.value - 27.0) < 0.1, "F3 wrist rotation slider should sync to 27° (tilted)")
	
	# Jump to F4 (Cleave Down with forward foreshortening)
	main_scene._on_frame_button_pressed(4)
	assert(abs(main_scene.slider_sh_rot.value - (-20.0)) < 0.1, "F4 shoulder rotation slider should sync to -20°")
	assert(main_scene.knight_back.arm_sprite.scale.y < 0.65, "F4 arm must be foreshortened along Y (< 0.65)")
	assert(main_scene.knight_back.sword_sprite.scale.y < 0.75, "F4 sword must be foreshortened along Y (< 0.75)")
	assert(main_scene.knight_back.slash_effect.visible == true, "F4 straight vertical trail must be visible")
	
	# Verify check_pivots toggle
	assert(main_scene.check_pivots != null, "CheckPivots checkbox must exist")
	assert(main_scene.knight_back.show_pivot_markers == true, "show_pivot_markers should default to true")
	main_scene.check_pivots.button_pressed = false
	main_scene._on_pivots_toggled(false)
	assert(main_scene.knight_back.show_pivot_markers == false, "show_pivot_markers must toggle to false")
	main_scene.check_pivots.button_pressed = true
	main_scene._on_pivots_toggled(true)
	
	# Manually adjust a slider
	main_scene.slider_sh_x.value = 8.5
	main_scene.slider_sh_y.value = -23.0
	main_scene.slider_wr_rot.value = 50.0
	main_scene._on_tuning_changed()
	
	assert(main_scene.knight_back.shoulder_pivot.position == Vector2(8.5, -23.0), "KnightBack shoulder position must reflect slider changes")
	assert(abs(rad_to_deg(main_scene.knight_back.wrist_pivot.rotation) - 50.0) < 0.1, "KnightBack wrist rotation must reflect slider changes")
	print("  PASS: Sliders manipulate joint coordinates live in real-time.")
	
	print("\n[TEST 4] Pose Dictionary Generation:")
	var code = main_scene._generate_pose_dict_string()
	assert(code.contains('"shoulder_pos": Vector2(8.5, -23.0)'), "Pose string must contain updated shoulder_pos")
	assert(code.contains('"wrist_deg": 50.0'), "Pose string must contain updated wrist_deg")
	print("  PASS: Pose code dictionary formatted accurately:\n" + code)
	
	main_scene.queue_free()
	print("\n>>> MAIN WORKBENCH INTERACTIVE TESTS PASSED WITH 100% SUCCESS! <<<\n")
	quit(0)
