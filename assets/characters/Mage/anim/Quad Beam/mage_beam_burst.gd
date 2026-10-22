class_name MageBeamBurst
extends Node2D

## The mage's ultimate shot, thrown in four directions at once.
##
## Each beam is a sprite running through the frames of the shot, with the
## muzzle pinned to the mage's hand and the whole sprite turned to aim.  The
## frames come off a rendered video at 1280x720 and are kept at that size,
## because a smaller copy loses the colour of the beam and the key goes with
## the colour.  The blocks of the effect are a fixed part of the picture, so
## they get smaller with the beam, which is what keeps it in the same league
## as the hand drawn art.

## Emitted when the shot has played all the way out.
signal finished

## The frames, in order.
@export var frames_dir: String = "res://assets/characters/Mage/anim/Quad Beam/frames"
## The dim that comes up while the shot winds up.  It is made here so the
## whole effect is one node that can be dropped onto a character.
@export var dim: QuadBeamDim = null
## How fast the frames go past, in frames a second.
@export var fps: float = 30.0
## How many source frames to step for every frame shown.
@export var frame_step: int = 3
## The last few frames play at full rate, so the end of the shot lands.
@export var full_rate_frames: int = 20
## How big the blocks of the effect are, in source texels.  The frames are
## the full size the video came out at, so the blocks scale with the beam:
## at the default beam size these come out about one pixel on screen.
@export var pixel_size: float = 4.0
## How big the beams are.
@export var beam_scale: float = 0.25

## The angle the beam is drawn at in the frames, below horizontal.
const ART_ANGLE := 23.0

## The four ways the shot goes out, and the turn each one needs.  The frames
## come off a shot that went down and to the right, so every beam is turned
## from that to a true diagonal.
const DIRECTIONS := {
	"north_east": -45.0 - ART_ANGLE,
	"north_west": -135.0 - ART_ANGLE,
	"south_east": 45.0 - ART_ANGLE,
	"south_west": 135.0 - ART_ANGLE,
}

## Where the muzzle sits in the frames, in source texels, measured from the
## bright pixels of the charge.
const MUZZLE := Vector2(300.0, 247.0)

var _frames: Array[Texture2D] = []
var _exempt_rig: Node = null
var _beams: Array[Sprite2D] = []
var _frame_index: int = 0
var _playing: bool = false
var _accumulator: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_frames()
	_build_dim()
	_build_beams()
	set_playing(false)


func _load_frames() -> void:
	var dir := DirAccess.open(frames_dir)
	if dir == null:
		push_error("MageBeamBurst: cannot open " + frames_dir)
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


## Makes the dim that comes up while the shot winds up.
##
## A dim that is already there is left where it is, so several bursts can
## share one.  Two dimming lights would take twice as much light away.
func _build_dim() -> void:
	if dim != null:
		return
	dim = QuadBeamDim.new()
	dim.name = "Dim"
	add_child(dim)


func _build_beams() -> void:
	var shader: Shader = load("res://assets/characters/Mage/anim/Quad Beam/beam_blast.gdshader") as Shader
	for direction in DIRECTIONS.keys():
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("key_floor", 0.45)
		material.set_shader_parameter("key_soft", 0.20)
		material.set_shader_parameter("key_saturation", 0.32)
		material.set_shader_parameter("pixel_size", pixel_size)

		var beam := Sprite2D.new()
		beam.name = "Beam" + str(direction).to_pascal_case()
		beam.material = material
		beam.centered = false
		# The sprite needs a texture of its own to have a quad to draw, even
		# though the shader takes its image from the frame_tex uniform.
		if not _frames.is_empty():
			beam.texture = _frames[0]
		# The muzzle sits on the mage, and the whole picture turns to aim.
		# With the sprite not centred, the offset shifts the texture away
		# from the node's origin, so this puts the muzzle on the origin.
		beam.offset = -MUZZLE
		beam.rotation_degrees = DIRECTIONS[direction]
		beam.scale = Vector2(beam_scale, beam_scale)
		beam.modulate = Color(1, 1, 1, 0)
		add_child(beam)
		_beams.append(beam)
		if dim != null:
			dim.set_exempt(beam)


func set_playing(playing: bool) -> void:
	_playing = playing
	if not playing:
		for beam in _beams:
			beam.modulate = Color(1, 1, 1, 0)
		_frame_index = 0
		_accumulator = 0.0


## Whether the shot is still going.
func is_playing() -> bool:
	return _playing


## Puts the shot on the gem on a rig's staff, so it comes out of the staff
## rather than out of the air.
##
## The gem sits in a different place in every view, and it moves while the
## staff is being animated, so this is worth calling every frame while the
## shot is out.  The rig may sit anywhere in the tree, so the place is worked
## out in world terms.
func anchor_to_gem(rig: Node) -> void:
	if rig == null or not rig.has_method("get_gem_position"):
		return
	var gem: Vector2 = rig.get_gem_position("staff")
	# the rig may be drawn larger than life, so the gem is put through its
	# own transform rather than simply added on
	global_position = rig.global_transform * gem
	# she is lit by her own light, not by the dim
	if dim != null and rig != _exempt_rig:
		dim.set_exempt(rig)
		_exempt_rig = rig


## Shows or hides the beams.
func show_beams(shown: bool) -> void:
	for beam in _beams:
		beam.modulate = Color(1, 1, 1, 1) if shown else Color(1, 1, 1, 0)


func _process(delta: float) -> void:
	if not _playing or _frames.is_empty():
		return
	_accumulator += delta * fps
	while _accumulator >= 1.0:
		_accumulator -= 1.0
		# the tail of the shot plays at full rate
		var step := 1
		if _frame_index < _frames.size() - full_rate_frames:
			step = maxi(1, frame_step)
		_frame_index += step
		if _frame_index >= _frames.size():
			# the shot is over
			_playing = false
			show_beams(false)
			if dim != null:
				dim.stop()
			finished.emit()
			return
	_show_frame(_frame_index)


func _show_frame(index: int) -> void:
	if _frames.is_empty():
		return
	_frame_index = clampi(index, 0, _frames.size() - 1)
	var texture := _frames[_frame_index]
	for beam in _beams:
		var material := beam.material as ShaderMaterial
		if material != null:
			material.set_shader_parameter("frame_tex", texture)
			material.set_shader_parameter("progress", float(_frame_index) / float(_frames.size()))


## Plays the shot out once.
func fire() -> void:
	_frame_index = 0
	_accumulator = 0.0
	_playing = true
	show_beams(true)
	_show_frame(0)
	if dim != null:
		dim.start()
