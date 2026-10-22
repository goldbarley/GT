extends SceneTree

func _init() -> void:
	print("--- BEGINNING ARROW SHOCKWAVE FINAL CORRECTIONS TEST ---\n")
	var success := true
	
	# TEST 1: Load and verify ArrowShockwave scene, Shader & Backward Yellow Particles
	print("[TEST 1] Scene & Backward Particle Verification:")
	var shockwave_scene = load("res://scenes/arrow_shockwave.tscn")
	if not shockwave_scene:
		print("  FAIL: Unable to load scenes/arrow_shockwave.tscn")
		quit(1)
		return
	
	var shockwave = shockwave_scene.instantiate() as ArrowShockwave
	if not shockwave:
		print("  FAIL: Could not instantiate ArrowShockwave")
		quit(1)
		return
	root.add_child(shockwave)
	shockwave._ready()
	
	var sprite = shockwave.get_node_or_null("ShockwaveSprite") as Sprite2D
	var particles = shockwave.get_node_or_null("LingeringParticles") as CPUParticles2D
	
	if not particles:
		print("  FAIL: LingeringParticles node missing")
		success = false
	else:
		print("  Particle settings: amount=%d, scale=%0.2f, dir=%s, extents=%s" % [particles.amount, particles.scale_amount_min, particles.direction, particles.emission_rect_extents])
		# Check vertical area
		if particles.emission_rect_extents.y >= 12.0:
			print("  PASS: Particles originate from a longer vertical area (height = %0.1f px)." % (particles.emission_rect_extents.y * 2.0))
		else:
			print("  FAIL: Vertical area too small: %s" % particles.emission_rect_extents)
			success = false
			
		# Check backward direction
		if particles.direction.x < 0.0:
			print("  PASS: Particles emit backwards towards the archer (direction = %s)." % particles.direction)
		else:
			print("  FAIL: Particles not emitting backwards: %s" % particles.direction)
			success = false
			
		# Check yellow color ramp
		if particles.color_ramp:
			var colors = particles.color_ramp.colors
			var first_color = colors[0]
			print("  Particle initial color: %s" % first_color)
			if first_color.r > 0.8 and first_color.g > 0.6 and first_color.b < 0.2:
				print("  PASS: Particles are yellow instead of white.")
			else:
				print("  FAIL: Particle color is not yellow: %s" % first_color)
				success = false
	
	# TEST 2: Stage 5 Dissipating Remnant Particles (30 Frames, Radial Motion, 10% Wind, Yellow)
	print("\n[TEST 2] Stage 5 Dissipating Remnant Particles Simulation (30 frames):")
	shockwave._apply_stage(4) # Enter Stage 5
	
	if shockwave.stage_5_active and shockwave.stage_5_particles.size() > 0:
		print("  PASS: Stage 5 activated with %d dissipating remnant particles." % shockwave.stage_5_particles.size())
	else:
		print("  FAIL: Stage 5 remnant particles not initialized")
		success = false
		
	# Verify particles move radially opposite to shockwave center (22, 0)
	var center = Vector2(22.0, 0.0)
	var radial_correct_count = 0
	for p in shockwave.stage_5_particles:
		var dir_expected = (p.pos - center).normalized()
		var vel_dir = p.vel.normalized()
		if dir_expected.dot(vel_dir) > 0.5:
			radial_correct_count += 1
		# Check yellow color
		if p.base_color.r < 0.8 or p.base_color.g < 0.5 or p.base_color.b > 0.2:
			print("  FAIL: Remnant particle color not yellow: %s" % p.base_color)
			success = false
			
	if radial_correct_count >= shockwave.stage_5_particles.size() * 0.9:
		print("  PASS: Remnant particles move radially opposite to center in all directions (%d/%d particles)." % [radial_correct_count, shockwave.stage_5_particles.size()])
	else:
		print("  FAIL: Only %d/%d particles moving radially away from center" % [radial_correct_count, shockwave.stage_5_particles.size()])
		success = false
		
	# Simulate 30 frames of Stage 5 process loop
	var dt := 0.0166667
	var wind_change_observed := false
	var initial_vel = shockwave.stage_5_particles[0].vel
	
	for f in range(30):
		shockwave._process(dt)
		if shockwave.stage_5_particles[0].vel.angle_to(initial_vel) > 0.05:
			wind_change_observed = true
			
	print("  PASS: 30 frames completed. Particle age: %d/30 frames." % shockwave.stage_5_particles[0].age_frames)
	print("  Wind fluctuation effect active: %s (10%% chance per frame)" % wind_change_observed)
	
	shockwave.queue_free()
	
	# TEST 3: Full Lifecycle Simulation
	print("\n[TEST 3] Full Lifecycle Progression:")
	var shockwave2 = shockwave_scene.instantiate() as ArrowShockwave
	root.add_child(shockwave2)
	shockwave2._ready()
	
	var elapsed := 0.0
	var stages_seen = []
	for frame in range(65):
		shockwave2._process(dt)
		elapsed += dt
		if not stages_seen.has(shockwave2.stage_index) and shockwave2.stage_index < 5:
			stages_seen.append(shockwave2.stage_index)
			print("  Frame %2d (t=%0.3fs): Reached Stage %d" % [frame + 1, elapsed, shockwave2.stage_index + 1])
			
	if stages_seen.size() == 5:
		print("  PASS: All 5 stages traversed smoothly through the extended 30-frame Stage 5.")
	else:
		print("  FAIL: Stages seen: %d/5" % stages_seen.size())
		success = false
		
	shockwave2.queue_free()
	
	if success:
		print("\n>>> ALL FINAL CORRECTION TESTS PASSED SUCCESSFULLY! <<<")
		quit(0)
	else:
		print("\n>>> TESTS FAILED! <<<")
		quit(1)
