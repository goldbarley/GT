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
## by the knight, so it is always the size of him and always where he is,
## however the camera is placed.  The knight's own data says where his face
## is and which way he looks; the fire floats in front of his face, a little
## way off it, with its hollow open back towards him.
##
## The last of the fire is embers, and embers do not stop where they are:
## they drift, slowly, for as long as they are showing.

## The quad that blacks the screen out.
@export var dark_path: NodePath

## The rig the knight stands on.
@export var rig_path: NodePath

## How many frames the flipbook holds.
@export var frames: float = 8.0

## The knight's pixels per pixel of the master's canvas.
@export var art_scale: float = 0.05

## How far in front of his face the fire floats, in his own pixels.
@export var art_distance: float = 9.0

## -1 for the view where the knight faces the other way.
@export var mirror: float = 1.0

## How far the embers drift, in the master's pixels a second.  They rise as
## they cool, and wander sideways as they do.
@export var drift_speed = Vector2(-14.0, -52.0)

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
var _head_cache: Dictionary = {}       # where his face is, and which way he looks


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

	# All four of the knight's rigs stand in the same place, and only one of
	# them is the one you can see.  The fire belongs to the one you can see,
	# so the ones you cannot see cast no fire and darken no screen.
	var shown := _rig.is_visible_in_tree()
	visible = shown
	if _dark != null:
		_dark.visible = shown
	if not shown:
		return

	# the darkness is a quad of its own, underneath
	if _dark_material != null:
		_dark_material.set_shader_parameter("dim", _shared_dark(dim))

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

	# The fire floats in front of his face, with its hollow open back towards
	# him.  The knight's own data says where his face is and which way he
	# looks, so the fire is always where he is, and always the right way
	# round, whichever of the four views of him is on the screen.
	var face := _face()
	var looking := _looking()
	if not _has_head():
		# the knight does not say where his face is, so there is nowhere to
		# put the fire: there is no sweep, only the flame on the blade
		_material.set_shader_parameter("slash", 0.0)
		return
	var centre := face + looking * art_distance
	var at := canvas * (_rig.global_transform * centre)
	var his_face := canvas * (_rig.global_transform * face)
	# the way from the fire back to him: the hollow opens this way
	var back := his_face - at
	if back.length() < 0.001:
		back = canvas.basis_xform(_rig.global_transform.basis_xform(looking))
		if back.length() < 0.001:
			back = Vector2.UP
	back = back.normalized()
	# the hollow, as it is painted, and as it is turned for this view
	var mouth := Vector2(art_mouth().x * mirror, art_mouth().y)

	var scale := art_scale * knight_scale
	_material.set_shader_parameter("scale", scale)
	_material.set_shader_parameter("origin", at)
	_material.set_shader_parameter("rotation", back.angle() - mouth.angle())

	# the flame stays on the blade, so it has to know where the blade is
	var sword := _rig.get_piece("sword")
	if sword == null:
		return
	var blade := _blade(sword, canvas)
	_material.set_shader_parameter("blade_pos", blade["pos"])
	_material.set_shader_parameter("blade_dir", blade["dir"])
	_material.set_shader_parameter("blade_len", blade["len"])


## Where the knight's face is, in his own space, and which way he looks.
## Both come from his own data, measured from his art; see `knight_rig.py`.
func _head() -> Dictionary:
	if _head_cache.is_empty():
		var data := _rig.get_piece_data()
		_head_cache = {
			"face": data.get("face", {}),
			"facing": data.get("facing", {}),
		}
	return _head_cache


## The black, shared out between the knights that can be seen.  They all
## stand in the same place and one of them at a time is the one you can see,
## but where there is more than one of them on show, each of them darkens the
## screen a little, and each one only puts in its share of the black.
func _shared_dark(dim: float) -> float:
	var count := _visible_rigs()
	if count <= 1:
		return dim
	return 1.0 - pow(1.0 - dim, 1.0 / float(count))


## How many of the knight's rigs can be seen.  They are brothers, one for
## each way of looking at him.
func _visible_rigs() -> int:
	var parent := _rig.get_parent()
	if parent == null:
		return 1
	var count := 0
	for child in parent.get_children():
		if child is KnightModularBase and (child as Node2D).is_visible_in_tree():
			count += 1
	return maxi(count, 1)


## Whether the knight has said where his face is.
func _has_head() -> bool:
	var face: Dictionary = _head()["face"]
	return face.size() == 2


## The knight's face, in his own space: x to the right, y down, feet at the
## origin.
func _face() -> Vector2:
	var face: Dictionary = _head()["face"]
	return Vector2(float(face.get("x", 0.0)), float(face.get("y", 0.0)))


## The way the knight is looking, in his own space.
func _looking() -> Vector2:
	var facing: Dictionary = _head()["facing"]
	var looking := Vector2(float(facing.get("x", 0.0)), float(facing.get("y", 1.0)))
	if looking.length() < 0.001:
		looking = Vector2(0.0, 1.0)
	return looking.normalized()


## The way the fire's hollow opens, as it is painted on the master's canvas.
## It is read from the material, so the art and the placement can never
## disagree.
func art_mouth() -> Vector2:
	var value: Variant = _material.get_shader_parameter("art_mouth")
	if value is Vector2:
		return value
	return Vector2(-0.464, -0.886)


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
