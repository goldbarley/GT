extends Node

const SAVE_PATH = "/home/stark/.gemini/antigravity/brain/9c327554-3d68-4656-8b31-6be9c7767fc3/scratch/mage_showcase_capture.png"

var timer: float = 0.0
var step: int = 0

func _ready() -> void:
	print("Mage Showcase Capture Runner ready...")

func _process(delta: float) -> void:
	timer += delta
	if step == 0 and timer > 0.5:
		var img = get_viewport().get_texture().get_image()
		if img:
			img.save_png(SAVE_PATH)
			print("Saved screenshot to: ", SAVE_PATH)
		get_tree().quit(0)
