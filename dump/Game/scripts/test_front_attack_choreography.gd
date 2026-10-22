extends SceneTree

func _init() -> void:
	print("--- BEGINNING FRONT ATTACK CHOREOGRAPHY VERIFICATION ---")
	
	var knight_scene = load("res://scenes/Knight.tscn")
	if not knight_scene:
		push_error("Failed to load Knight.tscn")
		quit(1)
		return
		
	var knight = knight_scene.instantiate()
	root.add_child(knight)
	knight._ready()
	
	print("\n[TEST 1] Front Rig Arm & Sword Joint Verification:")
	knight.set_facing(knight.Facing.FRONT)
	assert(knight.active_arm_pivot != null, "ArmR_Pivot must be bound in Facing.FRONT")
	assert(knight.active_sword_pivot != null, "Sword_Pivot must be bound in Facing.FRONT")
	assert(knight.active_sword_sprite != null, "Sprite2D must exist on Sword_Pivot")
	assert(knight.active_point_sprite != null, "PointSprite must exist on Sword_Pivot")
	assert(knight.active_point_sprite.visible == false, "PointSprite must start hidden")
	assert(knight.active_sword_sprite.visible == true, "SwordSprite must start visible")
	print("  PASS: ArmR_Pivot, PointSprite, and SwordSprite bound and initialized.")
	
	print("\n[TEST 2] Left-Flank SlashEffect Alignment:")
	assert(knight.slash_effect != null, "SlashEffect must exist")
	assert(knight.slash_effect.position.x < 0.0, "SlashEffect must be positioned on the knight's right flank (viewer's left)")
	print("  PASS: SlashEffect positioned at %s (left flank alignment verified)." % knight.slash_effect.position)
	
	print("\n[TEST 3] 7-Stage Attack Progression Simulation:")
	# Trigger attack
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	knight._unhandled_input(click)
	assert(knight.attack_timer > 0.0, "Attack must be triggered")
	
	# Simulate through the attack duration (0.45s) in small timesteps
	var base_arm_y = knight.base_positions[knight.active_arm_pivot].y
	var arm_lifted_above_base = false
	var saw_point_sprite = false
	var saw_blade_swing = false
	var saw_arm_low_finish = false
	
	var total_time = 0.0
	var step = 0.01
	while knight.attack_timer > 0.0:
		knight.update_combat_animation(step)
		knight.attack_timer -= step
		total_time += step
		var progress = total_time / knight.ATTACK_DURATION
		
		# Check Arm Lift during wind-up
		if progress < 0.42:
			if knight.active_arm_pivot.position.y < base_arm_y - 2.0:
				arm_lifted_above_base = true
				
		# Check Stage 5 (Camera Point Object)
		if progress >= 0.42 and progress < 0.54:
			if knight.active_point_sprite.visible == true and knight.active_sword_sprite.visible == false:
				saw_point_sprite = true
				
		# Check Stage 6 (Downward Cleave)
		if progress >= 0.54 and progress < 0.76:
			if knight.active_sword_sprite.visible == true and knight.active_sword_pivot.rotation < 0.0:
				saw_blade_swing = true
				
		# Check Stage 7 (Low Arm Follow-Through)
		if progress >= 0.70 and progress < 0.76:
			if knight.active_arm_pivot.position.y > base_arm_y + 2.0:
				saw_arm_low_finish = true
				
	assert(arm_lifted_above_base, "Arm must lift up above base resting position during wind-up")
	assert(saw_point_sprite, "PointSprite must become active during peak camera point (Stage 5)")
	assert(saw_blade_swing, "Blade must swing downward with negative rotation during slash (Stage 6)")
	assert(saw_arm_low_finish, "Arm must drop down past base position for low follow-through (Stage 7)")
	print("  PASS: All 7 stages executed in exact choreography sequence!")
	
	print("\n[TEST 4] Post-Attack Recovery:")
	for f in range(60):
		knight.update_combat_animation(1.0 / 60.0)
	assert(abs(knight.active_arm_pivot.position.y - base_arm_y) < 0.6, "Arm must smoothly return to base resting position within breathing range")
	assert(abs(knight.active_sword_pivot.rotation - knight.base_rotations[knight.active_sword_pivot]) < 0.15, "Sword must return to resting angle (~165 deg)")
	assert(knight.active_sword_sprite.visible == true, "Sword blade must remain visible on idle")
	assert(knight.active_point_sprite.visible == false, "PointSprite must remain hidden on idle")
	print("  PASS: Arm and sword smoothly returned to calibrated resting pose.")
	
	print("\n>>> ALL FRONT ATTACK CHOREOGRAPHY TESTS PASSED! <<<\n")
	quit(0)
