extends Node2D

const ArcherUtility := preload("res://assets/characters/Archer/ModularArcherUtility.gd")
const ArcherPlayerScript := preload("res://assets/characters/Archer/ArcherChoreoPlayer.gd")
const WIDTH := 1280
const HEIGHT := 720
const COLUMN_X := [150.0, 475.0, 800.0, 1125.0]
const SKILL_TIMES := [0.12, 0.22, 0.25, 0.38]
const STRONG_TIMES := [0.18, 0.4, 0.67, 0.75]
const CAPTURE_PATH := "/tmp/archer-skills-showcase.png"

var stage: ColorRect
var labels: CanvasLayer


func _ready() -> void:
	_build_stage()
	call_deferred("_build_pose_sheet")


func _build_stage() -> void:
	stage = ColorRect.new()
	stage.color = Color("#171d2b")
	stage.size = Vector2(WIDTH, HEIGHT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	move_child(stage, 0)

	labels = CanvasLayer.new()
	add_child(labels)
	_add_label("ARCHER SKILL / RELEASE AND RECOVERY", Vector2(48, 22), 28, Color("#f5e7c7"))
	_add_label("QUICK SKILL", Vector2(48, 70), 16, Color("#78d9e7"))
	_add_label("STRONG SKILL", Vector2(48, 374), 16, Color("#ffc96b"))
	var line := ColorRect.new()
	line.position = Vector2(48, 357)
	line.size = Vector2(1184, 2)
	line.color = Color("#3d465c")
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(line)
	for col in range(4):
		_add_label(["DRAW", "AIM", "RELEASE", "FOLLOW-THROUGH"][col], Vector2(COLUMN_X[col] - 75, 108), 12, Color("#b8c4d8"))
		_add_label(["BRACE", "DRAW", "HOLD", "RECOIL"][col], Vector2(COLUMN_X[col] - 75, 414), 12, Color("#b8c4d8"))
	_add_label("Skill: quick snap and compact follow-through", Vector2(48, 326), 13, Color("#9eacc2"))
	_add_label("Strong skill: planted stance, loaded hold, stronger recoil", Vector2(48, 674), 13, Color("#9eacc2"))


func _build_pose_sheet() -> void:
	for _frame in range(3):
		await get_tree().process_frame
	for row in range(2):
		var clip := "archer_skill" if row == 0 else "archer_strong_skill"
		var times: Array = SKILL_TIMES if row == 0 else STRONG_TIMES
		for col in range(4):
			var actor: ArcherModularBase = ArcherUtility.instantiate_archer("right")
			actor.scale = Vector2.ONE * 5.0
			actor.position = Vector2(COLUMN_X[col], (226.0 if row == 0 else 530.0) - actor.get_feet_centre().y * actor.scale.y)
			add_child(actor)
			var player: ArcherChoreoPlayer = ArcherPlayerScript.new()
			player.target = actor
			player.smooth_rotation = false
			add_child(player)
			await get_tree().process_frame
			player.play(clip)
			player.set_process(false)
			player.apply_pose(player.sample(float(times[col])))
			actor.set_process(false)
	for _frame in range(2):
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(CAPTURE_PATH)
	if error == OK:
		print("Archer skill showcase saved to ", CAPTURE_PATH)
	else:
		push_error("Could not save Archer skill showcase: %s" % error_string(error))


func _add_label(value: String, at: Vector2, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	labels.add_child(label)
