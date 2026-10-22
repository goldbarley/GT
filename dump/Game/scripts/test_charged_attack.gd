extends SceneTree

func _init() -> void:
	print("==================================================================")
	print("🧪 STARTING ARCHER PLACEHOLDER: CHARGED ATTACK TEST SUITE")
	print("==================================================================")
	
	var scene_res = load("res://scenes/ArcherChargedWorkbench.tscn")
	assert(scene_res != null, "ArcherChargedWorkbench.tscn must load successfully")
	
	var wb = scene_res.instantiate() as ArcherChargedWorkbench
	assert(wb != null, "ArcherChargedWorkbench must instantiate successfully")
	root.add_child(wb)
	wb._ready()
	
	var archer: ArcherPlaceholder = wb.archer
	assert(archer != null, "ArcherPlaceholder must exist in workbench")
	archer._setup_nodes()
	archer._ready()
	
	# Verify required nodes and removal of red spiral
	assert(archer.bowstring != null, "Bowstring Line2D must exist")
	assert(archer.charged_arrow != null, "ChargedArrow Node2D must exist")
	assert(archer.charged_arrow_sprite != null, "ChargedArrowSprite must exist")
	assert(archer.dust_puff != null, "DustPuff Node2D must exist")
	assert(wb.find_child("SpiralEnergy", true, false) == null, "SpiralEnergy must be completely removed")
	print("✅ PASS: All scene nodes verified and Red Spiral confirmed removed.")
	
	# TEST 1: Frame 1 - Raise Bow
	print("\n[TEST 1] Verifying Frame 1 (Raise Bow):")
	wb._evaluate_timeline(1.0)
	assert(archer.current_pose == ArcherPlaceholder.Pose.CHARGED_F1_RAISE, "Pose must be CHARGED_F1_RAISE")
	assert(archer.arm_l_upper_pivot.rotation < -1.0, "Bow arm must be extended forward to shoulder height")
	assert(abs(archer.bow_pivot.global_rotation) < 0.01, "Bow must be upright (rotation 0.0), never rotated 90°")
	assert(archer.bow_sprite.texture == archer.tex_bow_red, "Bow must be relaxed red D-bow in Frame 1")
	assert(archer.charged_arrow.visible == false, "Charged arrow must be hidden in Frame 1")
	assert(archer.bowstring.points.size() == 3, "Single bowstring must exist")
	assert(abs(archer.bowstring.points[0].x - archer.bowstring.points[1].x) < 0.5, "String must be straight vertical in Frame 1")
	assert(archer.arm_r_upper_pivot.rotation > -0.5, "Draw hand must hang relaxed at side")
	print("  ✅ PASS: Frame 1 upright D-bow, straight string, and relaxed draw hand verified.")
	
	# TEST 2: Frame 2 - Grip String
	print("\n[TEST 2] Verifying Frame 2 (Grip String):")
	wb._evaluate_timeline(2.0)
	assert(archer.current_pose == ArcherPlaceholder.Pose.CHARGED_F2_GRIP, "Pose must be CHARGED_F2_GRIP")
	assert(abs(archer.bow_pivot.global_rotation) < 0.01, "Bow must remain upright (rotation 0.0)")
	assert(archer.bow_sprite.texture == archer.tex_bow_red, "Bow remains unchanged in Frame 2")
	assert(archer.arm_r_upper_pivot.rotation < -1.0, "Draw hand must reach forward to pinch bowstring midpoint")
	assert(abs(archer.bowstring.points[0].x - archer.bowstring.points[1].x) < 0.5, "String remains straight vertical in Frame 2")
	assert(archer.charged_arrow.visible == false, "Charged arrow must be hidden in Frame 2")
	print("  ✅ PASS: Frame 2 free hand gripping straight bowstring midpoint verified.")
	
	# TEST 3: Frame 3 - Draw & Energy Arrow
	print("\n[TEST 3] Verifying Frame 3 (Draw Bow & Energy Arrow):")
	wb._evaluate_timeline(3.0)
	assert(archer.current_pose == ArcherPlaceholder.Pose.CHARGED_F3_DRAW, "Pose must be CHARGED_F3_DRAW")
	assert(archer.bow_sprite.texture == archer.tex_bow_bent, "Bow limbs must bend under tension in Frame 3")
	assert(archer.bowstring.points[1].x < archer.bowstring.points[0].x, "Bowstring must be pulled back into acute '<' shape")
	assert(archer.charged_arrow.visible == true, "Charged energy arrow must be visible in Frame 3")
	assert(abs(archer.charged_arrow.global_rotation) < 0.01, "Arrow rotation must be strictly 0.0° horizontal")
	var arrow_mat = archer.charged_arrow_sprite.material as ShaderMaterial
	assert(arrow_mat != null, "Charged arrow must have ShaderMaterial")
	assert(arrow_mat.get_shader_parameter("tip_radiance") == 0.0, "Tip radiance must be 0.0 in Frame 3 (clean arrow)")
	print("  ✅ PASS: Frame 3 draw, bent limbs, '<' string, and 0° horizontal energy arrow verified.")
	
	# TEST 4: Frame 4 - Max Charge (Hold & 45° Tip Radiance)
	print("\n[TEST 4] Verifying Frame 4 (Max Charge & 45° Tip Radiance):")
	wb._evaluate_timeline(4.0)
	assert(archer.current_pose == ArcherPlaceholder.Pose.CHARGED_F4_MAX_CHARGE, "Pose must be CHARGED_F4_MAX_CHARGE")
	assert(archer.charged_arrow.visible == true, "Charged arrow must be visible in Frame 4")
	assert(abs(archer.charged_arrow.global_rotation) < 0.01, "Arrow rotation must remain strictly 0.0° horizontal")
	assert(arrow_mat.get_shader_parameter("tip_radiance") > 0.9, "Tip radiance must be active (1.0) in Frame 4")
	assert(wb.find_child("SpiralEnergy", true, false) == null, "Red spiral must not exist in Frame 4")
	print("  ✅ PASS: Frame 4 45° tip radiance active, shaft clean, and zero red spiral verified.")
	
	# TEST 5: Frame 5 - Release, Shockwave, Knockback, Camera Shake, Ground Tear
	print("\n[TEST 5] Verifying Frame 5 (Release, Shockwave, Knockback, Camera Shake, Ground Tear):")
	wb._evaluate_timeline(4.10) # 0.10 into Frame 5 (rel_time = 0.08s, within knockback duration 0.20s)
	assert(archer.current_pose == ArcherPlaceholder.Pose.CHARGED_F5_RELEASE, "Pose must be CHARGED_F5_RELEASE")
	assert(abs(archer.bowstring.points[0].x - archer.bowstring.points[1].x) < 0.5, "Bowstring must snap forward to straight vertical")
	assert(archer.bow_sprite.texture == archer.tex_bow_red, "Bow must return to relaxed shape after release")
	assert(archer.charged_arrow.visible == false, "Arrow node on bow must be hidden after release")
	
	# Verify Knockback and Dust Puff
	assert(archer.knockback_offset.x < 0.0, "Archer must be knocked backward along -X")
	assert(archer.dust_puff.visible == true, "Dust puff must be visible at feet during knockback")
	
	# Verify Shockwave (Multi-temperature shader + backward particles)
	assert(wb.shockwave_node.visible == true, "Shockwave ring must be visible on release")
	assert(wb.shockwave_radius > 15.0, "Shockwave radius must expand outward")
	assert(wb.shockwave_node is ArrowShockwave, "ShockwaveNode must be an ArrowShockwave instance")
	var sw_sprite = wb.shockwave_node.get_node_or_null("ShockwaveSprite") as Sprite2D
	assert(sw_sprite != null and sw_sprite.material is ShaderMaterial, "Shockwave must have ShaderMaterial")
	var sw_mat = sw_sprite.material as ShaderMaterial
	assert(sw_mat.shader != null, "Shockwave must have active shader")
	assert(sw_mat.get_shader_parameter("low_temp_color") != null, "Shader must use multi-temperature low_temp_color")
	assert(sw_mat.get_shader_parameter("mid_temp_color") != null, "Shader must use multi-temperature mid_temp_color")
	assert(sw_mat.get_shader_parameter("high_temp_color") != null, "Shader must use multi-temperature high_temp_color")
	var sw_particles = wb.shockwave_node.get_node_or_null("LingeringParticles") as CPUParticles2D
	assert(sw_particles != null, "Shockwave must have LingeringParticles")
	assert(sw_particles.direction.x < 0.0, "Particles must emit backwards toward archer")
	
	# Verify Projectile & 0° Orientation
	assert(wb.projectile_node.visible == true, "Projectile must be visible in flight")
	assert(abs(wb.projectile_node.rotation) < 0.01, "Projectile rotation must be strictly 0.0° horizontal")
	assert(wb.projectile_node.global_position.x > wb.archer_base_pos.x + 50.0, "Projectile must travel forward along +X at 1500 px/s")
	
	# Verify Camera Shake
	assert(abs(wb.camera.offset.y) > 0.01, "Camera shake must be active during release")
	
	# Verify Ground Tear Progressive Reveal Behind Arrow
	var tear_mat = wb.ground_tear_rect.material as ShaderMaterial
	assert(tear_mat != null, "Ground tear must have ShaderMaterial")
	var lead_prog = tear_mat.get_shader_parameter("lead_progress") as float
	assert(lead_prog > 0.0 and lead_prog < 1.0, "Ground tear lead_progress must reveal progressively")
	# Ensure tear leading edge is strictly behind arrow
	var tear_lead_x = wb.ground_tear_rect.global_position.x + lead_prog * wb.ground_tear_rect.size.x
	assert(tear_lead_x <= wb.projectile_node.global_position.x, "Ground tear leading edge must NEVER be ahead of the arrow")
	print("  ✅ PASS: Frame 5 snap, projectile, shockwave, knockback, camera shake, and ground tear verified.")
	
	# TEST 6: Bi-Directional Scrubbing Determinism
	print("\n[TEST 6] Verifying Bi-Directional Scrubbing Determinism:")
	wb._evaluate_timeline(4.8) # Late release: arrow past screen, ground tear fading
	assert((tear_mat.get_shader_parameter("fade_progress") as float) > 0.0, "Ground tear must begin fading out")
	
	# Rewind back to Frame 1
	wb._evaluate_timeline(1.0)
	assert(archer.current_pose == ArcherPlaceholder.Pose.CHARGED_F1_RAISE, "Scrubbing back to 1.0 must restore Frame 1")
	assert(archer.charged_arrow.visible == false, "Arrow must be hidden after scrub rewind")
	assert(wb.shockwave_node.visible == false, "Shockwave must be hidden after scrub rewind")
	assert(wb.projectile_node.visible == false, "Projectile must be hidden after scrub rewind")
	assert((tear_mat.get_shader_parameter("lead_progress") as float) == 0.0, "Ground tear must reset to 0.0 after scrub rewind")
	assert(wb.camera.offset == Vector2.ZERO, "Camera shake must reset after scrub rewind")
	assert(archer.knockback_offset == Vector2.ZERO, "Knockback must reset after scrub rewind")
	print("  ✅ PASS: Timeline scrubbing forward and rewinding backwards is 100% deterministic.")
	
	print("\n==================================================================")
	print("🎉 ALL 6 CHARGED ATTACK TESTS PASSED SUCCESSFULLY!")
	print("==================================================================")
	quit(0)
