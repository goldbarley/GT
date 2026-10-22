extends Node

const ARTIFACT_DIR = "/home/stark/.gemini/antigravity/brain/9c327554-3d68-4656-8b31-6be9c7767fc3"

var main_scene: SkyIslandMain = null
var current_step: int = 0
var timer: float = 0.0

func _ready() -> void:
	print("CaptureRunner _ready started...")
	var res = load("res://scenes/SkyIslandMain.tscn")
	main_scene = res.instantiate()
	get_parent().add_child.call_deferred(main_scene)

func _process(delta: float) -> void:
	if main_scene == null or not main_scene.is_inside_tree():
		return
		
	timer += delta
	match current_step:
		0:
			if timer > 0.4:
				_save_viewport_screenshot(ARTIFACT_DIR + "/scratch/view_0deg_front.png")
				print("Captured Front View (0°)")
				main_scene.camera.set_angle_degrees(90.0)
				timer = 0.0
				current_step = 1
		1:
			if timer > 0.5:
				_save_viewport_screenshot(ARTIFACT_DIR + "/scratch/view_plus90deg_right.png")
				print("Captured Right View (+90°)")
				main_scene.camera.set_angle_degrees(-90.0)
				timer = 0.0
				current_step = 2
		2:
			if timer > 0.5:
				_save_viewport_screenshot(ARTIFACT_DIR + "/scratch/view_minus90deg_left.png")
				print("Captured Left View (-90°)")
				print("ALL SCREENSHOTS CAPTURED!")
				get_tree().quit(0)

func _save_viewport_screenshot(save_path: String) -> void:
	var img = get_viewport().get_texture().get_image()
	if img:
		img.save_png(save_path)
		print("Saved screenshot to: ", save_path)
	else:
		push_error("Viewport texture image was null!")
