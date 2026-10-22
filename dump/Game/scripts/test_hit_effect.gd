extends SceneTree

const HitEffectClass := preload("res://scripts/hit_effect.gd")

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	print("--- Testing Hit Effect & CharacterController / UniversalMotor Integration ---")

	# 1. Test standalone HitEffect node
	print("1. Testing standalone HitEffect...")
	var hit = HitEffectClass.new()
	root.add_child(hit)
	await process_frame
	assert(not hit.is_playing(), "Hit effect should not be playing before play() is called")

	var finished := [false]
	hit.hit_finished.connect(func(): finished[0] = true)
	hit.play(0.1) # Fast test duration
	assert(hit.is_playing(), "Hit effect should be playing after play()")

	# Advance frames manually to verify step progression
	hit.advance(0.05)
	assert(hit.is_playing(), "Should still be playing at 50% duration")
	hit.advance(0.06)
	assert(finished[0], "hit_finished signal should have emitted after advancing past duration")
	assert(not hit.is_playing(), "Hit effect should have stopped playing")
	hit.queue_free()
	print("✓ Standalone HitEffect played and completed successfully")

	# 2. Test CharacterController.play_hit()
	print("2. Testing CharacterController.play_hit()...")
	var controller := ArcherController.new()
	root.add_child(controller)
	await process_frame

	var hit_signal_received := [false]
	var hit_offset := [Vector2.ZERO]
	controller.hit_received.connect(func(pos):
		hit_signal_received[0] = true
		hit_offset[0] = pos
	)

	controller.play_hit(Vector2(5, -15), 0.1)
	assert(hit_signal_received[0], "controller.hit_received signal should have emitted")
	assert(hit_offset[0] == Vector2(5, -15), "hit_offset should match Vector2(5, -15)")
	assert(controller._hit_effect != null, "_hit_effect should be instantiated on controller")
	assert(controller._hit_effect.is_playing(), "_hit_effect should be playing")
	controller._hit_effect.advance(0.12)
	assert(not controller._hit_effect.is_playing(), "_hit_effect should finish after duration")
	print("✓ CharacterController.play_hit() executed and triggered HitEffect successfully")

	# 3. Test UniversalMotor.play_hit()
	print("3. Testing UniversalMotor.play_hit()...")
	var motor := UniversalMotor.new()
	motor.set_controller(controller)
	root.add_child(motor)
	await process_frame

	hit_signal_received[0] = false
	motor.play_hit(Vector2(0, -10), 0.1)
	assert(hit_signal_received[0], "motor.play_hit() should delegate to controller and emit hit_received")
	assert(hit_offset[0] == Vector2(0, -10), "hit_offset from motor should be Vector2(0, -10)")
	print("✓ UniversalMotor.play_hit() delegated to controller successfully")

	# 4. Test HitEffect.spawn_at()
	print("4. Testing HitEffect.spawn_at()...")
	var spawned = HitEffectClass.spawn_at(root, Vector2(100, 200), 2.0, 0.1)
	assert(spawned != null, "spawned HitEffect should not be null")
	assert(spawned.global_position == Vector2(100, 200), "Position should match spawn coordinates")
	assert(spawned.scale == Vector2(2.0, 2.0), "Scale should match requested scale")
	print("✓ HitEffect.spawn_at() executed successfully")

	print("--- All Hit Effect & Motor/Controller tests passed! ---")
	quit(0)
