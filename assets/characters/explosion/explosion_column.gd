class_name ExplosionColumn
extends Node2D

## A pillar of fire that stands on the ground.
##
## The art comes off a rendered video shot from ground level, so it is a
## column of flame seen from the side, not from above.  The island is looked
## down on from the sky, so the column is treated as a billboard: it is
## turned with the camera and stays upright, the way the characters are.
##
## The column is stretched up until it runs past the top of the screen, so
## there is no top edge to give the game away, and it is cut off at the edge
## of the map, so it does not hang in the sky.  The orb of fire at its foot
## is the same art squashed down, so the two are one shape.

## Emitted when the shot has played all the way out.
signal finished

## The frames, in order.
@export var frames_dir: String = "res://assets/characters/explosion/frames"
## How fast the frames go past, in frames a second.
@export var fps: float = 8.0
## How many source frames to step for every frame shown.
@export var frame_step: int = 4
## The last few frames play at the full rate, so the fire can be seen dying
## out instead of blinking away.
@export var full_rate_frames: int = 20
## How big the blocks of the effect are, in source texels.
@export var pixel_size: float = 16.0
## How wide the column is, in world pixels.  A tile on the island is a shade
## under 24 pixels, so 71 pixels is three tiles.
@export var column_width: float = 106.0
## How many times taller than it is wide the column is drawn.
@export var column_stretch: float = 1.8
## The area the effect is cut off to, in world space.  Set it to the map's
## own bounds, so the column stops at the edge of the island.
@export var clip_rect: Rect2 = Rect2(0.0, 0.0, 456.0, 432.0)

## Where the fire sits in the frames, in source texels.  The column stands
## between x 376 and x 872 and its foot is at y 660; the orb's hot middle is
## at (648, 305).
const COLUMN_FOOT := Vector2(624.0, 660.0)
const ORB_CENTRE := Vector2(648.0, 305.0)
## How wide the fire is in the frames, and how much the orb is squashed.
const FIRE_WIDTH := 496.0
const ORB_SQUASH := 0.34

var _frames: Array[Texture2D] = []
var _column: Sprite2D = null
var _orb: Sprite2D = null
var _clip: Control = null
var _shader_mat: ShaderMaterial = null
var _index: int = 0
var _playing: bool = false
var _accumulator: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_frames()
	_build()
	set_playing(false)


func _load_frames() -> void:
	var dir := DirAccess.open(frames_dir)
	if dir == null:
		push_error("ExplosionColumn: cannot open " + frames_dir)
		return
	var names: Array[String] = []
	for file_name in dir.get_files():
		if file_name.to_lower().ends_with(".png"):
			names.append(file_name)
	names.sort()
	for name in names:
		var texture := load(frames_dir + "/" + name) as Texture2D
		if texture != null:
			_frames.append(texture)


## Makes the clip, the column and the orb.
func _build() -> void:
	# The clip is a control with its contents cut off, because that is the
	# only thing in the engine that can cut a shape to a rectangle.  It sits
	# in the map's own space, so the cut does not move when the camera turns.
	_clip = Control.new()
	_clip.name = "Clip"
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.size = clip_rect.size if clip_rect.size != Vector2.ZERO else Vector2(100000.0, 100000.0)
	add_child(_clip)

	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = load("res://assets/characters/explosion/explosion_blast.gdshader") as Shader
	_shader_mat.set_shader_parameter("pixel_size", pixel_size)

	var scale_x := column_width / FIRE_WIDTH
	var scale_y := scale_x * column_stretch

	_orb = _make_sprite("Orb")
	_orb.scale = Vector2(scale_x, scale_x * ORB_SQUASH)
	# the offset is in the texture's own pixels, and it is scaled with the
	# sprite, so the middle of the fire lands on the node's origin
	_orb.offset = -ORB_CENTRE

	_column = _make_sprite("Column")
	_column.scale = Vector2(scale_x, scale_y)
	_column.offset = -COLUMN_FOOT


func _make_sprite(sprite_name: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = sprite_name
	sprite.material = _shader_mat
	sprite.centered = false
	if not _frames.is_empty():
		sprite.texture = _frames[0]
	_clip.add_child(sprite)
	return sprite


func set_playing(playing: bool) -> void:
	_playing = playing
	if not playing:
		_hide_sprites()
	_index = 0
	_accumulator = 0.0


## Whether the shot is still going.
func is_playing() -> bool:
	return _playing


## Plays the shot out once.
func fire() -> void:
	_index = 0
	_accumulator = 0.0
	_playing = true
	_hide_sprites()
	_show_frame(0)


## Where the cut sits in the world.
##
## A cut of no size means no cut at all: the clip is put far away and made
## big enough to hold everything, so it cuts nothing.
func _clip_world_origin() -> Vector2:
	if clip_rect.size == Vector2.ZERO:
		return global_position - Vector2(50000.0, 50000.0)
	return clip_rect.position


func _hide_sprites() -> void:
	if _column != null:
		_column.modulate = Color(1, 1, 1, 0)
	if _orb != null:
		_orb.modulate = Color(1, 1, 1, 0)


func _show_frame(index: int) -> void:
	if _frames.is_empty():
		return
	_index = clampi(index, 0, _frames.size() - 1)
	_shader_mat.set_shader_parameter("frame_tex", _frames[_index])
	# the whole shot is lit, and the orb is the hottest part of it
	_column.modulate = Color(1, 1, 1, 1)
	_orb.modulate = Color(1, 1, 1, 1)


func _process(delta: float) -> void:
	# the column is a billboard, so it turns with the camera and stays
	# upright, the way the characters do
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		_column.global_rotation = camera.global_rotation
		_orb.global_rotation = camera.global_rotation

	# The cut is in the map's own space, so it stays at the edge of the
	# island however the camera turns or the explosion moves.  The fire is
	# put back on the node inside that cut.
	if _clip != null:
		_clip.size = clip_rect.size / global_scale.abs() if clip_rect.size != Vector2.ZERO else Vector2(100000.0, 100000.0)
		# the cut is in world space, so it lands on the map whatever the
		# explosion is hanging off
		_clip.position = to_local(_clip_world_origin())
		var place := -_clip.position
		_column.position = place
		_orb.position = place

	if not _playing or _frames.is_empty():
		return
	_accumulator += delta * fps
	while _accumulator >= 1.0:
		_accumulator -= 1.0
		# the tail of the shot, where the fire dies out, plays at the full
		# rate so the ending can be seen
		var step := 1
		if _index < _frames.size() - full_rate_frames:
			step = maxi(1, frame_step)
		_index += step
		if _index >= _frames.size():
			# the shot is over
			_playing = false
			_hide_sprites()
			finished.emit()
			return
	_show_frame(_index)
