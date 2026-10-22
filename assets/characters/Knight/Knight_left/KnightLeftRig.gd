extends KnightModularBase
class_name KnightLeft

const JSON_PATH = "res://assets/characters/Knight/Knight_left/pieces.json"
const TEXTURE_PATH = "res://assets/characters/Knight/Knight_left/Knight_left_clean.png"

func _init() -> void:
	perspective_name = "left"
	canvas_size = Vector2(32, 32)

func _ready() -> void:
	super._ready()
	# If no children exist (e.g. instantiated from pure script without .tscn), assemble from json
	if get_child_count() == 0:
		assemble_from_json(JSON_PATH, TEXTURE_PATH)
