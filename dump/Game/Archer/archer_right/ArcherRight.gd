extends ArcherModularBase
class_name ArcherRight

const JSON_PATH = "res://Archer/archer_right/pieces.json"
const TEXTURE_PATH = "res://Archer/archer_right/Archer_right_clean.png"


func _init() -> void:
	perspective_name = "right"
	canvas_size = Vector2(35, 31)


func _ready() -> void:
	super._ready()
	# If no children exist (e.g. instantiated from pure script without .tscn), assemble from json
	if get_child_count() == 0:
		assemble_from_json(JSON_PATH, TEXTURE_PATH)
