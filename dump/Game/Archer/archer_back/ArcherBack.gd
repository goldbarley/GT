extends ArcherModularBase
class_name ArcherBack

const JSON_PATH = "res://Archer/archer_back/pieces.json"
const TEXTURE_PATH = "res://Archer/archer_back/Archer_back_clean.png"


func _init() -> void:
	perspective_name = "back"
	canvas_size = Vector2(38, 32)


func _ready() -> void:
	super._ready()
	# If no children exist (e.g. instantiated from pure script without .tscn), assemble from json
	if get_child_count() == 0:
		assemble_from_json(JSON_PATH, TEXTURE_PATH)
