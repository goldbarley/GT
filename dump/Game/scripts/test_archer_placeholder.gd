extends SceneTree

const ArcherScript = preload("res://scripts/archer_placeholder.gd")

func _init() -> void:
	print("--- BEGINNING ARCHER PLACEHOLDER RIG & JOINT SYSTEM TEST ---")
	
	var scene = load("res://scenes/archer_placeholder.tscn")
	if not scene:
		push_error("Failed to load res://scenes/archer_placeholder.tscn")
		quit(1)
		return
	
	var archer = scene.instantiate()
	root.add_child(archer)
	archer._ready()
	
	# TEST 1: Joint Hierarchy & Registry
	print("\n[TEST 1] Joint Registry & Bone Hierarchy Verification:")
	var required_joints = [
		"torso", "head",
		"arm_l_upper", "arm_l_lower", "hand_l", "bow",
		"arm_r_upper", "arm_r_lower", "hand_r", "arrow",
		"leg_l_upper", "leg_l_lower", "foot_l",
		"leg_r_upper", "leg_r_lower", "foot_r"
	]
	for j_name in required_joints:
		var node = archer.get_joint_node(j_name)
		assert(node != null, "Joint '%s' must exist in skeleton" % j_name)
	print("  PASS: All 16 skeletal joints registered and resolved.")
	
	# TEST 2: Joint Manipulation API
	print("\n[TEST 2] Joint Rotation and Position Manipulation API:")
	archer.set_joint_rotation("head", 0.45)
	assert(is_equal_approx(archer.get_joint_rotation("head"), 0.45), "Head rotation must update")
	archer.set_joint_rotation("arm_l_upper", -1.2)
	assert(is_equal_approx(archer.get_joint_rotation("arm_l_upper"), -1.2), "Left arm upper rotation must update")
	archer.set_joint_position("head", Vector2(0, -12))
	assert(archer.get_joint_position("head") == Vector2(0, -12), "Head position must update")
	archer.reset_all_joints()
	assert(is_equal_approx(archer.get_joint_rotation("head"), 0.0), "Head must reset to base rotation")
	print("  PASS: Joint rotation, translation, and reset API operate correctly.")
	
	# TEST 3: Detach & Re-Attach API
	print("\n[TEST 3] Limb & Item Re-attachment Verification:")
	var hand_l = archer.get_joint_node("hand_l")
	var initial_child_count = hand_l.get_child_count()
	assert(initial_child_count >= 2, "Hand L must hold sprite and bow pivot")
	
	# Detach bow
	var detached_bow = archer.detach_from_joint("hand_l")
	assert(detached_bow != null, "Detached child must be returned")
	assert(hand_l.get_child_count() == initial_child_count - 1, "Child count must decrease upon detachment")
	
	# Re-attach bow
	archer.attach_to_joint("hand_l", detached_bow)
	assert(hand_l.get_child_count() == initial_child_count, "Child count must restore upon re-attachment")
	print("  PASS: Detach and re-attach functions work seamlessly.")
	
	# TEST 4: Procedural Archery Poses & Aiming
	print("\n[TEST 4] Procedural Pose States (Idle, Aim, Draw, Release):")
	archer.set_pose(ArcherScript.Pose.IDLE)
	archer._physics_process(0.1)
	assert(archer.current_pose == ArcherScript.Pose.IDLE, "Must be in IDLE pose")
	assert(archer.arrow_sprite.visible == false, "Arrow sprite should be hidden during idle")
	
	# Aim at angle (e.g. 45 degrees up)
	archer.aim_at_angle(-0.785)
	assert(archer.current_pose == ArcherScript.Pose.AIM, "Must transition to AIM pose")
	archer._physics_process(0.1)
	assert(archer.arrow_sprite.visible == true, "Arrow sprite should become visible during aim")
	
	# Draw bowstring with full strength
	archer.draw_bow_string(1.0)
	assert(archer.current_pose == ArcherScript.Pose.DRAW, "Must transition to DRAW pose")
	archer._physics_process(0.1)
	assert(archer.draw_strength == 1.0, "Draw strength must be recorded")
	
	# Release arrow
	archer.release_arrow()
	assert(archer.current_pose == ArcherScript.Pose.RELEASE, "Must transition to RELEASE pose")
	archer._physics_process(0.05)
	assert(archer.arrow_sprite.visible == false, "Arrow sprite should hide upon release")
	print("  PASS: All 4 procedural archery poses execute cleanly.")
	
	# TEST 5: Shader Hook Availability
	print("\n[TEST 5] Shader Hook Availability:")
	var hook = archer.get_shader_hook()
	assert(hook != null, "ShaderHook node must exist for upcoming GLSL shader experiments")
	print("  PASS: ShaderHook node is mounted and ready for GLSL experimentation.")
	
	print("\n>>> ALL ARCHER PLACEHOLDER RIG & JOINT TESTS PASSED SUCCESSFULLY! <<<\n")
	archer.queue_free()
	quit(0)
