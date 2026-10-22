class_name ChoreoPlayer
extends Node

## Runtime player for modular Mage choreography clips.
##
## A clip is a JSON file with a list of keyframed poses. Each pose names a
## *role* (a piece such as "staff" or "hat") or a *group* (several pieces moved
## together) and gives it a rotation in degrees plus a pixel offset.
##
## The mage pieces are flat siblings rather than a node hierarchy, so groups
## exist to move several pieces rigidly about a shared pivot. Group definitions
## live in each perspective's `pieces.json` because the pivot depends on that
## perspective's layout; clips stay perspective agnostic and only refer to group
## names.
##
## A clip file looks like this:
##
##     {
##       "clip": "idle",
##       "fps": 8,
##       "loop": true,
##       "duration": 2.0,
##       "keys": [
##         { "time": 0.0, "ease": "in_out", "poses": {} },
##         { "time": 1.0, "ease": "in_out", "poses": {
##             "torso": { "rot": 0.0, "pos": { "x": 0, "y": -1 } },
##             "hat":  { "rot": -1.5 },
##             "staff":{ "rot": 2.5 }
##         } }
##       ]
##     }
##
## "ease" on a key describes the transition from that key to the next one. A
## pose that is not mentioned in a key returns to rest, so clips only ever list
## what is actually changing.
##
## A clip may override its keys per perspective with a "perspectives" block:
##
##     "perspectives": { "front": { "keys": [ ... ] }, "right": { "keys": [ ... ] } }

## Emitted when the clip asks the camera to shake. The amount is the strength.
signal camera_shake_requested(amount: float)
signal clip_started(clip_name: String)
signal clip_impact(clip_name: String)
signal clip_finished(clip_name: String)
signal frame_changed(frame: int, total_frames: int)
signal pose_applied(t: float)

@export var target: ModularRig
@export var clips_directory: String = "res://assets/characters/Mage/anim/clips"
@export var playback_speed: float = 1.0
@export var autoplay: String = ""
@export var loop: bool = true

## Use smooth filtering on a piece while it is turning, so the movement reads as
## a continuous turn instead of a stutter.
@export var smooth_rotation: bool = true

## How far a piece has to turn before it is filtered smoothly, in degrees.
@export var smooth_rotation_threshold: float = 4.0

var clip_data: Dictionary = {}
var current_clip: String = ""
var is_playing: bool = false
var elapsed: float = 0.0
var manual_scrub: bool = false
var scrub_value: float = 0.0

var _keys: Array = []
var _duration: float = 0.0
var _fps: float = 8.0
var _loop: bool = true
var _groups: Dictionary = {}
var _roles: Dictionary = {}
var _rest: Dictionary = {}          # piece name -> { pos: Vector2, rot: float }
var _role_to_piece: Dictionary = {} # role -> piece name
var _parent_of: Dictionary = {}     # piece name -> parent piece name
var _children_of: Dictionary = {}   # piece name -> Array of piece names
var _order: Array = []              # piece names, parents before children
var _fx_node: Node = null           # the node the clip's "fx" block drives
var _fx_spawn_node: Node = null     # the node the clip's "fx" block can set off
var _fx_dim_node: Node = null       # the node the clip's "fx" block can darken with
var _fx_spawned: bool = false       # whether it has been set off this time
var _fx_clip_material: ShaderMaterial = null  # the material that clips the character
var _clip_drives_character: bool = false    # does this clip cut the character itself
var _clip_linger: float = 0.0       # how long the current clip's effect outlives it
var _linger_node: Node = null       # the effect that is burning out
var _linger_duration: float = 0.0   # how long that burn-out lasts
var _linger_elapsed: float = -1.0   # seconds since that effect ended, -1 when not lingering
var _smooth_pieces: Dictionary = {}  # pieces that turn far enough to need smooth filtering
var _interpolation: String = "smooth"  # "smooth" carries through the keys, "eased" stops at them
var _impact_time: float = -1.0   # when the clip hits, -1 when it has no impact
var _impact_done: bool = false
var _rest_target_pos: Vector2 = Vector2.ZERO   # where the mage stands at rest
var _root_offset: Vector2 = Vector2.ZERO      # the jump and the flight
var _root_rotation: float = 0.0
var _shake: float = 0.0                      # how much the mage is shaking
var _camera_shake: float = 0.0               # how much the camera is asked to shake


func _ready() -> void:
	if target == null:
		target = get_parent() as MageModularBase
	if target == null:
		push_error("MageChoreoPlayer: no target mage assigned")
		set_process(false)
		return
	_cache_rig()
	if autoplay != "":
		play(autoplay)


# --------------------------------------------------------------------------- #
# rig introspection
# --------------------------------------------------------------------------- #
func _cache_rig() -> void:
	_rest.clear()
	_role_to_piece.clear()

	# the target may not have run its own _ready() yet if the player is a child
	# of the mage, so make sure the piece registry is populated
	if target.original_positions.is_empty():
		target._register_child_pieces()

	for piece_name in target.original_positions.keys():
		var sprite: Sprite2D = target.pieces.get(piece_name)
		if sprite == null:
			continue
		_rest[piece_name] = {
			"pos": target.original_positions[piece_name],
			"rot": target.original_rotations.get(piece_name, 0.0),
		}

	_rest_target_pos = target.position

	var data: Dictionary = target.get_piece_data()
	_roles = data.get("roles", {})
	_groups = data.get("groups", {})

	# role -> concrete piece name
	for role in _roles.keys():
		var piece_name: String = str(_roles[role])
		if target.get_piece(piece_name) != null:
			_role_to_piece[role] = piece_name

	_build_hierarchy(data)



## Works out which piece rides which, and the order they have to be evaluated
## in. A piece may declare a "parent" in pieces.json, which means it is held by
## that piece - the staff is held by the arm, so raising the arm carries the
## staff with it while the staff can still rotate about the grip.
func _build_hierarchy(data: Dictionary) -> void:
	_parent_of.clear()
	_children_of.clear()
	_order.clear()

	var raw: Dictionary = data.get("piece_parents", {})
	for role in raw.keys():
		if not _role_to_piece.has(role):
			continue
		var child: String = str(_role_to_piece[role])
		var parent_role: String = str(raw[role])
		if not _role_to_piece.has(parent_role):
			continue
		var parent: String = str(_role_to_piece[parent_role])
		if child == parent:
			continue
		_parent_of[child] = parent
		if not _children_of.has(parent):
			_children_of[parent] = []
		_children_of[parent].append(child)

	# parents always come before their children
	var visited: Dictionary = {}
	for piece_name in _role_to_piece.values():
		_visit_hierarchy(str(piece_name), visited)


func _visit_hierarchy(piece_name: String, visited: Dictionary) -> void:
	if visited.has(piece_name):
		return
	visited[piece_name] = true
	if _parent_of.has(piece_name):
		_visit_hierarchy(str(_parent_of[piece_name]), visited)
	_order.append(piece_name)


## The piece and everything it carries.
func _subtree(piece_name: String) -> Array:
	var out: Array = [piece_name]
	for child in _children_of.get(piece_name, []):
		out.append_array(_subtree(str(child)))
	return out


## Depth first search for a node by name, used to reach effect nodes that are
## not direct children of the mage.
func _find_node(from_node: Node, node_name: String) -> Node:
	for child in from_node.get_children():
		if child.name == node_name:
			return child
		var found := _find_node(child, node_name)
		if found != null:
			return found
	return null


## Resolves a pose target (role or group or raw piece name) to a piece name.
func _resolve_piece(key: String) -> String:
	if _role_to_piece.has(key):
		return _role_to_piece[key]
	if target.get_piece(key) != null:
		return key
	return ""


# --------------------------------------------------------------------------- #
# clip loading
# --------------------------------------------------------------------------- #
## Lists the clip names available in the clips directory.
func get_available_clips() -> Array[String]:
	var found: Array[String] = []
	if not DirAccess.dir_exists_absolute(clips_directory):
		return found
	for file in DirAccess.get_files_at(clips_directory):
		if file.ends_with(".json"):
			found.append(file.get_basename())
	found.sort()
	return found


## Loads a clip by name (without the .json extension).
func load_clip(clip_name: String) -> bool:
	var path := "%s/%s.json" % [clips_directory, clip_name]
	if not FileAccess.file_exists(path):
		push_error("MageChoreoPlayer: clip not found: " + path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("MageChoreoPlayer: malformed clip: " + path)
		return false
	clip_data = parsed
	_apply_clip_metadata()
	return true


func _apply_clip_metadata() -> void:
	_impact_time = float(clip_data.get("impact", -1.0))
	_impact_done = false
	_keys = []
	_duration = 0.0
	_fps = float(clip_data.get("fps", 8.0))
	_loop = bool(clip_data.get("loop", loop))
	# How long this clip's own effect outlives it.  The burn-out that is
	# already running belongs to an earlier effect and is left alone: the
	# character goes back to standing still the moment a cast is over, and
	# the pit of fire still has to go out.
	_clip_linger = float(clip_data.get("linger", 0.0))
	_interpolation = str(clip_data.get("interpolation", "smooth"))

	# a per-perspective override wins over the shared key list
	var source: Dictionary = clip_data
	var per_perspective: Dictionary = clip_data.get("perspectives", {})
	if per_perspective.has(target.perspective_name):
		source = per_perspective[target.perspective_name]

	for k in source.get("keys", []):
		_keys.append(k)
	_keys.sort_custom(func(a, b): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))

	if clip_data.has("duration"):
		_duration = float(clip_data["duration"])
	elif _keys.size() > 0:
		_duration = float(_keys[_keys.size() - 1].get("time", 0.0))
	if _duration <= 0.0:
		_duration = 1.0

	_find_turning_pieces()
	_update_filters()

	# resolve the effect node the clip's "fx" block drives
	_fx_node = null
	_fx_spawn_node = null
	_fx_dim_node = null
	_fx_spawned = false
	_fx_clip_material = null
	_clip_drives_character = false
	var fx_block: Dictionary = clip_data.get("fx", {})
	if fx_block.has("node") and target != null:
		_fx_node = target.get_node_or_null(str(fx_block["node"]))
		if _fx_node == null:
			_fx_node = _find_node(target, str(fx_block["node"]))
	# The character pieces share one material, and the clip shader on it
	# measures everything in the mage's own space. That matrix has to be kept
	# up to date for every clip, even the ones that do not cut the character,
	# otherwise the shader falls back to world space and dissolves the mage
	# whenever she stands far from the origin.
	if target != null:
		for piece_name in target.pieces.keys():
			var piece: Sprite2D = target.pieces[piece_name]
			if piece != null and piece.material is ShaderMaterial:
				_fx_clip_material = piece.material as ShaderMaterial
				break
	# "clip": true means the effect's parameters also reach the character
	# material.  The teleport cuts her with it, the fireball lights her with
	# it, so the flag is about the character and the effect talking to each
	# other, not only about cutting.
	_clip_drives_character = fx_block.get("clip", false)
	# A clip may also name a node to set off, for an effect that is a thing
	# in the world rather than something drawn on the character.
	var spawn_name := str(fx_block.get("spawn", ""))
	if spawn_name != "" and target != null:
		_fx_spawn_node = target.get_node_or_null(spawn_name)
		if _fx_spawn_node == null:
			_fx_spawn_node = _find_node(target, spawn_name)
	# A clip may also name a node to darken the screen with, for a spell
	# that takes the light out of the world while it is charging up.
	var dim_name := str(fx_block.get("dim", ""))
	if dim_name != "" and target != null:
		_fx_dim_node = target.get_node_or_null(dim_name)
		if _fx_dim_node == null:
			_fx_dim_node = _find_node(target, dim_name)


# --------------------------------------------------------------------------- #
# transport
# --------------------------------------------------------------------------- #
func play(clip_name: String) -> void:
	if not load_clip(clip_name):
		return
	current_clip = clip_name
	elapsed = 0.0
	manual_scrub = false
	_impact_done = false
	# A clip that brings an effect of its own replaces whatever was burning
	# out.  A clip without one leaves it alone: the pit of fire keeps
	# burning while the mage walks away.
	if _clip_linger > 0.0:
		_linger_node = null
		_linger_duration = 0.0
		_linger_elapsed = -1.0
	is_playing = true
	evaluate(0.0)
	clip_started.emit(clip_name)


func stop() -> void:
	is_playing = false
	elapsed = 0.0
	# an effect whose cast is cut short still has to go out
	_begin_linger()
	reset_to_rest()


## Sets how fast the clip plays.  1.0 is normal, 0.25 is slow motion and 0
## freezes the clip where it is.  The change takes hold straight away, so a
## cast can be slowed down while it is playing.
func set_playback_speed(speed: float) -> void:
	playback_speed = maxf(0.0, speed)


## How fast the clip is playing.
func get_playback_speed() -> float:
	return playback_speed


func get_progress() -> float:
	if _duration <= 0.0:
		return 0.0
	return clampf(elapsed / _duration, 0.0, 1.0)


func get_frame_count() -> int:
	return maxi(1, int(round(_duration * _fps)))


func get_current_frame() -> int:
	return clampi(int(floor(get_progress() * get_frame_count())) + 1, 1, get_frame_count())


## Scrubs to an absolute progress value in the 0..1 range.
##
## By default this stops the clip, the way a scrub bar on a stopped clip
## behaves.  With `keep_playing` the clip carries straight on from the new
## spot, which is what a game wants when the player is seeking through a
## cast that is already running.
func scrub(progress: float, keep_playing: bool = false) -> void:
	scrub_value = clampf(progress, 0.0, 1.0)
	elapsed = scrub_value * _duration
	if keep_playing:
		manual_scrub = false
		is_playing = true
	else:
		manual_scrub = true
		is_playing = false
	evaluate(elapsed)


## Scrubs to a progress value expressed in the 0..100 range (slider friendly).
func scrub_percent(percent: float, keep_playing: bool = false) -> void:
	scrub(percent / 100.0, keep_playing)

## Scrubs to an absolute time in seconds. `scrub` takes a 0..1 fraction of the
## clip, which is easy to confuse with a time.
func scrub_time(seconds: float) -> void:
	scrub(seconds / _duration if _duration > 0.0 else 0.0)


## Jumps to a 1-based frame index.
func jump_to_frame(frame_num: int) -> void:
	var total := get_frame_count()
	var index := clampi(frame_num - 1, 0, total - 1)
	scrub(float(index) / float(total))


## The length of the active clip in seconds.
func get_duration() -> float:
	return _duration


## Returns every key time of the active clip, for authoring a scrub bar.
func get_key_times() -> Array[float]:
	var times: Array[float] = []
	for k in _keys:
		times.append(float(k.get("time", 0.0)))
	return times


func _process(delta: float) -> void:
	if manual_scrub:
		return

	if is_playing:
		elapsed += delta * playback_speed
		if _loop:
			elapsed = fposmod(elapsed, _duration)
		else:
			elapsed = minf(elapsed, _duration)
			if elapsed >= _duration:
				is_playing = false
				clip_finished.emit(current_clip)
				# an effect can outlive the clip, a pit of fire keeps burning
				_begin_linger()
		evaluate(elapsed)

	# The burn-out of an effect that outlived its clip runs on whatever the
	# character is doing, so the pit of fire goes out even while she is
	# walking away.
	_advance_linger(delta)


## Starts the burn-out of the clip's own effect, so an effect that outlives
## its clip fades away on its own instead of staying on the screen for good.
func _begin_linger() -> void:
	if _clip_linger <= 0.0 or _fx_node == null:
		return
	_linger_node = _fx_node
	_linger_duration = _clip_linger
	_linger_elapsed = 0.0
	# the clip says how long the effect burns for, so the shader is told the
	# same and the two cannot drift apart
	var material := _fx_node.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("linger_duration", _clip_linger)


## Counts the burn-out of an effect that outlived its clip.  It runs on
## whatever the character is doing, so the fire goes out even while she is
## walking away.
func _advance_linger(delta: float) -> void:
	if _linger_node == null or _linger_elapsed < 0.0:
		return
	if _linger_elapsed >= _linger_duration:
		return
	_linger_elapsed += delta * playback_speed
	apply_fx_linger(_linger_elapsed)


# --------------------------------------------------------------------------- #
# evaluation
# --------------------------------------------------------------------------- #
## Evaluates the clip at time `t` (seconds) and applies it to the rig.
func evaluate(t: float) -> void:
	if _keys.is_empty():
		return
	# the shake has to be read before the pose is written, because the pose
	# is what actually moves the mage
	var fx := sample_fx(t)
	_read_shake(fx)
	var pose := sample(t)
	apply_pose(pose)
	apply_fx(fx)
	# the moment the clip lands, if it says when that is
	if _impact_time >= 0.0 and not _impact_done and t >= _impact_time:
		_impact_done = true
		clip_impact.emit(current_clip)
	pose_applied.emit(t)
	frame_changed.emit(get_current_frame(), get_frame_count())


## Picks up the shake amounts a clip asks for.
func _read_shake(params: Dictionary) -> void:
	_shake = float(params.get("shake", _shake))
	_camera_shake = float(params.get("camera_shake", _camera_shake))
	if _camera_shake > 0.0:
		camera_shake_requested.emit(_camera_shake)


## Samples the clip's effect parameters at time `t`.
## A clip may carry an "fx" block naming a node under the target and the
## shader parameters to drive. Per key "fx" dictionaries are interpolated the
## same way poses are, so the effect moves continuously as well.
func sample_fx(t: float) -> Dictionary:
	if _interpolation != "eased":
		return _sample_fx_smooth(t)
	var result: Dictionary = {}
	if _keys.is_empty():
		return result

	var index := 0
	for i in range(_keys.size()):
		if float(_keys[i].get("time", 0.0)) <= t:
			index = i
		else:
			break
	var k0: Dictionary = _keys[index]
	var k1: Dictionary = _keys[mini(index + 1, _keys.size() - 1)]

	var t0 := float(k0.get("time", 0.0))
	var t1 := float(k1.get("time", 0.0))
	var p := 0.0
	if t1 > t0:
		p = clampf((t - t0) / (t1 - t0), 0.0, 1.0)
	p = _ease(p, str(k0.get("ease", "linear")))

	var fx0: Dictionary = k0.get("fx", {})
	var fx1: Dictionary = k1.get("fx", {})
	for key in fx0.keys():
		result[key] = _lerp_fx(fx0[key], fx1.get(key, fx0[key]), p)
	for key in fx1.keys():
		if not result.has(key):
			result[key] = _lerp_fx(fx0.get(key, fx1[key]), fx1[key], p)
	return result


## Interpolates an effect parameter. Numbers blend as numbers, positions blend
## as vectors so a moving spawn point can be animated too.
func _lerp_fx(a, b, p: float) -> Variant:
	if (a is Dictionary or a is Array) and (b is Dictionary or b is Array):
		return _to_vec(a).lerp(_to_vec(b), p)
	return lerpf(float(a), float(b), p)


## Converts a clip value into something a shader uniform can take. Positions
## may be written as {"x":..,"y":..} or [x, y] in the clip and end up as a
## Vector2 in the shader.
static func _as_uniform(value) -> Variant:
	if value is Dictionary and value.has("x") and value.has("y"):
		return Vector2(float(value["x"]), float(value["y"]))
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return value


## Works out which pieces the clip turns far enough that they need smooth
## filtering. A piece that only nudges is left crisp.
func _find_turning_pieces() -> void:
	_smooth_pieces.clear()
	if not smooth_rotation:
		return
	var biggest: Dictionary = {}
	for key in _keys:
		var poses: Dictionary = key.get("poses", {})
		for role in poses.keys():
			var piece_name := _resolve_piece(str(role))
			if piece_name == "":
				continue
			var amount := absf(float(poses[role].get("rot", 0.0)))
			if amount > float(biggest.get(piece_name, 0.0)):
				biggest[piece_name] = amount
	for piece_name in biggest.keys():
		if float(biggest[piece_name]) >= smooth_rotation_threshold:
			_smooth_pieces[piece_name] = true


## Dismisses the effect the clip drives, if it knows how to dismiss itself.
## Used by effects that stay up after the clip has finished, like the energy
## barrier.
func dismiss_effect() -> bool:
	if _fx_node == null:
		return false
	if _fx_node.has_method("dismiss"):
		_fx_node.call("dismiss")
		return true
	return false


## Brings the effect back if it was dismissed.
func restore_effect() -> bool:
	if _fx_node == null:
		return false
	if _fx_node.has_method("restore"):
		_fx_node.call("restore")
		return true
	return false


## Samples the effect parameters as a smooth curve through the keys.
func _sample_fx_smooth(t: float) -> Dictionary:
	var result: Dictionary = {}
	if _keys.is_empty():
		return result

	var order: Array = []
	for key in _keys:
		for param in key.get("fx", {}).keys():
			if not order.has(param):
				order.append(param)

	for param in order:
		var curve: Array = []
		for key in _keys:
			var kt := float(key.get("time", 0.0))
			var value: Variant = key.get("fx", {}).get(param, 0.0)
			if value is Dictionary or value is Array:
				curve.append([kt, _to_vec(value)])
			else:
				curve.append([kt, float(value)])
		if curve[0][1] is Vector2:
			var xs: Array = []
			var ys: Array = []
			for point in curve:
				xs.append([point[0], point[1].x])
				ys.append([point[0], point[1].y])
			result[param] = Vector2(_curve_value(xs, t), _curve_value(ys, t))
		else:
			result[param] = _curve_value(curve, t)
	return result


## Pushes the linger time to the effect, so it can burn out on its own once the
## clip has finished.
##
## The time goes to the effect that is burning out, not to the effect of
## whatever clip happens to be playing now.
func apply_fx_linger(t: float) -> void:
	var node: Node = _linger_node if _linger_node != null else _fx_node
	if node == null:
		return
	var material: ShaderMaterial = node.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("linger", t)


## Sets off the node the clip's "fx" block names, once, when the clip says
## so.  The "spawn" parameter in the clip's keys goes from nothing to
## something at the moment the effect should start.
func _apply_fx_spawn(params: Dictionary) -> void:
	if _fx_spawn_node == null or _fx_spawned:
		return
	if not params.has("spawn"):
		return
	var value: Variant = _as_uniform(params["spawn"])
	if float(value) <= 0.0:
		return
	_fx_spawned = true
	if _fx_spawn_node.has_method("fire"):
		_fx_spawn_node.call("fire")


## Darkens the screen with the node the clip's "fx" block names, if there is
## one.  The "dim" parameter in the clip's keys goes from nothing to
## something over the wind up.
func _apply_fx_dim(params: Dictionary) -> void:
	if _fx_dim_node == null or not params.has("dim"):
		return
	var value: Variant = _as_uniform(params["dim"])
	if _fx_dim_node.has_method("set_dim"):
		_fx_dim_node.call("set_dim", float(value))


## Pushes the sampled effect parameters into the shaders that drive the effect.
func apply_fx(params: Dictionary) -> void:
	_apply_fx_spawn(params)
	_apply_fx_dim(params)
	if _fx_clip_material != null:
		# the character clip works in the mage's own space, so the cut stays
		# correct wherever the mage is placed or how far it is scaled
		_fx_clip_material.set_shader_parameter("to_local", _to_local_matrix())
		# the gem's place in her own space, so a spell that is charging up
		# can light her from the staff
		_fx_clip_material.set_shader_parameter("gem_pos", target.get_gem_position())
	if params.is_empty():
		return
	if _fx_node != null:
		var material: ShaderMaterial = _fx_node.material as ShaderMaterial
		if material != null:
			for key in params.keys():
				material.set_shader_parameter(str(key), _as_uniform(params[key]))
	if _fx_clip_material != null and _clip_drives_character:
		for key in params.keys():
			_fx_clip_material.set_shader_parameter(str(key), params[key])


## The inverse of the mage's global transform, used to measure the cut in the
## mage's local space.
func _to_local_matrix() -> Transform2D:
	if target == null or not target.is_inside_tree():
		return Transform2D.IDENTITY
	return target.get_global_transform().affine_inverse()


## Samples the clip at time `t` and returns { target: { rot: float, pos: Vector2 } }.
##
## A clip is sampled with a smooth curve by default, so the motion carries on
## straight through a key instead of easing to a stop at it. A clip can ask for
## the old stepped behaviour with "interpolation": "eased".
func sample(t: float) -> Dictionary:
	if _interpolation == "eased":
		return _sample_eased(t)
	return _sample_smooth(t)


## Samples a clip as a smooth curve through its keys.
##
## Every animated value gets a Hermite curve whose tangents are taken from the
## neighbouring keys, so the velocity is continuous across a key. That is what
## stops the motion from pausing on every frame of the drawing.
func _sample_smooth(t: float) -> Dictionary:
	var result: Dictionary = {}
	if _keys.is_empty():
		return result

	# every target gets a curve that spans the whole clip. A target that is
	# not mentioned in a key is at rest in that key, exactly as it would be in
	# the stepped sampler.
	var order: Array = []
	for key in _keys:
		for target in key.get("poses", {}).keys():
			if not order.has(target):
				order.append(target)

	var curves: Dictionary = {}
	for target in order:
		var curve: Dictionary = {"rot": [], "pos_x": [], "pos_y": [], "alpha": []}
		for key in _keys:
			var kt := float(key.get("time", 0.0))
			var value: Dictionary = key.get("poses", {}).get(target, {})
			var pos := _to_vec(value.get("pos", Vector2.ZERO))
			curve["rot"].append([kt, float(value.get("rot", 0.0))])
			curve["pos_x"].append([kt, pos.x])
			curve["pos_y"].append([kt, pos.y])
			curve["alpha"].append([kt, float(value.get("alpha", 1.0))])
		curves[target] = curve

	for target in order:
		var c: Dictionary = curves[target]
		result[target] = {
			"rot": _curve_value(c["rot"], t),
			"pos": Vector2(_curve_value(c["pos_x"], t), _curve_value(c["pos_y"], t)),
			"alpha": _curve_value(c["alpha"], t),
		}
	return result


## Evaluates a Hermite curve through a set of [time, value] points.
static func _curve_value(points: Array, t: float) -> float:
	var count := points.size()
	if count == 0:
		return 0.0
	if count == 1:
		return float(points[0][1])
	if t <= float(points[0][0]):
		return float(points[0][1])
	if t >= float(points[count - 1][0]):
		return float(points[count - 1][1])

	var i := 0
	for k in range(count - 1):
		if float(points[k][0]) <= t and t <= float(points[k + 1][0]):
			i = k
			break

	var t0 := float(points[i][0])
	var t1 := float(points[i + 1][0])
	var v0 := float(points[i][1])
	var v1 := float(points[i + 1][1])
	var h := t1 - t0
	if h <= 0.0:
		return v1
	var s := (t - t0) / h
	var m0 := _curve_tangent(points, i)
	var m1 := _curve_tangent(points, i + 1)
	var s2 := s * s
	var s3 := s2 * s
	return (2.0 * s3 - 3.0 * s2 + 1.0) * v0 \
		+ (s3 - 2.0 * s2 + s) * h * m0 \
		+ (-2.0 * s3 + 3.0 * s2) * v1 \
		+ (s3 - s2) * h * m1


## The slope of a curve at a point, taken from its neighbours. It is clamped so
## the curve cannot overshoot and turn back on itself.
static func _curve_tangent(points: Array, i: int) -> float:
	var count := points.size()
	var m := 0.0
	# the slope of the segment on each side of this point
	var before := 0.0
	var after := 0.0
	if i > 0:
		before = (float(points[i][1]) - float(points[i - 1][1])) / maxf(float(points[i][0]) - float(points[i - 1][0]), 0.0001)
	if i < count - 1:
		after = (float(points[i + 1][1]) - float(points[i][1])) / maxf(float(points[i + 1][0]) - float(points[i][0]), 0.0001)
	if i == 0:
		m = after
	elif i == count - 1:
		m = before
	else:
		m = (float(points[i + 1][1]) - float(points[i - 1][1])) / maxf(float(points[i + 1][0]) - float(points[i - 1][0]), 0.0001)

	# keep the curve from overshooting the value it is heading for
	var delta := after if i < count - 1 else before
	if delta != 0.0:
		var ratio := m / delta
		if ratio < 0.0:
			m = 0.0
		elif ratio > 3.0:
			m = 3.0 * delta

	# A value that holds still has to stay still.  The tangent at the end of a
	# flat segment is flat as well, otherwise the curve swings past the value
	# it is holding and has to come back to it: a fireball that is meant to
	# land on the ground would sail past it first.
	if (i > 0 and before == 0.0) or (i < count - 1 and after == 0.0):
		m = 0.0
	return m


## Samples the clip the old way, easing to a stop at every key.
func _sample_eased(t: float) -> Dictionary:
	var result: Dictionary = {}
	if _keys.is_empty():
		return result

	var index := 0
	for i in range(_keys.size()):
		if float(_keys[i].get("time", 0.0)) <= t:
			index = i
		else:
			break
	var k0: Dictionary = _keys[index]
	var k1: Dictionary = _keys[mini(index + 1, _keys.size() - 1)]

	var t0 := float(k0.get("time", 0.0))
	var t1 := float(k1.get("time", 0.0))
	var p := 0.0
	if t1 > t0:
		p = clampf((t - t0) / (t1 - t0), 0.0, 1.0)
	p = _ease(p, str(k0.get("ease", "linear")))

	var poses0: Dictionary = k0.get("poses", {})
	var poses1: Dictionary = k1.get("poses", {})

	# every target mentioned in either key has to be produced
	var targets: Array = []
	for key in poses0.keys():
		if not targets.has(key):
			targets.append(key)
	for key in poses1.keys():
		if not targets.has(key):
			targets.append(key)

	for target_key in targets:
		var a: Dictionary = _pose_value(poses0, target_key)
		var b: Dictionary = _pose_value(poses1, target_key)
		result[target_key] = {
			"rot": lerpf(float(a.get("rot", 0.0)), float(b.get("rot", 0.0)), p),
			"pos": a.get("pos", Vector2.ZERO).lerp(b.get("pos", Vector2.ZERO), p),
			"alpha": lerpf(float(a.get("alpha", 1.0)), float(b.get("alpha", 1.0)), p),
		}
	return result


## A target that is absent from a key is at rest.
func _pose_value(poses: Dictionary, key: String) -> Dictionary:
	if poses.has(key):
		var raw: Dictionary = poses[key]
		return {
			"rot": float(raw.get("rot", 0.0)),
			"pos": _to_vec(raw.get("pos", Vector2.ZERO)),
			"alpha": float(raw.get("alpha", 1.0)),
		}
	return {"rot": 0.0, "pos": Vector2.ZERO, "alpha": 1.0}


## Accepts an offset written as {"x":..,"y":..}, [x, y] or a plain Vector2.
static func _to_vec(value) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


## Writes a sampled pose onto the rig.
##
## Transforms compose rather than override, in three layers:
##
##   1. a piece's own pose, which rotates it about its own pivot
##   2. the group it belongs to, which carries it rigidly about the group pivot
##   3. the piece it is held by, so raising the arm carries the staff
##
## That is what keeps the hat attached to the body (the torso group carries it
## while the hat can still tilt on its neck pivot) and what lets the staff stay
## in the hand while the arm moves.
func apply_pose(pose: Dictionary) -> void:
	# start from the authored rest pose so nothing survives from a previous clip
	reset_to_rest()

	# --- 1. each piece's own pose -----------------------------------------
	var local_rot: Dictionary = {}    # piece name -> radians
	var local_off: Dictionary = {}    # piece name -> Vector2
	var local_alpha: Dictionary = {}  # piece name -> float
	for key in pose.keys():
		if _groups.has(key):
			continue
		var piece_name := _resolve_piece(str(key))
		if piece_name == "":
			continue
		var value: Dictionary = pose[key]
		local_rot[piece_name] = deg_to_rad(float(value.get("rot", 0.0)))
		local_off[piece_name] = _to_vec(value.get("pos", Vector2.ZERO))
		local_alpha[piece_name] = float(value.get("alpha", 1.0))

	# --- 2. the hierarchy, still in the group's frame ----------------------
	var frame_origin: Dictionary = {}  # piece name -> Vector2
	var chain_rot: Dictionary = {}    # piece name -> radians
	for piece_name in _order:
		var rest: Dictionary = _rest.get(piece_name, {})
		if rest.is_empty():
			continue
		var own_rot: float = float(local_rot.get(piece_name, 0.0))
		var own_off: Vector2 = local_off.get(piece_name, Vector2.ZERO)
		var parent_name: String = str(_parent_of.get(piece_name, ""))
		if parent_name != "" and frame_origin.has(parent_name):
			# the offset from the parent, swung by the parent's own rotation
			var offset: Vector2 = Vector2(rest["pos"]) - Vector2(_rest[parent_name]["pos"])
			frame_origin[piece_name] = Vector2(frame_origin[parent_name]) \
				+ (offset + own_off).rotated(float(chain_rot[parent_name]))
			chain_rot[piece_name] = float(chain_rot[parent_name]) + own_rot
		else:
			frame_origin[piece_name] = Vector2(rest["pos"]) + own_off
			chain_rot[piece_name] = own_rot

	# --- 3. the groups ride on top ----------------------------------------
	var final_pos: Dictionary = {}
	var final_rot: Dictionary = {}
	var final_alpha: Dictionary = {}
	for piece_name in _order:
		if not frame_origin.has(piece_name):
			continue
		final_pos[piece_name] = frame_origin[piece_name]
		final_rot[piece_name] = chain_rot[piece_name]
		final_alpha[piece_name] = float(local_alpha.get(piece_name, 1.0))

	for key in pose.keys():
		if not _groups.has(key):
			continue
		var group: Dictionary = _groups[key]
		var pivot := Vector2(
			float(group.get("pivot", {}).get("x", 0.0)),
			float(group.get("pivot", {}).get("y", 0.0))
		)
		var theta := deg_to_rad(float(pose[key].get("rot", 0.0)))
		var offset: Vector2 = _to_vec(pose[key].get("pos", Vector2.ZERO))
		var group_alpha := float(pose[key].get("alpha", 1.0))
		for member in group.get("members", []):
			var member_name := _resolve_piece(str(member))
			# only the root of a subtree is moved, the rest come along with it
			if member_name == "" or _parent_of.has(member_name):
				continue
			for piece_name in _subtree(member_name):
				if not frame_origin.has(piece_name):
					continue
				final_pos[piece_name] = (Vector2(frame_origin[piece_name]) - pivot).rotated(theta) \
					+ pivot + offset
				final_rot[piece_name] = theta + float(chain_rot[piece_name])
			final_alpha[member_name] = float(local_alpha.get(member_name, 1.0)) * group_alpha

	# --- 4. write it out ---------------------------------------------------
	for piece_name in _order:
		if not final_pos.has(piece_name):
			continue
		var parent_name: String = str(_parent_of.get(piece_name, ""))
		if parent_name != "" and final_alpha.has(parent_name):
			final_alpha[piece_name] = float(final_alpha[parent_name]) * float(local_alpha.get(piece_name, 1.0))
		sprite_set(piece_name, final_pos[piece_name], final_rot[piece_name])
		sprite_set_alpha(piece_name, final_alpha[piece_name])
	_update_filters()

	# --- 5. the whole mage moves, for the jump and the flight ---------------
	# A "root" target moves the mage as one piece, which is how she leaves the
	# ground and floats up out of it.
	var root_value: Dictionary = pose.get("root", {})
	_root_offset = _to_vec(root_value.get("pos", Vector2.ZERO))
	_root_rotation = deg_to_rad(float(root_value.get("rot", 0.0)))
	if target != null:
		# the offset is in the mage's own pixels, but the position is in the
		# space of whatever holds her, so it has to be scaled to match
		var offset := _root_offset + _shake_offset(_shake, elapsed)
		target.position = _rest_target_pos + Vector2(offset.x * target.scale.x, offset.y * target.scale.y)
		target.rotation = _root_rotation


## A small jitter for the mage and the camera while something is shaking.
## It is a function of time so it always plays the same way.
static func _shake_offset(amount: float, t: float) -> Vector2:
	if amount <= 0.0:
		return Vector2.ZERO
	var x := sin(t * 61.0) * 0.6 + sin(t * 37.0) * 0.4
	var y := cos(t * 53.0) * 0.6 + cos(t * 29.0) * 0.4
	return Vector2(x, y) * amount


## How much the camera is being asked to shake, from 0 to 1.
func get_camera_shake() -> float:
	return _camera_shake


## A piece that is turning has to be filtered smoothly, otherwise its pixels
## boil as the art re-samples every frame and the movement reads as a stutter
## rather than a turn.
##
## The decision is made per clip rather than per frame, so a piece never flickers
## between crisp and soft while it moves, and a clip that only nudges a piece
## (the idle breath) keeps the crisp pixel look.
func _update_filters() -> void:
	for piece_name in _rest.keys():
		var sprite: Sprite2D = target.pieces.get(piece_name)
		if sprite == null:
			continue
		var wanted := CanvasItem.TEXTURE_FILTER_NEAREST
		if smooth_rotation and _smooth_pieces.has(piece_name):
			wanted = CanvasItem.TEXTURE_FILTER_LINEAR
		if sprite.texture_filter != wanted:
			sprite.texture_filter = wanted


func sprite_set(piece_name: String, pos: Vector2, rot: float) -> void:
	var sprite: Sprite2D = target.pieces.get(piece_name)
	if sprite == null:
		return
	sprite.position = pos
	sprite.rotation = rot


## Sets the opacity of a piece.
func sprite_set_alpha(piece_name: String, alpha: float) -> void:
	var sprite: Sprite2D = target.pieces.get(piece_name)
	if sprite == null:
		return
	sprite.modulate.a = clampf(alpha, 0.0, 1.0)


## Returns the mage to its authored rest pose.
func reset_to_rest() -> void:
	for piece_name in _rest.keys():
		var rest: Dictionary = _rest[piece_name]
		sprite_set(piece_name, rest["pos"], rest["rot"])
		sprite_set_alpha(piece_name, 1.0)


## Reports the current world position of a piece's pivot, useful for attaching FX.
func get_piece_origin(piece_name: String) -> Vector2:
	var sprite: Sprite2D = target.pieces.get(piece_name)
	if sprite == null or not sprite.is_inside_tree():
		return Vector2.ZERO
	return sprite.global_position


# --------------------------------------------------------------------------- #
# easing
# --------------------------------------------------------------------------- #
static func _ease(p: float, kind: String) -> float:
	match kind:
		"linear":
			return p
		"in":
			return p * p
		"out":
			return 1.0 - pow(1.0 - p, 2.0)
		"in_out":
			return p * p * (3.0 - 2.0 * p)
		"in_quad":
			return p * p
		"out_quad":
			return 1.0 - pow(1.0 - p, 2.0)
		"in_cubic":
			return p * p * p
		"out_cubic":
			return 1.0 - pow(1.0 - p, 3.0)
		"in_out_cubic":
			return (4.0 * p * p * p) if p < 0.5 else (1.0 - pow(-2.0 * p + 2.0, 3.0) / 2.0)
		"out_expo":
			return 1.0 if p >= 1.0 else 1.0 - pow(2.0, -10.0 * p)
		"out_back":
			var c1 := 1.70158
			var c3 := c1 + 1.0
			return 1.0 + c3 * pow(p - 1.0, 3.0) + c1 * pow(p - 1.0, 2.0)
		"step":
			# holds the outgoing value then jumps at the very end of the segment
			return 0.0 if p < 1.0 else 1.0
		"snap":
			return 0.0 if p < 0.5 else 1.0
		_:
			return p
