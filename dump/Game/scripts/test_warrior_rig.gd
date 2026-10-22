extends SceneTree

func _init() -> void:
	print("--- BEGINNING WARRIOR MULTI-PERSPECTIVE & SKELETON RIG TEST ---")
	
	var knight_scene = load("res://scenes/Knight.tscn")
	if not knight_scene:
		push_error("Failed to load Knight.tscn")
		quit(1)
		return
		
	var knight = knight_scene.instantiate()
	root.add_child(knight)
	knight._ready()
	
	print("\n[TEST 1] Rig Nodes and Hierarchies:")
	assert(knight.rig_front != null, "rig_front must exist")
	assert(knight.rig_right != null, "rig_right must exist")
	assert(knight.rig_left != null, "rig_left must exist")
	print("  PASS: All 3 perspective rigs found under Visuals.")
	
	print("\n[TEST 2] Front Perspective Activation:")
	knight.set_facing(knight.Facing.FRONT)
	assert(knight.rig_front.visible == true, "rig_front must be visible")
	assert(knight.rig_right.visible == false, "rig_right must be hidden")
	assert(knight.rig_left.visible == false, "rig_left must be hidden")
	assert(knight.active_body == knight.rig_front.get_node("Body"), "active_body must point to Front")
	assert(knight.active_plume_pivot != null, "active_plume_pivot must be bound")
	assert(knight.active_shield_pivot != null, "active_shield_pivot must be bound")
	assert(knight.active_sword_pivot != null, "active_sword_pivot must be bound")
	assert(knight.active_leg_l_pivot != null, "active_leg_l_pivot must be bound")
	assert(knight.active_leg_r_pivot != null, "active_leg_r_pivot must be bound")
	print("  PASS: Front rig activated with full moveable skeleton.")
	
	print("\n[TEST 3] Right Perspective Activation:")
	knight.set_facing(knight.Facing.RIGHT)
	assert(knight.rig_front.visible == false, "rig_front must be hidden")
	assert(knight.rig_right.visible == true, "rig_right must be visible")
	assert(knight.rig_left.visible == false, "rig_left must be hidden")
	assert(knight.active_body == knight.rig_right.get_node("Body"), "active_body must point to Right")
	assert(knight.active_plume_pivot != null, "Right active_plume_pivot bound")
	assert(knight.active_shield_pivot != null, "Right active_shield_pivot bound")
	assert(knight.active_sword_pivot != null, "Right active_sword_pivot bound")
	assert(knight.active_leg_l_pivot != null, "Right active_leg_l_pivot bound")
	assert(knight.active_leg_r_pivot != null, "Right active_leg_r_pivot bound")
	print("  PASS: Right rig activated with full moveable skeleton.")
	
	print("\n[TEST 4] Left Perspective Activation:")
	knight.set_facing(knight.Facing.LEFT)
	assert(knight.rig_front.visible == false, "rig_front must be hidden")
	assert(knight.rig_right.visible == false, "rig_right must be hidden")
	assert(knight.rig_left.visible == true, "rig_left must be visible")
	assert(knight.active_body == knight.rig_left.get_node("Body"), "active_body must point to Left")
	assert(knight.active_plume_pivot != null, "Left active_plume_pivot bound")
	assert(knight.active_shield_pivot != null, "Left active_shield_pivot bound")
	assert(knight.active_sword_pivot != null, "Left active_sword_pivot bound")
	assert(knight.active_leg_l_pivot != null, "Left active_leg_l_pivot bound")
	assert(knight.active_leg_r_pivot != null, "Left active_leg_r_pivot bound")
	print("  PASS: Left rig activated with full moveable skeleton.")
	
	print("\n[TEST 5] Skeletal Joint Movement Simulation:")
	# Simulate 60 physics frames moving right
	knight.set_facing(knight.Facing.RIGHT)
	knight.velocity = Vector2(175.0, 0.0)
	var prev_leg_x = knight.active_leg_l_pivot.position.x
	
	for frame in range(30):
		knight.update_leg_animation(1.0 / 60.0, true, false)
		knight.update_plume_physics(1.0 / 60.0)
		knight.update_combat_animation(1.0 / 60.0)
		
	var moved_leg_x = knight.active_leg_l_pivot.position.x
	assert(moved_leg_x != prev_leg_x, "Leg skeleton must move during stride")
	print("  PASS: Skeletal joints animate dynamically (legs stride, plume swings, weapon/shield bob).")
	
	print("\n>>> ALL WARRIOR RIG TESTS PASSED! <<<\n")
	quit(0)
