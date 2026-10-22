extends SceneTree

## Verifies the modular Knight's rig and its walk: the pieces sit where the
## data says, the walk drives the body and the sword arm, and the loop closes.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	print("==================================================================")
	print("🧪 STARTING MODULAR KNIGHT RIG TEST SUITE")
	print("==================================================================")

	_test_rig()
	_test_walk()
	_test_attacks()
	_test_the_ultimate()
	_test_the_feet_walk()
	_test_the_knight_stays_whole()

	print("\n==================================================================")
	if _failures == 0:
		print("🎉 ALL %d MODULAR KNIGHT RIG CHECKS PASSED SUCCESSFULLY!" % _checks)
	else:
		print("❌ %d of %d MODULAR KNIGHT RIG CHECKS FAILED." % [_failures, _checks])
	print("==================================================================")
	quit(0 if _failures == 0 else 1)


## Records a check.
func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("  ❌ FAIL: " + message)


## Builds a rig for a perspective, and a player that drives it.
func _make_rig(perspective: String) -> Dictionary:
	var path := "res://Knight/Knight_%s/Knight%s.tscn" % [perspective, perspective.capitalize()]
	var scene := load(path) as PackedScene
	if scene == null:
		return {}
	var rig := scene.instantiate() as KnightModularBase
	root.add_child(rig)
	rig._ready()
	var player := KnightChoreoPlayer.new()
	player.target = rig
	root.add_child(player)
	player._ready()
	return {"rig": rig, "player": player}


func _test_rig() -> void:
	print("\n[TEST 1] The rig in every view:")
	for perspective in ["front", "back", "left", "right"]:
		var info := _make_rig(perspective)
		_check(not info.is_empty(), "[%s] The rig scene must load" % perspective)
		if info.is_empty():
			continue
		var rig: KnightModularBase = info["rig"]

		var data: Dictionary = rig.get_piece_data()
		_check(not data.is_empty(), "[%s] The rig must have its piece data" % perspective)
		var pieces: Dictionary = data.get("pieces", {})
		_check(not pieces.is_empty(), "[%s] The rig data must have pieces" % perspective)
		_check(data.get("roles", {}).has("body"),
			"[%s] The rig must have a body role" % perspective)
		_check(data.get("roles", {}).has("sword"),
			"[%s] The rig must have a sword role" % perspective)

		# every piece of the data has to be a sprite in the scene, sitting
		# exactly where the data says it sits
		var hip_x: float = float(pieces.get("body", {}).get("pivot", {}).get("x", 16.0))
		for name in pieces:
			var piece: Sprite2D = rig.get_piece(name)
			_check(piece != null, "[%s] The scene must carry the %s piece" % [perspective, name])
			if piece == null:
				continue
			var want: Dictionary = pieces[name]
			var canvas := Vector2(
				float(want.get("position", {}).get("x", 0.0)),
				float(want.get("position", {}).get("y", 0.0)))
			var got: Vector2 = piece.position + piece.offset
			var want_rig := Vector2(canvas.x - hip_x, canvas.y - 32.0)
			_check(got.distance_to(want_rig) < 0.01,
				"[%s] The %s piece must sit where the data says, at %s and not %s"
					% [perspective, name, str(got.round()), str(want_rig.round())])
			# and it turns about the pivot the data gives it
			var pivot: Vector2 = piece.get_meta("pivot", Vector2.ZERO)
			var want_pivot_data: Dictionary = want.get("pivot", {})
			var want_pivot := Vector2(
				float(want_pivot_data.get("x", 0.0)),
				float(want_pivot_data.get("y", 0.0)))
			_check(pivot.distance_to(want_pivot) < 0.01,
				"[%s] The %s piece must have the pivot the data gives it" % [perspective, name])
	print("  ✅ PASS: the knight's pieces sit where the data says in every view")


func _test_walk() -> void:
	print("\n[TEST 2] The walk:")
	var info := _make_rig("right")
	var player: KnightChoreoPlayer = info["player"]
	var rig: KnightModularBase = info["rig"]

	_check(FileAccess.file_exists(KnightAnims.clip_path(KnightAnims.WALK)),
		"The walk clip file must exist")
	_check(player.load_clip(KnightAnims.WALK), "The walk clip must load")
	_check(player.get_duration() > 0.0, "The walk must have a length")

	# the body bobs and the sword arm swings
	var start: Dictionary = player.sample(0.0)
	_check(start.has("torso"), "The walk must move the torso")
	_check(start.has("arm"), "The walk must move the arm")

	var lowest := 99.0
	var highest := -99.0
	var swing := 0.0
	for i in range(25):
		var t := float(i) / 24.0 * player.get_duration()
		var pose: Dictionary = player.sample(t)
		var torso: Dictionary = pose.get("torso", {})
		var body_pos: Vector2 = torso.get("pos", Vector2.ZERO)
		var body_y := body_pos.y
		lowest = minf(lowest, body_y)
		highest = maxf(highest, body_y)
		var arm: Dictionary = pose.get("arm", {})
		swing = maxf(swing, absf(float(arm.get("rot", 0.0))))
	_check(highest - lowest >= 0.5,
		"The body must bob with the stride, it only moved %f pixels" % (highest - lowest))
	_check(swing >= 5.0, "The sword arm must swing with the stride, it only swung %f degrees" % swing)

	# and the loop must close
	var first: Dictionary = player.sample(0.0)
	var last: Dictionary = player.sample(player.get_duration())
	_check(float(first.get("arm", {}).get("rot", 0.0)) == float(last.get("arm", {}).get("rot", 0.0)),
		"The walk must come back to where it started")

	# the sword rides in the hand, so it swings with the arm
	var sword: Sprite2D = rig.get_piece("sword")
	var arm: Sprite2D = rig.get_piece("arm")
	_check(sword != null and arm != null, "The right view needs an arm and a sword")
	if sword != null and arm != null:
		player.scrub_time(0.15)
		var swung: float = absf(rad_to_deg(arm.rotation))
		_check(swung > 1.0, "The arm must have swung")
		_check(absf(rad_to_deg(sword.rotation)) > 1.0,
			"The sword must swing with the arm that holds it")
	print("  ✅ PASS: the walk bobs the body, swings the sword arm and closes the loop")


func _test_attacks() -> void:
	print("\n[TEST 3] The attacks:")
	for anim in [KnightAnims.SLASH, KnightAnims.STAB, KnightAnims.PLUNGE]:
		_check(FileAccess.file_exists(KnightAnims.clip_path(anim)),
			"The %s clip file must exist" % anim)

	for perspective in ["front", "back", "left", "right"]:
		var info := _make_rig(perspective)
		var player: KnightChoreoPlayer = info["player"]
		for anim in [KnightAnims.SLASH, KnightAnims.STAB, KnightAnims.PLUNGE]:
			_check(player.load_clip(anim), "[%s] The %s clip must load" % [perspective, anim])
			# the sword arm has to move, and come back to where it started
			var swung := 0.0
			for i in range(25):
				var t := float(i) / 24.0 * player.get_duration()
				var pose: Dictionary = player.sample(t)
				var arm: Dictionary = pose.get("arm", {})
				swung = maxf(swung, absf(float(arm.get("rot", 0.0))))
			_check(swung > 10.0,
				"[%s] The %s must swing the sword arm, it only swung %f degrees"
					% [perspective, anim, swung])
			var first: Dictionary = player.sample(0.0)
			var last: Dictionary = player.sample(player.get_duration())
			_check(float(first.get("arm", {}).get("rot", 0.0)) == float(last.get("arm", {}).get("rot", 0.0)),
				"[%s] The %s must come back to where it started" % [perspective, anim])
	print("  ✅ PASS: the slash, the stab and the plunge swing the sword arm in every view")


## The Knight's Edge, the ultimate: the fire that the sword takes with it.
func _test_the_ultimate() -> void:
	print("\n[TEST 4] The Knight's Edge:")
	_check(FileAccess.file_exists(KnightAnims.clip_path(KnightAnims.ULTIMATE)),
		"The ultimate's clip file must exist")
	_check(FileAccess.file_exists("res://Knight/Anim/KnightUltimate/knight_ultimate_fire.gdshader"),
		"The ultimate's fire shader must exist")
	_check(FileAccess.file_exists("res://Knight/Anim/KnightUltimate/knight_ultimate_dark.gdshader"),
		"The ultimate's dark shader must exist")
	_check(FileAccess.file_exists("res://Knight/Anim/KnightUltimate/sprites/fire_slash.png"),
		"The ultimate's flipbook must exist")

	for perspective in ["front", "back", "left", "right"]:
		var info := _make_rig(perspective)
		var player: KnightChoreoPlayer = info["player"]
		var rig: KnightModularBase = info["rig"]
		_check(player.load_clip(KnightAnims.ULTIMATE),
			"[%s] The ultimate's clip must load" % perspective)

		# The effect has to be there, or the fire never shows.  Both parts
		# are in a layer over the game: the darkness covers the screen, and
		# the fire burns on top of it, placed and sized by the knight.
		var fx := rig.get_node_or_null("KnightUltimateLayer/KnightUltimateFX")
		var dark := rig.get_node_or_null("KnightUltimateLayer/KnightUltimateDark")
		_check(fx != null, "[%s] The Knight's Edge effect node must be in the scene" % perspective)
		_check(dark != null, "[%s] The Knight's Edge dark node must be in the scene" % perspective)
		if fx == null:
			continue
		var material := fx.material as ShaderMaterial
		_check(material != null, "[%s] The effect must carry a material" % perspective)
		if material == null:
			continue
		_check(material.get_shader_parameter("flipbook") != null,
			"[%s] The flipbook must be bound to the shader" % perspective)
		_check(material.shader != null, "[%s] The effect must carry the shader" % perspective)

		# the attack comes in three parts, and the clip has to say so:
		# the blade catches fire, the screen goes dark, then the sweep plays
		var charge := 0.0
		var dim := 0.0
		var slash_t := 0.0
		var slash := 0.0
		var peak_charge := 0.0
		var peak_dim := 0.0
		var seen: Dictionary = {}
		for i in range(40):
			var t := float(i) / 39.0 * player.get_duration()
			var params: Dictionary = player.sample_fx(t)
			charge = float(params.get("charge", 0.0))
			dim = float(params.get("dim", 0.0))
			slash_t = float(params.get("slash_t", 0.0))
			slash = float(params.get("slash", 0.0))
			peak_charge = maxf(peak_charge, charge)
			peak_dim = maxf(peak_dim, dim)
			if slash > 0.0:
				seen[int(floor(slash_t * 8.0))] = true
		_check(peak_charge > 0.9,
			"[%s] The blade must catch fire, it only reached %f" % [perspective, peak_charge])
		_check(peak_dim > 0.9,
			"[%s] The screen must go to pitch black, it only reached %f" % [perspective, peak_dim])
		_check(seen.size() >= 6,
			"[%s] The sweep must play most of the flipbook, it played %d frames"
				% [perspective, seen.size()])

		# the sword has to swing, and the swing has to be a real one
		var swung := 0.0
		for i in range(40):
			var t := float(i) / 39.0 * player.get_duration()
			player.apply_pose(player.sample(t))
			var sword: Sprite2D = rig.get_piece("sword")
			if sword != null:
				swung = maxf(swung, absf(rad_to_deg(sword.rotation)))
		_check(swung > 45.0,
			"[%s] The ultimate must swing the sword, it only swung %f degrees"
				% [perspective, swung])

		# and it has to come back to where it started
		var rest: Dictionary = player.sample(0.0)
		var end: Dictionary = player.sample(player.get_duration())
		var role := "arm"
		var data: Dictionary = rig.get_piece_data()
		if not data.get("roles", {}).has("arm"):
			role = "sword"
		_check(float(rest.get(role, {}).get("rot", 0.0)) == float(end.get(role, {}).get("rot", 0.0)),
			"[%s] The ultimate must come back to where it started" % perspective)

		# The fire is the size of the knight, not the size of the screen.  The
		# sweep's arc turns about the shoulder, and its radius is the blade's
		# reach, so the fire is always the line the blade drew.
		var placement: Dictionary = {}
		var path := "res://Knight/Anim/KnightUltimate/placement.json"
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			placement = JSON.parse_string(file.get_as_text())
		if not placement.is_empty():
			var measured: Dictionary = placement.get(perspective, {})
			var scale: float = float(measured.get("scale", 0.0))
			var radius: float = float(measured.get("arc_radius", 0.0))
			_check(scale > 0.0 and radius > 0.0,
				"[%s] The sweep must have a measured size" % perspective)
			# the arc, in the knight's own pixels, against the knight's own size
			var arc: float = radius * scale
			_check(arc > 8.0 and arc < 24.0,
				"[%s] The sweep's arc must be about the knight's size, it is %f pixels"
					% [perspective, arc])
			# and it has to sit in front of him, so it reads as his
			var offset: Array = measured.get("front_offset", [])
			_check(offset.size() == 2 and Vector2(offset[0], offset[1]).length() > 0.0,
				"[%s] The fire must sit in front of the knight" % perspective)

		# The last of the fire is embers, and embers do not stop where they
		# are.  The drift has to keep going while the screen is still dark.
		var shader: FileAccess = FileAccess.open(
			"res://Knight/Anim/KnightUltimate/knight_ultimate_fire.gdshader", FileAccess.READ)
		var source: String = shader.get_as_text()
		_check(source.contains("drift"),
			"[%s] The fire must drift, so the embers float" % perspective)
		_check(source.contains("drift_wander"),
			"[%s] Each ember must wander on its own course" % perspective)
	print("  ✅ PASS: the ultimate swings the sword and plays the fire in every view")


func _test_the_feet_walk() -> void:
	print("\n[TEST 5] The feet walk:")
	for perspective in ["front", "back", "left", "right"]:
		var info := _make_rig(perspective)
		var player: KnightChoreoPlayer = info["player"]
		var rig: KnightModularBase = info["rig"]
		_check(player.load_clip(KnightAnims.WALK), "[%s] The walk must load" % perspective)

		# the feet have to be roles, or a clip cannot move them at all
		var roles: Dictionary = rig.get_piece_data().get("roles", {})
		var feet := 0
		for name in roles:
			if name.begins_with("foot"):
				feet += 1
		_check(feet > 0, "[%s] The rig must have a foot role" % perspective)

		# and the walk has to move them
		var lift := 0.0
		var step := 0.0
		for i in range(25):
			var t := float(i) / 24.0 * player.get_duration()
			var pose: Dictionary = player.sample(t)
			for name in roles:
				if not name.begins_with("foot"):
					continue
				var foot: Dictionary = pose.get(name, {})
				var pos: Vector2 = foot.get("pos", Vector2.ZERO)
				lift = maxf(lift, absf(pos.y))
				step = maxf(step, absf(pos.x))
		_check(lift >= 0.5, "[%s] A foot must lift as he walks, it only lifted %f pixels" % [perspective, lift])
		# the side views stride, so a foot reaches forward as well as lifting.
		# The front and back views shuffle, because a step towards or away
		# from the camera cannot be seen.
		if perspective in ["left", "right"]:
			_check(step >= 0.5,
				"[%s] The feet must step, they only moved %f pixels" % [perspective, step])
	print("  ✅ PASS: the feet have roles and the walk moves them")


func _test_the_knight_stays_whole() -> void:
	print("\n[TEST 6] The knight stays whole:")
	for perspective in ["front", "back", "left", "right"]:
		var info := _make_rig(perspective)
		var player: KnightChoreoPlayer = info["player"]
		var rig: KnightModularBase = info["rig"]
		var data: Dictionary = rig.get_piece_data()
		var pieces: Dictionary = data.get("pieces", {})
		var members: Array = data.get("groups", {}).get("torso", {}).get("members", [])
		var parents: Dictionary = data.get("piece_parents", {})

		# Every piece has to hang off something: the body, the arm that holds
		# the sword, or the ground for the feet.  A piece that hangs off
		# nothing is a piece that stays behind when the rest of the knight
		# moves, and the knight comes apart in the middle.
		for name in pieces:
			if name in members or parents.has(name):
				continue
			if name.begins_with("boot"):
				continue
			_check(false,
				"[%s] The %s piece must hang off the body or off another piece"
					% [perspective, name])

		# and the sword must stay in the hand while the arm swings
		_check(player.load_clip(KnightAnims.WALK), "[%s] The walk must load" % perspective)
		var arm: Sprite2D = rig.get_piece("arm")
		var sword: Sprite2D = rig.get_piece("sword")
		if arm == null or sword == null:
			continue
		var first := -1.0
		for i in range(25):
			var t := float(i) / 24.0 * player.get_duration()
			player.scrub_time(t)
			var gap := arm.position.distance_to(sword.position)
			if first < 0.0:
				first = gap
			_check(absf(gap - first) < 0.01,
				"[%s] The sword must stay in the hand, the gap moved from %f to %f"
					% [perspective, first, gap])
	print("  ✅ PASS: every piece hangs off the knight, and the sword stays in the hand")
