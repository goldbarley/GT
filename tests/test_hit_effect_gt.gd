extends SceneTree

const HitEffectClass := preload("res://assets/effects/hit/hit_effect.gd")
const CharacterControllerClass := preload("res://scripts/Animation/character_controller.gd")
const UniversalMotorClass := preload("res://scripts/Animation/universal_motor.gd")


func _init() -> void:
	_run()


func _run() -> void:
	await process_frame

	var hit = HitEffectClass.new()
	root.add_child(hit)
	await process_frame
	var finished := [false]
	hit.hit_finished.connect(func(): finished[0] = true)
	hit.play(0.1)
	hit.advance(0.12)
	assert(finished[0], "HitEffect should emit hit_finished when playback ends.")
	hit.queue_free()
	await process_frame

	var controller = CharacterControllerClass.new()
	root.add_child(controller)
	await process_frame
	var hit_received := [false]
	controller.hit_received.connect(func(_position): hit_received[0] = true)
	controller.play_hit(Vector2(0, -10), 0.1)
	assert(hit_received[0], "CharacterController.play_hit should emit hit_received.")
	controller.queue_free()
	await process_frame

	var motor = UniversalMotorClass.new()
	var test_controller = CharacterControllerClass.new()
	motor.add_child(test_controller)
	motor.set_controller(test_controller)
	root.add_child(motor)
	await process_frame
	hit_received[0] = false
	test_controller.hit_received.connect(func(_position): hit_received[0] = true)
	motor.play_hit(Vector2(0, -10), 0.1)
	assert(hit_received[0], "UniversalMotor.play_hit should forward to its controller.")
	motor.queue_free()
	await process_frame

	print("Hit effect, controller hit flash, and motor forwarding checks passed.")
	quit(0)
