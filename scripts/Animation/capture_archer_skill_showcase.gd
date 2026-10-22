extends SceneTree


func _initialize() -> void:
	var showcase: Node = load("res://scenes/ArcherSkillShowcase.tscn").instantiate()
	root.add_child(showcase)
	for _frame in range(40):
		await process_frame
	quit()
