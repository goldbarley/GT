extends SceneTree

const HitEffectClass := preload("res://assets/effects/hit/hit_effect.gd")
const CharacterControllerClass := preload("res://scripts/Animation/character_controller.gd")
const UniversalMotorClass := preload("res://scripts/Animation/universal_motor.gd")

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	print("--- Testing GT Hit Effect, CharacterController & UniversalMotor ---")

	# 1. Standalone HitEffect
	print("1. Testing GT HitEffect...")
	var hit = HitEffectClass.new()
	root.add_child(hit)
	await process_frame

	var finished := [false]
	hit.hit_finished.connect(func(): finished[0] = true)
	hit.play(0.1)
	hit.advance(0.12)
	assert(finished[0], "hit_finished signal should have fired")
	hit.queue_free()
	print("✓ HitEffect playback and signal verified in GT")

	# 2. CharacterController play_hit
	print("2. Testing GT CharacterController.play_hit()...")
	var controller = CharacterControllerClass.new()
	root.add_child(controller)
	await process_frame

	var hit_signal := [false]
	controller.hit_received.connect(func(_pos): hit_signal[0] = true)
	controller.play_hit(Vector2(0, -10), 0.1)
	assert(hit_signal[0], "controller.hit_received should have fired")
	controller.queue_free()
	print("✓ CharacterController.play_hit() verified in GT")

	# 3. UniversalMotor play_hit
	print("3. Testing GT UniversalMotor.play_hit()...")
	var motor: Node = UniversalMotorClass.new()
	var test_ctrl: Node = CharacterControllerClass.new()
	motor.set_controller(test_ctrl)
	root.add_child(motor)
	await process_frame

	hit_signal[0] = false
	test_ctrl.hit_received.connect(func(_pos): hit_signal[0] = true)
	motor.play_hit(Vector2(0, -10), 0.1)
	assert(hit_signal[0], "motor.play_hit should delegate to controller")
	motor.queue_free()
	print("✓ UniversalMotor.play_hit() verified in GT")

	print("--- All GT Hit Effect tests passed successfully! ---")
	quit(0)
