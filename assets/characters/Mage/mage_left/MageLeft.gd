extends MageModularBase
class_name MageLeft

const JSON_PATH = "res://assets/characters/Mage/mage_left/pieces.json"
const TEXTURE_PATH = "res://assets/characters/Mage/mage_left/Mage_left_clean.png"

func _init() -> void:
	perspective_name = "left"
	canvas_size = Vector2(38, 32)

func _ready() -> void:
	super._ready()
	if get_child_count() == 0:
		assemble_from_json(JSON_PATH, TEXTURE_PATH)
