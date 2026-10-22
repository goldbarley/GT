class_name ModularArcherUtility
extends RefCounted

## Ready-to-use utility for loading, instantiating, and querying modular Archer
## sprites across all 4 perspectives (front, back, left, right).

const PERSPECTIVE_SCENES = {
	"front": "res://assets/characters/Archer/archer_front/archer_front.tscn",
	"back": "res://assets/characters/Archer/archer_back/archer_back.tscn",
	"left": "res://assets/characters/Archer/archer_left/archer_left.tscn",
	"right": "res://assets/characters/Archer/archer_right/archer_right.tscn",
	"archer_front": "res://assets/characters/Archer/archer_front/archer_front.tscn",
	"archer_back": "res://assets/characters/Archer/archer_back/archer_back.tscn",
	"archer_left": "res://assets/characters/Archer/archer_left/archer_left.tscn",
	"archer_right": "res://assets/characters/Archer/archer_right/archer_right.tscn"
}

const PERSPECTIVE_JSON = {
	"front": "res://assets/characters/Archer/archer_front/pieces.json",
	"back": "res://assets/characters/Archer/archer_back/pieces.json",
	"left": "res://assets/characters/Archer/archer_left/pieces.json",
	"right": "res://assets/characters/Archer/archer_right/pieces.json",
	"archer_front": "res://assets/characters/Archer/archer_front/pieces.json",
	"archer_back": "res://assets/characters/Archer/archer_back/pieces.json",
	"archer_left": "res://assets/characters/Archer/archer_left/pieces.json",
	"archer_right": "res://assets/characters/Archer/archer_right/pieces.json"
}

const PERSPECTIVE_TEXTURES = {
	"front": "res://assets/characters/Archer/archer_front/Archer_front.png",
	"back": "res://assets/characters/Archer/archer_back/Archer_back.png",
	"left": "res://assets/characters/Archer/archer_left/Archer_left.png",
	"right": "res://assets/characters/Archer/archer_right/Archer_right.png",
	"archer_front": "res://assets/characters/Archer/archer_front/Archer_front.png",
	"archer_back": "res://assets/characters/Archer/archer_back/Archer_back.png",
	"archer_left": "res://assets/characters/Archer/archer_left/Archer_left.png",
	"archer_right": "res://assets/characters/Archer/archer_right/Archer_right.png"
}

## Instantiates a fully assembled modular Archer scene for the requested perspective
static func instantiate_archer(perspective: String) -> ArcherModularBase:
	var key = perspective.to_lower()
	if not PERSPECTIVE_SCENES.has(key):
		push_error("ModularArcherUtility: Unknown perspective '%s'. Valid options are: front, back, left, right." % perspective)
		return null

	var scene_path = PERSPECTIVE_SCENES[key]
	var scene = load(scene_path) as PackedScene
	if not scene:
		push_error("ModularArcherUtility: Failed to load scene '%s'" % scene_path)
		return null

	var instance = scene.instantiate() as ArcherModularBase
	return instance

## Returns the .tscn scene resource path for a perspective
static func get_scene_path(perspective: String) -> String:
	return PERSPECTIVE_SCENES.get(perspective.to_lower(), "")

## Returns the pieces.json resource path for a perspective
static func get_json_path(perspective: String) -> String:
	return PERSPECTIVE_JSON.get(perspective.to_lower(), "")

## Returns the spritesheet PNG resource path for a perspective.
## The sheet name is read from pieces.json ("spritesheet") so that it stays
## in sync with the atlas that the region rectangles actually refer to. The
## PERSPECTIVE_TEXTURES table is only used as a fallback.
static func get_texture_path(perspective: String) -> String:
	var key = perspective.to_lower()
	var data: Dictionary = get_piece_data(key)
	var sheet: String = str(data.get("spritesheet", ""))
	if sheet != "":
		var json_path: String = get_json_path(key)
		if json_path != "":
			return json_path.get_base_dir().path_join(sheet)
	return PERSPECTIVE_TEXTURES.get(key, "")

## Loads and parses the raw coordinate and pivot dictionary from pieces.json
static func get_piece_data(perspective: String) -> Dictionary:
	var path = get_json_path(perspective)
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(content) == OK:
		return json.get_data() as Dictionary
	return {}

## Returns list of supported perspectives
static func get_available_perspectives() -> Array[String]:
	return ["front", "back", "left", "right"]
