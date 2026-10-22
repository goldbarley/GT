class_name KnightUltimateFX
extends ColorRect

## Drives Knight's Edge, the Knight's ultimate attack.
##
## The attack comes in three parts:
##
##   1. the knight raises his sword and the blade catches fire
##   2. the whole screen goes to pitch black
##   3. the fire sweeps across the dark
##
## The clip drives the timing: it sets `charge` for the flame on the blade,
## `dim` for the darkness, and `slash_t` for the sweep through the flipbook.
##
## The fire is drawn in the screen's own pixels, but it is placed and sized
## by the knight, so it is always the size of him and always where his
## sword is, however the camera is placed.  The sweep's arc turns about the
## shoulder the sword swings on, and its radius is the blade's reach, so the
## fire is always the line the blade drew.
##
## The last of the fire is embers, and embers do not stop where they are:
## they drift, slowly, for as long as they are showing.

## The quad that blacks the screen out.
@export var dark_path: NodePath

## The rig the knight stands on.
@export var rig_path: NodePath

## How many frames the flipbook holds.
@export var frames: float = 8.0

## Where the fire sits, in the knight's own pixels, from his shoulder.
@export var arc_centre_offset = Vector2.ZERO

## The knight's pixels per pixel of the master's canvas.
@export var arc_scale: float = 0.05

## -1 for the view where the knight faces the other way.
@export var mirror: float = 1.0

## How far the embers drift, in the master's pixels a second.  They rise as
## they cool, and wander sideways as they do.
@export var drift_speed = Vector2(-14.0, 52.0)

## How far each ember wanders on its own course, in the master's pixels.
@export var drift_wander: float = 34.0

var _rig: KnightModularBase = null
var _dark: ColorRect = null
var _material: ShaderMaterial = null
var _dark_material: ShaderMaterial = null
var _time: float = 0.0                # the clock the flame flickers on
var _drift: Vector2 = Vector2.ZERO     # how far the embers have drifted
var _tip: Vector2 = Vector2.ZERO       # the blade's tip, from the sword's pivot
var _tip_found: bool = false
var _last_index: float = 0.0            # the frame the sweep was on


func _ready() -> void:
	_material = material as ShaderMaterial
	if dark_path != NodePath():
		_dark = get_node_or_null(dark_path) as ColorRect
		if _dark != null:
			_dark_material = _dark.material as ShaderMaterial
	if rig_path != NodePath():
		_rig = get_node_or_null(rig_path) as KnightModularBase
	if _rig == null:
		# the rig is the ancestor of the layer this quad sits in
		var node := get_parent()
		while node != null:
			if node is KnightModularBase:
				_rig = node as KnightModularBase
				break
			node = node.get_parent()
	# run after the choreography player, so the sword is already posed
	process_priority = 10
	set_process(_rig != null and _material != null)


func _process(delta: float) -> void:
	if _rig == null or _material == null:
		return
	_time += delta

	var charge := _number("charge")
	var dim := _number("dim")
	var slash_t := _number("slash_t")
	var slash := _number("slash")

	# the darkness is a quad of its own, underneath
	if _dark_material != null:
		_dark_material.set_shader_parameter("dim", dim)

	# the sweep plays through the flipbook, one frame at a time
	var index: float = floor(clamp(slash_t * frames, 0.0, frames - 1.0))
	_material.set_shader_parameter("frame", index)
	_material.set_shader_parameter("slash", slash)

	# The embers drift, slowly, for as long as they are showing.  They are
	# the last of the fire, so they only start to float once the sweep has
	# burnt down to nothing but embers.  They keep floating after the sweep
	# is done, so the last of the fire hangs in the air until the dark lifts.
	var embers: float = clamp((index - 5.0) / 1.0, 0.0, 1.0)
	if index < _last_index:
		# the sweep is starting over, so the embers start from nothing
		_drift = Vector2.ZERO
	if slash > 0.001:
		# the drift only runs while there is fire to drift
		_drift += drift_speed * delta * embers
	_last_index = index
	_material.set_shader_parameter("drift", _drift)
	_material.set_shader_parameter("drift_mix", embers)
	_material.set_shader_parameter("drift_time", _time)
	_material.set_shader_parameter("time_seconds", _time)
	_material.set_shader_parameter("mirror", mirror)

	# The screen, in its own pixels.  The quad covers all of it, so its own
	# UV runs from one corner to the other.
	var size := get_viewport().get_visible_rect().size
	_material.set_shader_parameter("screen_size", size)

	# where the knight is on the screen, and how big he is there
	var canvas := get_viewport().get_canvas_transform()
	# how big the knight is on the screen: his own scale, then the camera's
	var knight_scale := canvas.basis_xform(
		_rig.global_transform.basis_xform(Vector2(1.0, 0.0))
	).length()

	# where the sweep turns about, and how big it is
	var shoulder := _shoulder()
	var at := canvas * (_rig.global_transform * shoulder)
	# and it sits a little way in front of him
	var front := canvas.basis_xform(
		_rig.global_transform.basis_xform(Vector2(arc_centre_offset.x, arc_centre_offset.y))
	)
	var scale := arc_scale * knight_scale
	_material.set_shader_parameter("scale", scale)
	_material.set_shader_parameter("origin", at + front - art_centre() * scale)

	# the flame stays on the blade, so it has to know where the blade is
	var sword := _rig.get_piece("sword")
	if sword == null:
		return
	var blade := _blade(sword, canvas)
	_material.set_shader_parameter("blade_pos", blade["pos"])
	_material.set_shader_parameter("blade_dir", blade["dir"])
	_material.set_shader_parameter("blade_len", blade["len"])


## The arc's centre on the canvas the art is painted on, measured from the
## frames.  It is read from the material, so the art and the placement can
## never disagree.
func art_centre() -> Vector2:
	var value: Variant = _material.get_shader_parameter("art_centre")
	if value is Vector2:
		return value
	return Vector2(484.6, 305.6)


## Where the knight's shoulder is, in his own space.  The sweep turns about
## it, the same way the sword swings about it.
func _shoulder() -> Vector2:
	var arm := _rig.get_piece("arm")
	if arm != null:
		return arm.position
	# the left view has no arm of its own, so the sword turns about its grip
	var sword := _rig.get_piece("sword")
	return sword.position if sword != null else Vector2.ZERO


## Where the sword's tip is on the screen, which way the blade points, and
## how long it is there.
func _blade(sword: Sprite2D, canvas: Transform2D) -> Dictionary:
	# the tip of the blade, found in the sword's own pixels
	if not _tip_found:
		_tip = _find_tip(sword)
		_tip_found = true

	var radians := sword.rotation
	var turned := Vector2(
		_tip.x * cos(radians) - _tip.y * sin(radians),
		_tip.x * sin(radians) + _tip.y * cos(radians)
	)
	var tip := sword.position + turned
	var direction := tip - sword.position
	var length := direction.length()
	if length > 0.001:
		direction /= length
	# into the screen's own pixels
	return {
		"pos": canvas * (_rig.global_transform * sword.position),
		"dir": canvas.basis_xform(direction).normalized(),
		"len": length * canvas.basis_xform(Vector2(1.0, 0.0)).length(),
	}


## The tip of the blade, in the sword's own pixels, measured from its pivot.
## It is found in the art rather than written down by hand, so it is right
## however the sword is drawn.
func _find_tip(sword: Sprite2D) -> Vector2:
	if sword.texture == null:
		return Vector2.ZERO
	var image := sword.texture.get_image()
	if image == null:
		return Vector2.ZERO
	var region := sword.region_rect
	var pivot: Vector2 = sword.get_meta("pivot", Vector2.ZERO)
	var best := Vector2.ZERO
	var best_distance := -1.0
	for y in range(int(region.position.y), int(region.end.y)):
		for x in range(int(region.position.x), int(region.end.x)):
			if image.get_pixel(x, y).a <= 0.4:
				continue
			var offset := Vector2(x - region.position.x - pivot.x, y - region.position.y - pivot.y)
			var distance := offset.length()
			if distance > best_distance:
				best_distance = distance
				best = offset
	return best


## A number the clip has set, or nothing if it has not set it yet.
func _number(name: String) -> float:
	var value: Variant = _material.get_shader_parameter(name)
	if value is float or value is int:
		return float(value)
	return 0.0
