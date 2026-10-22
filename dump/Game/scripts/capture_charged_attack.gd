extends Node

const ARTIFACT_DIR = "/home/stark/.gemini/antigravity/brain/9c327554-3d68-4656-8b31-6be9c7767fc3/scratch"

var wb: Node2D = null
var timer: float = 0.0
var step: int = 0

func _ready() -> void:
	print("Archer Charged Capture Runner ready...")
	var scene_res = load("res://scenes/ArcherChargedWorkbench.tscn")
	wb = scene_res.instantiate()
	get_parent().add_child.call_deferred(wb)

func _process(delta: float) -> void:
	if wb == null or not wb.is_inside_tree():
		return
		
	timer += delta
	match step:
		0:
			if timer > 0.4:
				wb._select_frame(1)
				timer = 0.0
				step = 1
		1:
			if timer > 0.35:
				_save_viewport_screenshot(ARTIFACT_DIR + "/charged_frame1.png")
				print("Captured Frame 1")
				wb._select_frame(2)
				timer = 0.0
				step = 2
		2:
			if timer > 0.35:
				_save_viewport_screenshot(ARTIFACT_DIR + "/charged_frame2.png")
				print("Captured Frame 2")
				wb._select_frame(3)
				timer = 0.0
				step = 3
		3:
			if timer > 0.35:
				_save_viewport_screenshot(ARTIFACT_DIR + "/charged_frame3.png")
				print("Captured Frame 3")
				wb._select_frame(4)
				timer = 0.0
				step = 4
		4:
			if timer > 0.35:
				_save_viewport_screenshot(ARTIFACT_DIR + "/charged_frame4.png")
				print("Captured Frame 4")
				wb._select_frame(5)
				timer = 0.0
				step = 5
		5:
			if timer > 0.10:
				_save_viewport_screenshot(ARTIFACT_DIR + "/charged_frame5.png")
				print("Captured Frame 5")
				print("ALL CHARGED FRAMES CAPTURED SUCCESSFULLY!")
				get_tree().quit(0)

func _save_viewport_screenshot(save_path: String) -> void:
	var img = get_viewport().get_texture().get_image()
	if img:
		img.save_png(save_path)
		print("Saved screenshot to: ", save_path)
	else:
		push_error("Viewport texture image was null!")
