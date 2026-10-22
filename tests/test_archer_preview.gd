extends SceneTree


func _init() -> void:
	_run()


func _run() -> void:
	await process_frame

	var stage := Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(stage)

	var archer := Node2D.new()
	archer.set_script(load("res://scripts/Game/FighterVisual.gd"))
	stage.add_child(archer)
	archer.call("configure", 2)
	archer.call("fit_tile", 128.0)

	var target := Vector2(700, 300)
	var expected := stage.get_global_transform() * target
	var actual: Vector2 = archer.call("_parent_to_global", target)
	assert(actual.is_equal_approx(expected), "Archer preview target must use its Control parent's canvas transform.")

	var effect_spawned := [false]
	stage.child_entered_tree.connect(func(child: Node):
		if child != archer:
			effect_spawned[0] = true
	)
	archer.call("perform", -1, 4, archer.position, target, 1.0)
	await create_timer(1.0).timeout
	assert(effect_spawned[0], "Archer preview attack should spawn its shot under the Control parent.")
	assert(archer.is_inside_tree(), "Archer attack preview should remain in the scene while its clip plays.")

	stage.queue_free()
	await process_frame
	print("Archer preview transform and attack playback passed.")
	quit(0)
