extends MageModularBase
class_name MageBack

const JSON_PATH = "res://Mage/mage_back/pieces.json"
const TEXTURE_PATH = "res://Mage/mage_back/Mage_back_clean.png"

func _init() -> void:
	perspective_name = "back"
	canvas_size = Vector2(37, 32)

func _ready() -> void:
	super._ready()
	if get_child_count() == 0:
		assemble_from_json(JSON_PATH, TEXTURE_PATH)
