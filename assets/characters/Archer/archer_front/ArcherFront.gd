extends ArcherModularBase
class_name ArcherFront

const JSON_PATH = "res://assets/characters/Archer/archer_front/pieces.json"
const TEXTURE_PATH = "res://assets/characters/Archer/archer_front/Archer_front_clean.png"


func _init() -> void:
	perspective_name = "front"
	canvas_size = Vector2(33, 32)


func _ready() -> void:
	super._ready()
	# If no children exist (e.g. instantiated from pure script without .tscn), assemble from json
	if get_child_count() == 0:
		assemble_from_json(JSON_PATH, TEXTURE_PATH)
