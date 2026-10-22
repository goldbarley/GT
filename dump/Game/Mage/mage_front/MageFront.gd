extends MageModularBase
class_name MageFront

const JSON_PATH = "res://Mage/mage_front/pieces.json"
const TEXTURE_PATH = "res://Mage/mage_front/Mage_front_clean.png"

func _init() -> void:
	perspective_name = "front"
	canvas_size = Vector2(38, 32)

func _ready() -> void:
	super._ready()
	# If no children exist (e.g. instantiated from pure script without .tscn), assemble from json
	if get_child_count() == 0:
		assemble_from_json(JSON_PATH, TEXTURE_PATH)
