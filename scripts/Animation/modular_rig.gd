extends Node2D
class_name ModularRig

## Base class for modular mage character rigs.
## Supports both pre-built Godot scene nodes (.tscn) and dynamic runtime JSON loading.

@export var perspective_name: String = ""
@export var canvas_size: Vector2 = Vector2(38, 32)

var pieces: Dictionary = {} # String -> Sprite2D
var piece_pivots: Dictionary = {} # String -> Vector2
var piece_gems: Dictionary = {} # String -> Vector2, the gem's offset from the piece's pivot
var original_positions: Dictionary = {} # String -> Vector2
var original_rotations: Dictionary = {} # String -> float

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_register_child_pieces()

## Automatically register existing child Sprite2Ds (e.g. from a .tscn file)
func _register_child_pieces() -> void:
	for child in get_children():
		if child is Sprite2D:
			var piece_name = child.name.to_snake_case()
			pieces[piece_name] = child
			pieces[child.name] = child # Register both PascalCase and snake_case
			original_positions[piece_name] = child.position
			original_rotations[piece_name] = child.rotation
			
			# If child has metadata for pivot, register it
			if child.has_meta("pivot"):
				piece_pivots[piece_name] = child.get_meta("pivot")
			elif child.offset != Vector2.ZERO:
				piece_pivots[piece_name] = -child.offset

			_register_gem(piece_name, child)

## Build/Re-assemble piece nodes dynamically from a pieces.json definition
func assemble_from_json(json_path: String, texture_res_path: String) -> bool:
	if not FileAccess.file_exists(json_path):
		push_error("ModularRig: JSON file not found at " + json_path)
		return false
		
	var file = FileAccess.open(json_path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("ModularRig: JSON parse error: " + json.get_error_message())
		return false
		
	var data = json.get_data() as Dictionary
	if not data:
		return false
		
	perspective_name = data.get("perspective", "")
	var c_size = data.get("canvas_size", {})
	canvas_size = Vector2(c_size.get("width", 38), c_size.get("height", 32))
	
	var texture = load(texture_res_path) as Texture2D
	if not texture:
		push_error("ModularRig: Texture not found at " + texture_res_path)
		return false
		
	# Clear previous pieces
	for p in pieces.values():
		if is_instance_valid(p) and p.get_parent() == self:
			p.queue_free()
	pieces.clear()
	piece_pivots.clear()
	original_positions.clear()
	original_rotations.clear()
	
	var pieces_data = data.get("pieces", {}) as Dictionary
	var base_dir := json_path.get_base_dir()
	for p_name in pieces_data.keys():
		var p_info = pieces_data[p_name] as Dictionary
		var reg = p_info.get("region", {})
		var pos = p_info.get("position", {})
		var piv = p_info.get("pivot", {})
		var z = p_info.get("z_index", 0)
		
		var sprite = Sprite2D.new()
		sprite.name = p_name
		# A piece may bring its own file, which is how the Knight's front view is
		# stored.  Otherwise the piece is a region of the shared sheet.
		var own_texture: Texture2D = null
		if p_info.has("texture"):
			own_texture = load(base_dir + "/" + str(p_info["texture"])) as Texture2D
		if own_texture != null:
			sprite.texture = own_texture
			if not reg.is_empty():
				sprite.region_enabled = true
				sprite.region_rect = Rect2(reg.get("x", 0), reg.get("y", 0), reg.get("w", 1), reg.get("h", 1))
		else:
			sprite.texture = texture
			sprite.region_enabled = true
			sprite.region_rect = Rect2(reg.get("x", 0), reg.get("y", 0), reg.get("w", 1), reg.get("h", 1))
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		
		var pivot_vec = Vector2(piv.get("x", 0), piv.get("y", 0))
		var pos_vec = Vector2(pos.get("x", 0), pos.get("y", 0))
		
		# Set pivot offset so rotation pivots around the defined joint
		sprite.offset = -pivot_vec
		sprite.position = pos_vec + pivot_vec
		sprite.z_index = z
		sprite.set_meta("pivot", pivot_vec)
		
		add_child(sprite)
		pieces[p_name] = sprite
		piece_pivots[p_name] = pivot_vec
		original_positions[p_name] = sprite.position
		original_rotations[p_name] = 0.0
		_register_gem(p_name, sprite)
		
	return true

## The rig's own pieces.json, which is where the roles, the groups and the
## parent relationships live.  The player asks the rig for this, so the same
## player drives any character.
func get_piece_data() -> Dictionary:
	return {}


## Looks for a gem in a piece's own pixels and works out where it sits.
##
## The gem on the staff is found in the art rather than written down by
## hand, so the glow the effect shaders draw always lands exactly on the
## gem, even if the art is redrawn or the staff is turned.  The result is the
## gem's offset from the piece's pivot, which is the point the piece turns
## about.
func _register_gem(piece_name: String, sprite: Sprite2D) -> void:
	var centre := _find_gem_centre(sprite)
	if centre == Vector2.INF:
		return
	var pivot: Vector2 = piece_pivots.get(piece_name, Vector2.ZERO)
	# the pivot is measured in the piece's own pixels, the centre is measured
	# in the texture's, so they have to be brought into the same space
	piece_gems[piece_name] = centre - (sprite.region_rect.position + pivot)


## Finds the bright red gem in a piece and returns where it is, in the
## texture's own pixels.  Returns Vector2.INF when the piece has no gem.
func _find_gem_centre(sprite: Sprite2D) -> Vector2:
	if sprite.texture == null:
		return Vector2.INF
	var image: Image = sprite.texture.get_image()
	if image == null:
		return Vector2.INF
	var region: Rect2 = sprite.region_rect
	var centre := Vector2.ZERO
	var count := 0
	for y in range(int(region.position.y), int(region.end.y)):
		for x in range(int(region.position.x), int(region.end.x)):
			var c := image.get_pixel(x, y)
			# the gem is the one saturated red in the piece
			if c.a > 0.5 and c.r > 0.75 and c.g <= 0.55 and (c.r - c.g) > 0.35:
				centre += Vector2(x, y)
				count += 1
	if count == 0:
		return Vector2.INF
	return centre / float(count)


## Where the mage's feet are, in her own space.
##
## The feet are drawn in a different place in every view, so this comes from
## the rig rather than from a number written down by hand.
func get_feet_centre() -> Vector2:
	var total := Vector2.ZERO
	var count := 0
	for child in get_children():
		if child is Sprite2D and child.name.to_snake_case().begins_with("foot"):
			total += (child as Sprite2D).position
			count += 1
	if count == 0:
		return Vector2(canvas_size.x * 0.5, canvas_size.y)
	return total / float(count)


## Where the gem on a piece is, in the mage's own space, taking into account
## how the piece is currently turned.
##
## The effect shaders use this to put their glow exactly on the gem.
func get_gem_position(piece_name: String = "staff") -> Vector2:
	var sprite: Sprite2D = get_piece(piece_name)
	if sprite == null:
		return Vector2.ZERO
	if not piece_gems.has(piece_name):
		return sprite.position
	var offset: Vector2 = piece_gems[piece_name]
	return sprite.position + offset.rotated(sprite.rotation)


## Access a piece node by name
func get_piece(piece_name: String) -> Sprite2D:
	var key = piece_name.to_snake_case()
	if pieces.has(key):
		return pieces[key]
	if pieces.has(piece_name):
		return pieces[piece_name]
	var node = get_node_or_null(piece_name)
	if node is Sprite2D:
		return node
	return null

## Check if a piece exists
func has_piece(piece_name: String) -> bool:
	return get_piece(piece_name) != null

## Get list of all registered piece names
func get_piece_names() -> Array:
	return pieces.keys()

## Toggle visibility of an individual piece (e.g. hat, staff)
func set_piece_visible(piece_name: String, is_visible: bool) -> void:
	var sprite = get_piece(piece_name)
	if sprite:
		sprite.visible = is_visible

## Rotate a piece around its designated pivot joint
func rotate_piece(piece_name: String, angle_rad: float) -> void:
	var sprite = get_piece(piece_name)
	if sprite:
		sprite.rotation = angle_rad

## Reset all pieces to their default assembled positions & rotations
func reset_pose() -> void:
	for p_name in pieces.keys():
		var sprite = pieces[p_name] as Sprite2D
		if is_instance_valid(sprite) and original_positions.has(p_name):
			sprite.position = original_positions[p_name]
			sprite.rotation = original_rotations[p_name]
			sprite.visible = true
