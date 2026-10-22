class_name ModularMageUtility

## Ready-to-use utility for loading, instantiating, and querying modular Mage sprites
## across all 4 perspectives (front, back, left, right).

const PERSPECTIVE_SCENES = {
	"front": "res://Mage/mage_front/mage_front.tscn",
	"back": "res://Mage/mage_back/mage_back.tscn",
	"left": "res://Mage/mage_left/mage_left.tscn",
	"right": "res://Mage/mage_right/mage_right.tscn",
	"mage_front": "res://Mage/mage_front/mage_front.tscn",
	"mage_back": "res://Mage/mage_back/mage_back.tscn",
	"mage_left": "res://Mage/mage_left/mage_left.tscn",
	"mage_right": "res://Mage/mage_right/mage_right.tscn"
}

const PERSPECTIVE_JSON = {
	"front": "res://Mage/mage_front/pieces.json",
	"back": "res://Mage/mage_back/pieces.json",
	"left": "res://Mage/mage_left/pieces.json",
	"right": "res://Mage/mage_right/pieces.json",
	"mage_front": "res://Mage/mage_front/pieces.json",
	"mage_back": "res://Mage/mage_back/pieces.json",
	"mage_left": "res://Mage/mage_left/pieces.json",
	"mage_right": "res://Mage/mage_right/pieces.json"
}

const PERSPECTIVE_TEXTURES = {
	"front": "res://Mage/mage_front/Mage_front.png",
	"back": "res://Mage/mage_back/Mage_back.png",
	"left": "res://Mage/mage_left/Mage_left.png",
	"right": "res://Mage/mage_right/Mage_right.png",
	"mage_front": "res://Mage/mage_front/Mage_front.png",
	"mage_back": "res://Mage/mage_back/Mage_back.png",
	"mage_left": "res://Mage/mage_left/Mage_left.png",
	"mage_right": "res://Mage/mage_right/Mage_right.png"
}

## Instantiates a fully assembled modular Mage scene for the requested perspective
static func instantiate_mage(perspective: String) -> MageModularBase:
	var key = perspective.to_lower()
	if not PERSPECTIVE_SCENES.has(key):
		push_error("ModularMageUtility: Unknown perspective '%s'. Valid options are: front, back, left, right." % perspective)
		return null
		
	var scene_path = PERSPECTIVE_SCENES[key]
	var scene = load(scene_path) as PackedScene
	if not scene:
		push_error("ModularMageUtility: Failed to load scene '%s'" % scene_path)
		return null
		
	var instance = scene.instantiate() as MageModularBase
	return instance

## Returns the .tscn scene resource path for a perspective
static func get_scene_path(perspective: String) -> String:
	return PERSPECTIVE_SCENES.get(perspective.to_lower(), "")

## Returns the pieces.json resource path for a perspective
static func get_json_path(perspective: String) -> String:
	return PERSPECTIVE_JSON.get(perspective.to_lower(), "")

## Returns the spritesheet PNG resource path for a perspective.
## The sheet name is read from pieces.json ("spritesheet") so that it stays in
## sync with the atlas that the region rectangles actually refer to. The
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
