extends MageModularBase
class_name MageRight

const JSON_PATH = "res://assets/characters/Mage/mage_right/pieces.json"
const TEXTURE_PATH = "res://assets/characters/Mage/mage_right/Mage_right_clean.png"

func _init() -> void:
	perspective_name = "right"
	canvas_size = Vector2(37, 32)

func _ready() -> void:
	super._ready()
	if get_child_count() == 0:
		assemble_from_json(JSON_PATH, TEXTURE_PATH)
