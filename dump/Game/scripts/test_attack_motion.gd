extends SceneTree

func _init() -> void:
	print("--- BEGINNING ATTACK & SWORD TRAIL SHADER VERIFICATION ---")
	
	var knight_scene = load("res://scenes/Knight.tscn")
	if not knight_scene:
		push_error("Failed to load scenes/Knight.tscn")
		quit(1)
		return
	
	var knight = knight_scene.instantiate()
	root.add_child(knight)
	
	# Let _ready run
	knight._ready()
	
	# 1. Verify required nodes exist
	print("\n[TEST 1] Node hierarchy verification:")
	var shield_pivot = knight.get_node_or_null("Visuals/Body/Shield_Pivot")
	var slash_effect = knight.get_node_or_null("Visuals/Body/SlashEffect")
	var sword_trail = knight.get_node_or_null("Visuals/Body/SlashEffect/SwordTrail")
	var slash_particles = knight.get_node_or_null("Visuals/Body/SlashEffect/SlashParticles")
	var slash_back_particles = knight.get_node_or_null("Visuals/Body/SlashEffect/SlashBackParticles")
	
	assert(shield_pivot != null, "Shield_Pivot must exist")
	assert(slash_effect != null, "SlashEffect must exist")
	assert(sword_trail != null, "SwordTrail must exist")
	assert(slash_particles != null, "SlashParticles must exist")
	assert(slash_back_particles != null, "SlashBackParticles must exist")
	print("  PASS: All visual and effect nodes (including forward and back particle systems) exist.")
	
	# 2. Verify Shader Material, Temperature Gradient, Dimensions, and 100% Base Opacity
	print("\n[TEST 2] Shader material and opacity verification:")
	var mat = sword_trail.material as ShaderMaterial
	assert(mat != null, "SwordTrail must have ShaderMaterial")
	assert(mat.shader != null, "Shader must be assigned")
	
	var min_thick = mat.get_shader_parameter("min_thickness_px")
	var max_thick = mat.get_shader_parameter("max_thickness")
	var exp_val = mat.get_shader_parameter("crescent_exponent")
	var angle_s = mat.get_shader_parameter("angle_start")
	var angle_e = mat.get_shader_parameter("angle_end")
	var low_col = mat.get_shader_parameter("low_temp_color")
	var mid_col = mat.get_shader_parameter("mid_temp_color")
	var high_col = mat.get_shader_parameter("high_temp_color")
	var app_op = mat.get_shader_parameter("appearance_opacity")
	
	assert(min_thick == 1.0, "min_thickness_px must be 1.0 for 1px tapered tips")
	assert(is_equal_approx(max_thick, 0.165), "max_thickness must be 0.165 (+10% width from 0.15)")
	assert(is_equal_approx(angle_e - angle_s, 3.34), "Angle range must be ~3.34 rad (+15% length from 2.90 rad)")
	assert(exp_val == 0.6, "crescent_exponent must be 0.6 for slow crescent thinning")
	
	# Temperature colors verification
	assert(high_col.r == 1.0 and high_col.g == 1.0 and high_col.b == 1.0, "high_temp_color must be bright white")
	assert(mid_col.r > 0.8 and mid_col.g > 0.7, "mid_temp_color must be vibrant yellow")
	assert(low_col.r > 0.7 and low_col.g < 0.65, "low_temp_color must be darker yellow/amber")
	
	# Base opacity must be 100% (1.0)
	assert(app_op == 1.0, "appearance_opacity must be 1.0 (100% base opacity)")
	print("  PASS: Dimensions, temperature gradient, and 100% base opacity verified.")
	
	# 3. Verify All-Direction Full-Arc Emission, Forward Inertia Damping, and Back Low-Velocity Damping
	print("\n[TEST 3] Omnidirectional arc emission & dual inertia physics verification:")
	# Both systems must emit along the entire crescent arc via EMISSION_SHAPE_POINTS
	assert(slash_particles.emission_shape == CPUParticles2D.EMISSION_SHAPE_POINTS, "Forward particles must emit from arc points")
	assert(slash_back_particles.emission_shape == CPUParticles2D.EMISSION_SHAPE_POINTS, "Back particles must emit from arc points")
	
	# Verify emission points cover entire slash arc from top tip to bottom tip
	var fwd_pts = slash_particles.emission_points
	var back_pts = slash_back_particles.emission_points
	assert(fwd_pts.size() >= 30, "Forward particles must have points covering full arc (found %d)" % fwd_pts.size())
	assert(back_pts.size() >= 30, "Back particles must have points covering full arc (found %d)" % back_pts.size())
	
	var fwd_min_y = 999.0
	var fwd_max_y = -999.0
	for pt in fwd_pts:
		if pt.y < fwd_min_y: fwd_min_y = pt.y
		if pt.y > fwd_max_y: fwd_max_y = pt.y
	assert(fwd_min_y <= -135.0 and fwd_max_y >= 135.0, "Forward arc points must span from top tip to bottom tip")
	print("  PASS: Arc points span Y from %.1f to %.1f (%d points)." % [fwd_min_y, fwd_max_y, fwd_pts.size()])
	
	# Forward particles: high velocity with high damping (quickly dies down)
	assert(slash_particles.initial_velocity_min >= 180.0, "Forward particles must carry high forward velocity/inertia")
	assert(slash_particles.damping_min >= 100.0, "Forward velocity must quickly die down with high damping")
	
	# Back particles: low velocity that dampens slowly (low damping)
	assert(slash_back_particles.initial_velocity_min <= 30.0, "Back particles must have very low velocity")
	assert(slash_back_particles.damping_min <= 10.0, "Back particles must dampen slowly with low damping")
	
	# Lifespans, 2x particle counts & 2px texture
	assert(slash_particles.amount == 64, "Forward particles amount must be 64 (2x increased from 32)")
	assert(slash_back_particles.amount == 48, "Back particles amount must be 48 (2x increased from 24)")
	assert(slash_particles.lifetime == 2.0 and slash_back_particles.lifetime == 2.0, "Particles must have 2.0s lifespan")
	assert(slash_particles.texture.resource_path.ends_with("pixel_particle_2px.png"), "Forward particles must use 2px texture")
	assert(slash_back_particles.texture.resource_path.ends_with("pixel_particle_2px.png"), "Back particles must use 2px texture")
	print("  PASS: Full-arc point emission, 2x particle amount (64 + 48), forward inertia damping, and back low-velocity damping verified.")
	
	# 4. Verify Left Mouse Click input triggering attack
	print("\n[TEST 4] Left Mouse Click input handling:")
	assert(knight.attack_timer <= 0.0, "Knight should start in idle state")
	
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	knight._unhandled_input(click_event)
	
	assert(knight.attack_timer > 0.0, "Left mouse click must trigger attack")
	print("  PASS: Left mouse click initiates attack successfully.")
	
	# 5. Phase 1 Simulation: Charge Preparation / Wind-up
	print("\n[TEST 5] Phase 1 (Wind-up):")
	knight._physics_process(0.06)
	var rot_phase1 = shield_pivot.rotation
	print("  Phase 1 Arm Rotation: %.2f rad (%.1f deg)" % [rot_phase1, rad_to_deg(rot_phase1)])
	assert(rot_phase1 < -0.3, "Arm must swing upward/backward (negative rotation) during charge preparation")
	assert(sword_trail.visible == false, "Sword trail should remain hidden during wind-up")
	assert(slash_particles.emitting == false and slash_back_particles.emitting == false, "Particles must not emit during wind-up")
	print("  PASS: Arm swung up/back in charge preparation, trail & particles off.")
	
	# 6. Phase 2 Simulation: Rapid Down-Swing, Trail Sweep & Appearance Opacity
	print("\n[TEST 6] Phase 2 (Rapid Down-Swing, Continuous Particle Emission & Trail Sweep):")
	knight._physics_process(0.10)
	var rot_phase2 = shield_pivot.rotation
	print("  Phase 2 Arm Rotation: %.2f rad (%.1f deg)" % [rot_phase2, rad_to_deg(rot_phase2)])
	assert(sword_trail.visible == true, "Sword trail must be visible during down-swing")
	assert(knight.particles_fired == true, "particles_fired flag must be set during down-swing")
	assert(slash_particles.emitting == true, "Forward particles must stream continuously along with the slash")
	assert(slash_back_particles.emitting == true, "Back particles must stream continuously along with the slash")
	
	var sweep_val = mat.get_shader_parameter("trail_sweep")
	var app_val = mat.get_shader_parameter("appearance_opacity")
	assert(sweep_val > 0.0, "trail_sweep must advance downward during down-swing")
	assert(app_val > 0.0, "appearance_opacity must rapidly increase from 0% to 100%")
	print("  Phase 2 Trail Sweep: %.2f, Appearance Opacity: %.2f" % [sweep_val, app_val])
	print("  PASS: Rapid down-swing active, trail draws vertically, particles streaming along with slash.")
	
	# 7. Phase 3 Simulation: Recovery & Low-to-High Temp Thinning Die Down
	print("\n[TEST 7] Phase 3 (Particle Emission Stops & Inner-to-Outer Thinning Die Down):")
	knight._physics_process(0.16)
	var rot_phase3 = shield_pivot.rotation
	var die_down_val = mat.get_shader_parameter("die_down")
	print("  Phase 3 Arm Rotation: %.2f rad (%.1f deg)" % [rot_phase3, rad_to_deg(rot_phase3)])
	print("  Phase 3 Die-down parameter: %.2f" % die_down_val)
	assert(slash_particles.emitting == false, "Forward particle emitter must cease in Phase 3")
	assert(slash_back_particles.emitting == false, "Back particle emitter must cease in Phase 3")
	assert(die_down_val > 0.0, "die_down must progress during recovery")
	print("  PASS: Particle emission stopped, die-down animation thinning from low-temp to high-temp active.")
	
	# 8. Post-Attack Idle Reset
	print("\n[TEST 8] Post-Attack Return to Idle:")
	knight._physics_process(0.20)
	assert(knight.attack_timer <= 0.0, "Attack timer must elapse to 0")
	assert(sword_trail.visible == false, "Sword trail must be hidden once attack completes")
	print("  PASS: Attack cycle completed cleanly and reset to idle.")
	
	print("\n>>> ALL ATTACK & SWORD TRAIL IMPROVEMENT TESTS PASSED SUCCESSFULLY! <<<")
	knight.queue_free()
	quit(0)
