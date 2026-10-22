extends SceneTree

## Verifies the modular Mage choreography player: clip loading, sampling, group
## transforms, per-perspective overrides and rest restoration.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	print("==================================================================")
	print("🧪 STARTING MODULAR MAGE CHOREOGRAPHY TEST SUITE")
	print("==================================================================")

	_test_clip_loading()
	_test_idle_sampling()
	_test_group_transform()
	_test_per_perspective_override()
	_test_rest_restoration()
	_test_transport()
	_test_hat_stays_attached()
	_test_teleport()
	_test_teleport_reappear()
	_test_staff_rides_the_arm()
	_test_fireball()
	_test_smooth_rotation()
	_test_energy_barrier()
	_test_no_stops_at_keys()
	_test_meteorite()
	_test_root_motion()
	_test_playback_speed()
	_test_gem_detection()
	_test_scaled_root_motion()
	_test_character_controller()
	_test_walk_cycle()
	_test_contact_shadow()
	_test_gem_light()

	print("\n==================================================================")
	if _failures == 0:
		print("🎉 ALL %d MODULAR MAGE CHOREOGRAPHY CHECKS PASSED SUCCESSFULLY!" % _checks)
	else:
		print("❌ %d of %d MODULAR MAGE CHOREOGRAPHY CHECKS FAILED." % [_failures, _checks])
	print("==================================================================")
	quit(0 if _failures == 0 else 1)


## Records a check. Mirrors assert() but keeps an accurate tally so the summary
## line can never claim success while something actually failed.
func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("  ❌ FAIL: " + message)


## Builds a player bound to a fresh mage of the given perspective.
func _make_player(perspective: String) -> Dictionary:
	var mage: MageModularBase = ModularMageUtility.instantiate_mage(perspective)
	root.add_child(mage)
	mage._ready()
	var player := MageChoreoPlayer.new()
	player.target = mage
	root.add_child(player)
	player._ready()
	return {"mage": mage, "player": player}


func _test_clip_loading() -> void:
	print("\n[TEST 1] Clip discovery and loading:")
	var player_info := _make_player("front")
	var player: MageChoreoPlayer = player_info["player"]
	var clips := player.get_available_clips()
	_check(clips.has("mage_idle"), "The 'mage_idle' clip must be discoverable, found: " + str(clips))
	_check(clips.has("mage_cast"), "The 'mage_cast' clip must be discoverable, found: " + str(clips))
	_check(player.load_clip("mage_idle"), "load_clip('mage_idle') must succeed")
	_check(player.current_clip == "", "current_clip must stay empty until play()")
	print("  ✅ PASS: found %d clips (%s)" % [clips.size(), ", ".join(clips)])


func _test_idle_sampling() -> void:
	print("\n[TEST 2] Idle clip sampling and interpolation:")
	var player_info := _make_player("front")
	var player: MageChoreoPlayer = player_info["player"]
	var mage: MageModularBase = player_info["mage"]
	player.load_clip("mage_idle")

	# rest at t = 0
	player.scrub(0.0)
	var staff: Sprite2D = mage.get_piece("staff")
	_check(is_zero_approx(staff.rotation), "Staff must start unrotated, got %f" % staff.rotation)

	# peak of the breath at t = 1.0
	player.scrub(0.5)
	var peak := player.sample(1.0)
	_check(peak.has("staff"), "The sampled pose must contain the staff")
	_check(absf(float(peak["staff"].get("rot", 0.0)) - 2.0) < 0.001,
		"Staff rotation at the breath peak must be 2.0, got %s" % peak["staff"].get("rot"))
	_check(absf(float(peak["hat"].get("rot", 0.0)) + 1.5) < 0.001,
		"Hat rotation at the breath peak must be -1.5, got %s" % peak["hat"].get("rot"))
	print("  ✅ PASS: keyframes sample and interpolate correctly")


func _test_group_transform() -> void:
	print("\n[TEST 3] Group transform moves members rigidly about the shared pivot:")
	var player_info := _make_player("right")
	var player: MageChoreoPlayer = player_info["player"]
	var mage: MageModularBase = player_info["mage"]

	var body: Sprite2D = mage.get_piece("body")
	var arm: Sprite2D = mage.get_piece("arm_left")
	var rest_body: Vector2 = body.position
	var rest_arm: Vector2 = arm.position

	# a pure group translation must move body and arm by the same amount
	player.apply_pose({"torso": {"rot": 0.0, "pos": Vector2(0, -2)}})
	_check(body.position.is_equal_approx(rest_body + Vector2(0, -2)),
		"Body must move up 2px with the torso group, moved %s" % (body.position - rest_body))
	_check(arm.position.is_equal_approx(rest_arm + Vector2(0, -2)),
		"Arm must move up 2px with the torso group, moved %s" % (arm.position - rest_arm))

	# a group rotation must keep the distance from the pivot constant
	var pivot := Vector2(13, 25)
	var before: float = (rest_body - pivot).length()
	player.apply_pose({"torso": {"rot": 10.0, "pos": Vector2.ZERO}})
	var after: float = (body.position - pivot).length()
	_check(absf(before - after) < 0.01,
		"Body must keep its distance from the group pivot, %f vs %f" % [before, after])
	print("  ✅ PASS: groups translate and rotate their members as one rigid body")


func _test_per_perspective_override() -> void:
	print("\n[TEST 4] Per-perspective clip override:")
	var front_info := _make_player("front")
	var right_info := _make_player("right")
	var front_player: MageChoreoPlayer = front_info["player"]
	var right_player: MageChoreoPlayer = right_info["player"]

	front_player.load_clip("mage_cast")
	right_player.load_clip("mage_cast")

	var front_pose: Dictionary = front_player.sample(0.35)
	var right_pose: Dictionary = right_player.sample(0.35)
	_check(float(front_pose["staff"].get("rot", 0.0)) > 0.0,
		"The front view staff leans left, so the raise angle must be positive")
	_check(float(right_pose["staff"].get("rot", 0.0)) < 0.0,
		"The right view staff leans right, so the raise angle must be negative")
	print("  ✅ PASS: front %+.1f deg, right %+.1f deg" % [
		float(front_pose["staff"]["rot"]), float(right_pose["staff"]["rot"])])


func _test_rest_restoration() -> void:
	print("\n[TEST 5] Rest pose restoration:")
	var player_info := _make_player("back")
	var player: MageChoreoPlayer = player_info["player"]
	var mage: MageModularBase = player_info["mage"]
	var body: Sprite2D = mage.get_piece("body")
	var rest: Vector2 = body.position

	player.apply_pose({"torso": {"rot": 12.0, "pos": Vector2(3, -4)}})
	_check(not body.position.is_equal_approx(rest), "The pose must actually move the body")
	player.reset_to_rest()
	_check(body.position.is_equal_approx(rest), "reset_to_rest must restore the rest position")
	print("  ✅ PASS: reset_to_rest restores the authored pose")


func _test_transport() -> void:
	print("\n[TEST 6] Transport controls:")
	var player_info := _make_player("left")
	var player: MageChoreoPlayer = player_info["player"]
	player.load_clip("mage_idle")
	player.play("mage_idle")
	_check(player.is_playing, "play() must start playback")
	_check(player.get_frame_count() > 0, "The clip must report a frame count")
	player.jump_to_frame(1)
	_check(player.get_current_frame() == 1, "jump_to_frame(1) must land on frame 1")
	player.jump_to_frame(player.get_frame_count())
	_check(player.get_current_frame() == player.get_frame_count(),
		"jumping to the last frame must land on it")
	player.scrub_percent(50.0)
	_check(absf(player.get_progress() - 0.5) < 0.01, "scrub_percent(50) must reach 50%")
	player.stop()
	_check(not player.is_playing, "stop() must halt playback")
	print("  ✅ PASS: play / scrub / frame stepping / stop all behave")


func _test_hat_stays_attached() -> void:
	print("\n[TEST 7] The hat travels with the body:")
	for perspective in ["front", "back", "left", "right"]:
		var player_info := _make_player(perspective)
		var player: MageChoreoPlayer = player_info["player"]
		var mage: MageModularBase = player_info["mage"]

		var body: Sprite2D = mage.get_piece("body")
		var hat: Sprite2D = mage.get_piece("hat")
		var staff: Sprite2D = mage.get_piece("staff")
		var rest_body: Vector2 = body.position
		var rest_hat: Vector2 = hat.position
		var rest_staff: Vector2 = staff.position

		# the torso group lifts the chest, everything it carries must follow
		player.apply_pose({"torso": {"rot": 0.0, "pos": Vector2(0, -2)}})
		_check(body.position.is_equal_approx(rest_body + Vector2(0, -2)),
			"[%s] Body must lift 2px" % perspective)
		_check(hat.position.is_equal_approx(rest_hat + Vector2(0, -2)),
			"[%s] Hat must lift 2px with the body, moved %s" % [perspective, hat.position - rest_hat])
		_check(staff.position.is_equal_approx(rest_staff + Vector2(0, -2)),
			"[%s] Staff must lift 2px with the body, moved %s" % [perspective, staff.position - rest_staff])

		# a local hat tilt must survive on top of the group motion
		player.apply_pose({
			"torso": {"rot": 0.0, "pos": Vector2(0, -2)},
			"hat": {"rot": -4.0},
		})
		_check(absf(rad_to_deg(hat.rotation) + 4.0) < 0.01,
			"[%s] The hat must keep its own tilt while following the body, got %f deg"
				% [perspective, rad_to_deg(hat.rotation)])
		_check(hat.position.is_equal_approx(rest_hat + Vector2(0, -2)),
			"[%s] The hat must still lift 2px while tilting" % perspective)

		# and the hat must be back at rest once the pose is gone
		player.reset_to_rest()
		_check(hat.position.is_equal_approx(rest_hat),
			"[%s] The hat must return to its rest position" % perspective)
	print("  ✅ PASS: the hat and the staff stay attached to the body in all four views")


func _test_teleport() -> void:
	print("\n[TEST 8] The teleport clip drives the rig and the effect:")
	var player_info := _make_player("front")
	var player: MageChoreoPlayer = player_info["player"]
	var mage: MageModularBase = player_info["mage"]

	_check(player.load_clip("mage_teleport"), "The teleport clip must load")
	var clips := player.get_available_clips()
	_check(clips.has("mage_teleport"), "The teleport clip must be discoverable")

	# the effect node named by the clip's "fx" block has to be found
	var fx := mage.get_node_or_null("TeleportFX")
	_check(fx != null, "The mage scene must carry a TeleportFX node")
	var material := fx.material as ShaderMaterial
	_check(material != null, "TeleportFX must carry a ShaderMaterial")

	# the effect parameters are interpolated across the keys
	var early := player.sample_fx(0.0)
	var late := player.sample_fx(0.5)
	_check(float(early.get("progress", -1.0)) < float(late.get("progress", -1.0)),
		"The effect progress must advance over time")
	_check(float(late.get("progress", -1.0)) > 0.0, "The effect must have advanced by 0.5s")

	# scrubbing pushes the parameters into the shader
	player.scrub_time(0.5)
	_check(absf(float(material.get_shader_parameter("progress")) - float(late["progress"])) < 0.001,
		"scrub() must push the effect progress into the shader, got %s expected %s"
			% [material.get_shader_parameter("progress"), late["progress"]])

	# the bars close in on the mage, so the surviving band gets narrower
	player.scrub_time(0.0)
	var wide := player.sample_fx(0.0)
	player.scrub_time(0.55)
	var tight := player.sample_fx(0.55)
	_check(float(tight["band_top"]) > float(wide["band_top"]),
		"The upper bar must travel down over the clip")
	_check(float(tight["band_bottom"]) < float(wide["band_bottom"]),
		"The lower bar must travel up over the clip")
	_check(float(tight["band_bottom"]) - float(tight["band_top"])
		< float(wide["band_bottom"]) - float(wide["band_top"]),
		"The gap between the bars must shrink over the clip")

	# the character is cut by that gap, and the cut is pushed to the material
	_check(absf(float(material.get_shader_parameter("band_top")) - float(tight["band_top"])) < 0.001,
		"The upper band must reach the character clip material")
	_check(absf(float(material.get_shader_parameter("band_bottom")) - float(tight["band_bottom"])) < 0.001,
		"The lower band must reach the character clip material")

	# the character clip material has to be on the pieces, not just on one
	var clipped := 0
	for piece_name in mage.pieces.keys():
		var piece: Sprite2D = mage.pieces[piece_name]
		if piece != null and piece.material is ShaderMaterial:
			clipped += 1
	_check(clipped >= 5, "Every character piece must carry the clip material, found %d" % clipped)

	# the mage is not squished, it only dissolves
	var clip := player.clip_data
	for k in clip.get("keys", []):
		_check(k.get("poses", {}).is_empty(),
			"The teleport clip must not move any piece, found %s" % str(k.get("poses", {})))

	# once the bars have met, their extent shrinks down to a point
	var met: Dictionary = player.sample_fx(0.70)
	var shrunk: Dictionary = player.sample_fx(0.85)
	_check(float(met["bar_half_width"]) > float(shrunk["bar_half_width"]),
		"The bars must shrink after they meet")
	_check(float(shrunk["bar_half_width"]) <= 1.0,
		"The bars must shrink down to a point, got %s" % shrunk["bar_half_width"])
	_check(float(shrunk["band_top"]) == float(shrunk["band_bottom"]),
		"The bars must have met at a single point")
	_check(float(player.sample_fx(0.90)["opacity"]) <= 0.0,
		"The point must despawn at the end of the clip")

	# and the mage comes back when the pose is cleared
	var body: Sprite2D = mage.get_piece("body")
	player.reset_to_rest()
	_check(body.modulate.a > 0.99, "reset_to_rest must bring the mage back")
	print("  ✅ PASS: the teleport clip drives the converging bars, the dissolve and the closing point")


func _test_teleport_reappear() -> void:
	print("\n[TEST 9] The teleport in clip mirrors the teleport out:")
	var player_info := _make_player("front")
	var player: MageChoreoPlayer = player_info["player"]
	var mage: MageModularBase = player_info["mage"]

	# the named API has to reach both clips
	_check(MageAnims.TELEPORT == "mage_teleport", "The teleport name must be stable")
	_check(MageAnims.TELEPORT_REAPPEAR == "mage_teleport_reappear",
		"The reappear name must be stable")
	_check(MageAnims.all().has(MageAnims.TELEPORT), "all() must list the teleport")
	_check(MageAnims.all().has(MageAnims.TELEPORT_REAPPEAR), "all() must list the reappear")
	_check(FileAccess.file_exists(MageAnims.clip_path(MageAnims.TELEPORT)),
		"The teleport clip file must exist")
	_check(FileAccess.file_exists(MageAnims.clip_path(MageAnims.TELEPORT_REAPPEAR)),
		"The reappear clip file must exist")

	_check(player.load_clip(MageAnims.TELEPORT_REAPPEAR), "The reappear clip must load")
	var clips := player.get_available_clips()
	_check(clips.has(MageAnims.TELEPORT), "The teleport clip must be discoverable")
	_check(clips.has(MageAnims.TELEPORT_REAPPEAR), "The reappear clip must be discoverable")

	# it starts with the mage hidden and the bars collapsed to a point
	var start := player.sample_fx(0.0)
	_check(float(start["band_top"]) == float(start["band_bottom"]),
		"The reappear must start with the bars closed")
	_check(float(start["bar_half_width"]) <= 1.0,
		"The reappear must start from a point")
	_check(float(start["opacity"]) <= 0.0, "The reappear must start invisible")

	# and ends with the mage fully revealed and the bars gone
	var end := player.sample_fx(player.get_duration())
	_check(float(end["band_bottom"]) - float(end["band_top"]) > 30.0,
		"The band must be fully open at the end")
	_check(float(end["opacity"]) <= 0.0, "The bars must have faded out at the end")

	# the band widens as it plays
	var middle := player.sample_fx(0.45)
	_check(float(middle["band_bottom"]) - float(middle["band_top"])
		> float(start["band_bottom"]) - float(start["band_top"]),
		"The band must widen as the mage reappears")

	# the character clip material is driven by it as well
	var material := (mage.get_node_or_null("TeleportFX").material as ShaderMaterial)
	player.scrub_time(0.45)
	_check(absf(float(material.get_shader_parameter("band_top")) - float(middle["band_top"])) < 0.001,
		"The reappear must push the band to the character clip material")

	# and the mage comes back
	var body: Sprite2D = mage.get_piece("body")
	player.scrub_time(0.85)
	_check(body.modulate.a > 0.99, "The mage must be fully back at the end of the reappear")
	print("  ✅ PASS: the reappear clip is the mirror of the teleport and has its own entry point")


func _test_staff_rides_the_arm() -> void:
	print("\n[TEST 10] The staff is held by the arm:")
	for perspective in ["front", "back", "right"]:
		var player_info := _make_player(perspective)
		var player: MageChoreoPlayer = player_info["player"]
		var mage: MageModularBase = player_info["mage"]

		var arm: Sprite2D = mage.get_piece("arm_right") if perspective != "right" else mage.get_piece("arm_left")
		var staff: Sprite2D = mage.get_piece("staff")
		_check(arm != null and staff != null, "The %s view needs an arm and a staff" % perspective)
		var rest_arm: Vector2 = arm.position
		var rest_staff: Vector2 = staff.position
		var grip: Vector2 = rest_staff - rest_arm

		# raising the arm has to carry the staff with it
		player.apply_pose({"arm": {"rot": 40.0}})
		_check(absf(arm.rotation - deg_to_rad(40.0)) < 0.001,
			"[%s] The arm must rotate about its shoulder" % perspective)

		# the staff's grip stays in the hand: the offset from the arm is swung
		# by the arm's own rotation and nothing else
		var expected: Vector2 = rest_arm + grip.rotated(deg_to_rad(40.0))
		_check(staff.position.is_equal_approx(expected),
			"[%s] The staff must ride the arm, expected %s got %s"
				% [perspective, expected, staff.position])

		# and the staff can still turn about the grip while the arm holds it
		player.apply_pose({"arm": {"rot": 40.0}, "staff": {"rot": 25.0}})
		_check(absf(staff.rotation - deg_to_rad(65.0)) < 0.001,
			"[%s] The staff must turn about the grip inside the arm's frame, got %f deg"
				% [perspective, rad_to_deg(staff.rotation)])

		# back to rest
		player.reset_to_rest()
		_check(staff.position.is_equal_approx(rest_staff), "[%s] The staff must return to rest" % perspective)
	print("  ✅ PASS: the staff is carried by the arm and still turns about the grip")


func _test_fireball() -> void:
	print("\n[TEST 11] The fireball cast:")
	var player_info := _make_player("right")
	var player: MageChoreoPlayer = player_info["player"]
	var mage: MageModularBase = player_info["mage"]

	_check(MageAnims.FIREBALL == "mage_fireball", "The fireball name must be stable")
	_check(MageAnims.all().has(MageAnims.FIREBALL), "all() must list the fireball")
	_check(FileAccess.file_exists(MageAnims.clip_path(MageAnims.FIREBALL)),
		"The fireball clip file must exist")
	_check(player.load_clip(MageAnims.FIREBALL), "The fireball clip must load")

	# the effect node has to be on the mage and carry the fireball shader
	var fx := mage.get_node_or_null("FireballFX")
	_check(fx != null, "The mage scene must carry a FireballFX node")
	var material := fx.material as ShaderMaterial
	_check(material != null, "FireballFX must carry a ShaderMaterial")
	_check(material.shader != null and material.shader.resource_path.ends_with("mage_fireball.gdshader"),
		"FireballFX must use the fireball shader")

	# the cast raises the arm and then turns the staff in the hand
	var raised := player.sample(0.22)
	_check(float(raised["arm"].get("rot", 0.0)) < -15.0,
		"The arm must be raised, got %s" % raised["arm"].get("rot"))
	var turned := player.sample(0.96)
	_check(float(turned["staff"].get("rot", 0.0)) > 30.0,
		"The staff must be turned down in the hand, got %s" % turned["staff"].get("rot"))

	# the fireball falls from the sky onto the ground
	var start := player.sample_fx(0.42)
	var end := player.sample_fx(player.get_duration())
	_check(float(start["fall"]) <= 0.0, "The fireball must not have fallen yet")
	_check(float(end["fall"]) >= 0.99, "The fireball must have landed")
	_check(float(start["gem_glow"]) < float(end["gem_glow"]) or float(end["gem_glow"]) == 0.0,
		"The gem glow must come on")

	# the pit of fire is left behind and outlives the clip
	var pit := player.sample_fx(player.get_duration())
	_check(float(pit["pit_strength"]) > 0.9, "A pit of fire must be left behind")
	_check(player.get_duration() > 1.0, "The cast must last over a second")
	_check(player.clip_data.get("linger", 0.0) > 0.0, "The pit must outlive the clip")

	# and the effect is actually told about the linger
	player.scrub_time(player.get_duration())
	player.apply_fx_linger(1.0)
	_check(float(material.get_shader_parameter("linger")) > 0.9,
		"The linger time must reach the effect so the fire can burn out")

	# the pit has to burn out on its own.  The character goes back to
	# standing still the moment the cast is over, and that must not stop the
	# fire from going out.
	player.play(MageAnims.FIREBALL)
	for i in range(120):
		player._process(0.02)
	player.play(MageAnims.IDLE)
	for i in range(250):
		player._process(0.02)
	var burn: float = float(material.get_shader_parameter("linger"))
	var burn_length: float = float(material.get_shader_parameter("linger_duration"))
	_check(burn >= burn_length,
		"The pit must burn out after the cast, linger is %f of %f" % [burn, burn_length])

	# the pit stays where the fireball landed, and not where the mage is
	var fx_node := mage.get_node_or_null("FireballFX")
	_check(fx_node != null, "The mage scene must carry a FireballFX node")
	if fx_node != null:
		# the driver is put to work by hand, the same way the mage is
		fx_node._ready()
		player.play(MageAnims.FIREBALL)
		for i in range(120):
			player._process(0.02)
			fx_node._process(0.02)
		var landed: Vector2 = mage.to_global(material.get_shader_parameter("pit_pos"))
		# she walks away from the fire
		mage.position.x += 40.0
		fx_node._process(0.02)
		var afterwards: Vector2 = mage.to_global(material.get_shader_parameter("pit_pos"))
		_check(landed.is_equal_approx(afterwards),
			"The pit must stay where the fireball landed, %s and %s"
				% [str(landed), str(afterwards)])
		mage.position.x -= 40.0

	# the fireball is thrown forward, so it sails out in a parabola and never
	# doubles back on the staff it came from
	for perspective in ["front", "back", "left", "right"]:
		var view_info := _make_player(perspective)
		var view_player: MageChoreoPlayer = view_info["player"]
		var view_mage: MageModularBase = view_info["mage"]
		view_player.load_clip(MageAnims.FIREBALL)
		var fx_params: Dictionary = view_player.sample_fx(0.9)
		_check(fx_params.has("arc_height"),
			"[%s] The clip must tell the shader how far the throw arcs" % perspective)
		var spawn: Vector2 = fx_params.get("spawn_pos", Vector2.ZERO)
		var impact: Vector2 = fx_params.get("impact_pos", Vector2.ZERO)
		var arc: float = float(fx_params.get("arc_height", 0.0))

		# it has to be thrown away from the mage, not straight down at her feet
		var feet: Vector2 = view_mage.get_feet_centre()
		_check(absf(impact.x - feet.x) > absf(spawn.x - feet.x) + 8.0,
			"[%s] The fireball must be thrown away from the mage, spawn %s and impact %s"
				% [perspective, str(spawn), str(impact)])

		# the same parabola the shader draws
		var middle := (spawn + impact) * 0.5
		var control := middle + Vector2(0.0, -arc * 2.0)
		var last_x := 0.0
		var last_step := 0.0
		var reversed_sideways := false
		var highest := 9999.0
		var landed := Vector2.ZERO
		for i in range(21):
			var f := float(i) / 20.0
			var u := 1.0 - f
			var p := u * u * spawn + 2.0 * u * f * control + f * f * impact
			if i > 0:
				var step := p.x - last_x
				if last_step != 0.0 and signf(step) != signf(last_step):
					reversed_sideways = true
				last_step = step
			highest = minf(highest, p.y)
			last_x = p.x
			landed = p
		_check(not reversed_sideways,
			"[%s] The fireball must not double back on itself" % perspective)
		_check(highest < spawn.y,
			"[%s] The fireball must arc up out of the staff, it only reached %s"
				% [perspective, str(highest)])
		_check(landed.is_equal_approx(impact),
			"[%s] The fireball must land on the impact point, got %s" % [perspective, str(landed)])

	# the beats have to land in the same place in every view: the ball is
	# summoned into the sky, it falls, it hits the ground, and only then is
	# the pit left burning
	for perspective in ["front", "back", "left", "right"]:
		var view_info := _make_player(perspective)
		var view_player: MageChoreoPlayer = view_info["player"]
		view_player.load_clip(MageAnims.FIREBALL)

		var summoned: Dictionary = view_player.sample_fx(0.40)
		_check(float(summoned["fall"]) <= 0.0,
			"[%s] The fireball must not have fallen when it is summoned" % perspective)
		_check(float(summoned["progress"]) > 0.28,
			"[%s] The fireball must be summoned into the sky" % perspective)

		var landed: Dictionary = view_player.sample_fx(1.26)
		_check(float(landed["fall"]) >= 0.999,
			"[%s] The fireball must be on the ground at the impact, got %s"
				% [perspective, landed["fall"]])
		_check(float(landed["pit_strength"]) <= 0.0,
			"[%s] The pit must not be burning before the fireball lands" % perspective)
		_check(float(view_player.sample_fx(view_player.get_duration())["pit_strength"]) > 0.9,
			"[%s] The pit must be burning once the fireball has landed" % perspective)

		# the values stay inside their range, so the ball cannot sail past the
		# ground and the glow cannot flare past full
		for i in range(21):
			var t := float(i) / 20.0 * view_player.get_duration()
			var sampled: Dictionary = view_player.sample_fx(t)
			_check(float(sampled["fall"]) >= 0.0 and float(sampled["fall"]) <= 1.0,
				"[%s] The fall must stay between 0 and 1 at %.2fs, got %s"
					% [perspective, t, sampled["fall"]])
			_check(float(sampled["gem_glow"]) >= 0.0 and float(sampled["gem_glow"]) <= 1.0,
				"[%s] The gem glow must stay between 0 and 1 at %.2fs, got %s"
					% [perspective, t, sampled["gem_glow"]])
			_check(float(sampled["pit_strength"]) >= 0.0 and float(sampled["pit_strength"]) <= 1.0,
				"[%s] The pit must stay between 0 and 1 at %.2fs, got %s"
					% [perspective, t, sampled["pit_strength"]])

	print("  ✅ PASS: the fireball clip raises the arm, casts the ball and leaves a burning pit")


func _test_smooth_rotation() -> void:
	print("\n[TEST 12] A turning piece is filtered smoothly, a still one stays crisp:")
	var player_info := _make_player("right")
	var player: MageChoreoPlayer = player_info["player"]
	var mage: MageModularBase = player_info["mage"]
	var staff: Sprite2D = mage.get_piece("staff")
	var body: Sprite2D = mage.get_piece("body")

	# the idle only nudges the staff, so it must stay crisp
	player.load_clip(MageAnims.IDLE)
	_check(staff.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"The idle must leave the staff crisp, got %d" % staff.texture_filter)

	# the cast turns the staff right down, so it has to be filtered smoothly
	player.load_clip(MageAnims.CAST)
	_check(staff.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
		"The cast must filter the staff smoothly, got %d" % staff.texture_filter)
	_check(body.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"The body never turns, so it must stay crisp")

	# and the fireball turns the arm too
	player.load_clip(MageAnims.FIREBALL)
	var arm: Sprite2D = mage.get_piece("arm_left")
	_check(arm.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
		"The fireball must filter the arm smoothly, got %d" % arm.texture_filter)

	# the whole thing can be switched off
	player.smooth_rotation = false
	player.load_clip(MageAnims.FIREBALL)
	_check(arm.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"Turning smooth filtering off must leave every piece crisp")
	print("  ✅ PASS: only the pieces that really turn are filtered smoothly")


func _test_energy_barrier() -> void:
	print("\n[TEST 13] The energy barrier:")
	var player_info := _make_player("front")
	var player: MageChoreoPlayer = player_info["player"]
	var mage: MageModularBase = player_info["mage"]

	_check(MageAnims.BARRIER == "mage_energy_barrier", "The barrier name must be stable")
	_check(MageAnims.all().has(MageAnims.BARRIER), "all() must list the barrier")
	_check(FileAccess.file_exists(MageAnims.clip_path(MageAnims.BARRIER)),
		"The barrier clip file must exist")
	_check(player.load_clip(MageAnims.BARRIER), "The barrier clip must load")

	var fx := mage.get_node_or_null("BarrierFX")
	_check(fx != null, "The mage scene must carry a BarrierFX node")
	var material := fx.material as ShaderMaterial
	_check(material != null, "BarrierFX must carry a ShaderMaterial")
	_check(material.shader != null and material.shader.resource_path.ends_with("mage_energy_barrier.gdshader"),
		"BarrierFX must use the barrier shader")

	# the ground ring finishes before the dome does
	var early := player.sample_fx(0.22)
	var late := player.sample_fx(player.get_duration())
	_check(float(early["ground_progress"]) > float(early["progress"]),
		"The ground ring must form faster than the dome")
	_check(float(late["ground_progress"]) >= 0.999, "The ground ring must be finished")
	_check(float(late["progress"]) >= 0.999, "The dome must be closed at the end")

	# it stays up after the clip, until it is dismissed
	player.scrub_time(player.get_duration())
	_check(player.dismiss_effect(), "The barrier must know how to dismiss itself")
	_check(fx.is_dismissing(), "The barrier must start fading when dismissed")
	player.restore_effect()
	_check(not fx.is_dismissing(), "The barrier must be restorable")
	print("  ✅ PASS: the barrier forms, holds and can be dismissed")


func _test_no_stops_at_keys() -> void:
	print("\n[TEST 14] The motion carries straight through a key:")
	var player_info := _make_player("front")
	var player: MageChoreoPlayer = player_info["player"]
	player.load_clip(MageAnims.BARRIER)

	# the clip has a key in the middle, and the curve must not slow to a stop
	# on it. A stepped curve would have almost no movement either side of it.
	var keys: Array = player.clip_data.get("keys", [])
	_check(keys.size() >= 2, "The barrier clip must have keys")
	var key_time := float(keys[1]["time"])
	var before: float = float(player.sample_fx(key_time - 0.02).get("progress", 0.0))
	var after: float = float(player.sample_fx(key_time + 0.02).get("progress", 0.0))
	var moved := absf(float(after) - float(before))
	_check(moved > 0.01,
		"The motion must not stop on a key, only %f of progress across it" % moved)

	# and the same for a piece rotation, where a stop would be very visible
	var arm_before: Dictionary = player.sample(key_time - 0.02)
	var arm_after: Dictionary = player.sample(key_time + 0.02)
	_check(arm_before.has("torso") and arm_after.has("torso"),
		"The sampled poses must carry the animated targets")

	# a clip defaults to smooth sampling, and the stepped sampler still works
	# for anyone who wants the old hold on every key
	_check(player._interpolation == "smooth", "A clip must default to smooth sampling")
	var stepped: Dictionary = player._sample_eased(key_time)
	_check(stepped.has("torso"), "The stepped sampler must still be available")
	print("  ✅ PASS: the curve carries through the keys with no stops")


func _test_meteorite() -> void:
	print("\n[TEST 15] The meteorite:")
	var player_info := _make_player("right")
	var player: MageChoreoPlayer = player_info["player"]
	var mage: MageModularBase = player_info["mage"]

	_check(MageAnims.METEORITE == "mage_meteorite", "The meteorite name must be stable")
	_check(MageAnims.all().has(MageAnims.METEORITE), "all() must list the meteorite")
	_check(FileAccess.file_exists(MageAnims.clip_path(MageAnims.METEORITE)),
		"The meteorite clip file must exist")
	_check(player.load_clip(MageAnims.METEORITE), "The meteorite clip must load")

	# every perspective has to carry the effect
	for view in ["front", "back", "left", "right"]:
		var other: MageModularBase = ModularMageUtility.instantiate_mage(view)
		root.add_child(other)
		other._ready()
		var node := other.get_node_or_null("MeteoriteFX")
		_check(node != null, "The %s mage must carry a MeteoriteFX node" % view)
		if node != null:
			var mat := node.material as ShaderMaterial
			_check(mat != null and mat.shader != null \
				and mat.shader.resource_path.ends_with("mage_meteorite.gdshader"),
				"The %s MeteoriteFX must use the meteorite shader" % view)

	var fx := mage.get_node_or_null("MeteoriteFX")
	var material := fx.material as ShaderMaterial
	_check(material != null, "MeteoriteFX must carry a ShaderMaterial")

	# the mage leaves the ground and comes back
	var up := player.sample(2.5)
	var up_root: Dictionary = up.get("root", {})
	_check(float(up_root.get("pos", Vector2.ZERO).y) < -40.0,
		"The mage must float well above the ground while she calls the meteorite")
	var down := player.sample(player.get_duration())
	var down_root: Dictionary = down.get("root", {})
	_check(absf(float(down_root.get("pos", Vector2.ZERO).y)) < 1.0,
		"The mage must be back on the ground at the end")

	# the arm and the staff go up, and the gem lights up
	var staff: Dictionary = up.get("staff", {})
	_check(up.has("staff"), "The staff must be part of the sampled pose")
	_check(float(staff.get("rot", 0.0)) != 0.0, "The staff must be turned while she floats")
	var glow := player.sample_fx(3.0)
	_check(float(glow.get("gem_glow", 0.0)) > 0.5, "The gem on the staff must light up")
	_check(float(player.sample_fx(0.2).get("gem_glow", 0.0)) < 0.1,
		"The gem must not be lit before the cast starts")

	# the rock comes down
	var high := player.sample_fx(3.0)
	var low := player.sample_fx(5.08)
	_check(float(high["meteor_y"]) > 100.0, "The meteorite must start high in the sky")
	_check(float(low["meteor_y"]) < 1.0, "The meteorite must reach the ground")
	_check(float(player.sample_fx(2.0)["meteor_y"]) >= float(high["meteor_y"]),
		"The meteorite must wait in the sky until the cast begins")

	# it must come down slowly enough to be worth watching
	var fall_start := float(player.sample_fx(3.0)["meteor_y"])
	var fall_end := float(player.sample_fx(5.08)["meteor_y"])
	var fall_time := 5.08 - 3.0
	var draft_time := 0.95
	_check(fall_time > draft_time * 1.5,
		"The meteorite must come down 40%% slower, %f seconds instead of %f" % [fall_time, draft_time])
	_check(fall_start > 0.0 and fall_end <= 1.0, "The meteorite must come all the way down")

	# it hits, and the pillar of fire goes up.  The old mushroom cloud is
	# gone: the pillar is a thing in the world now, not a picture on her.
	_check(float(player.sample_fx(5.2)["spawn"]) > 0.5, "The pillar of fire must go off")
	_check(float(player.sample_fx(4.0)["spawn"]) < 0.2, "The pillar of fire must not start early")
	_check(float(player.sample_fx(5.2)["explode"]) < 0.01,
		"The old mushroom cloud must not be drawn as well")
	# the screen goes down as the meteor is summoned
	_check(float(player.sample_fx(0.0)["dim"]) < 0.01,
		"The screen must start bright")
	_check(float(player.sample_fx(0.6)["dim"]) > 0.35,
		"The screen must be down while the meteor is called")
	_check(float(player.sample_fx(4.9)["dim"]) > 0.35,
		"The screen must stay down until the meteor lands")
	# and the site of the impact is written down
	_check(float(player.sample_fx(5.08)["meteor_x"]) > 0.0,
		"The site of the meteor's impact must be written down")

	# The cloud does not wait for her.  It keeps going for two seconds after
	# it has reached full size, long after she has come back down.
	_check(float(player.sample_fx(5.1)["cloud_age"]) < 0.05,
		"The cloud must be at its biggest just after the blast")
	_check(float(player.sample_fx(6.45)["cloud_age"]) > 0.4,
		"The cloud must still be going while she is coming down")
	_check(float(player.sample_fx(6.45).get("root", {}).get("pos", Vector2.ZERO).y) > -5.0,
		"She must be back on the ground while the cloud is still going")
	_check(float(player.sample_fx(player.get_duration())["cloud_age"]) >= 0.999,
		"The cloud must have merged with the air by the end")
	_check(player.get_duration() > 6.0,
		"The clip must run on long enough for the cloud to finish")

	# the camera is asked to shake while the rock falls
	_check(float(player.sample_fx(4.7)["camera_shake"]) > 0.5,
		"The camera must be asked to shake as the rock falls")
	player.scrub_time(4.2)
	_check(player.get_camera_shake() > 0.5, "The player must report the camera shake")
	_check(float(player.sample_fx(0.2)["camera_shake"]) < 0.05,
		"The camera must not shake before the rock starts falling")

	# she only comes down half a second after the blast
	_check(float(player.sample(5.2).get("root", {}).get("pos", Vector2.ZERO).y) < -40.0,
		"The mage must still be in the air half a second after the blast")
	_check(float(player.sample(6.45).get("root", {}).get("pos", Vector2.ZERO).y) > -5.0,
		"The mage must be back on the ground by the end")

	_check(player.get_duration() > 4.0, "The cast must last over four seconds")
	print("  ✅ PASS: the mage leaps, calls the meteorite and comes back down")


func _test_root_motion() -> void:
	print("\n[TEST 16] The mage can leave the ground:")
	var player_info := _make_player("front")
	var player: MageChoreoPlayer = player_info["player"]
	var mage: MageModularBase = player_info["mage"]
	player.load_clip(MageAnims.METEORITE)

	# the whole mage has to move, not just one of its pieces
	var rest_y := mage.position.y
	player.scrub_time(2.5)
	_check(mage.position.y < rest_y - 40.0,
		"The mage must actually be lifted off the ground")
	player.scrub_time(0.0)
	_check(absf(mage.position.y - rest_y) < 0.5,
		"The mage must be back where it started")

	# and the cut in the character shader has to be measured in the mage's own
	# space, or a mage standing far from the origin dissolves away
	mage.position = Vector2(mage.position.x, 2000.0)
	player.scrub_time(0.0)
	var body: Sprite2D = mage.get_piece("body")
	_check(body != null and body.visible and body.modulate.a > 0.99,
		"The mage must still be whole when it stands far from the origin")
	print("  ✅ PASS: the mage leaves the ground and stays whole wherever it stands")


func _test_playback_speed() -> void:
	print("\n[TEST 17] The clip can be slowed down:")
	var player_info := _make_player("front")
	var player: MageChoreoPlayer = player_info["player"]
	player.load_clip(MageAnims.METEORITE)
	player.play(MageAnims.METEORITE)

	# the speed is readable and writable
	_check(player.get_playback_speed() == 1.0, "A clip must start at normal speed")
	player.set_playback_speed(0.25)
	_check(player.get_playback_speed() == 0.25, "The speed must be readable back")
	player.set_playback_speed(-3.0)
	_check(player.get_playback_speed() == 0.0, "The speed must not go negative")

	# and it must actually slow the clip down
	player.set_playback_speed(0.5)
	player.scrub_time(0.0)
	player.is_playing = true
	player.manual_scrub = false
	player._process(0.4)
	_check(absf(player.elapsed - 0.2) < 0.001,
		"Half speed must move the clip half as far, moved %f" % player.elapsed)

	player.set_playback_speed(1.0)
	player.scrub_time(0.0)
	player.is_playing = true
	player.manual_scrub = false
	player._process(0.4)
	_check(absf(player.elapsed - 0.4) < 0.001,
		"Full speed must move the clip the whole way, moved %f" % player.elapsed)

	# a clip can be seeked through without stopping it, so slow motion can be
	# used while it is running
	player.scrub(0.5, true)
	_check(player.is_playing, "Seeking must not stop a running clip")
	_check(absf(player.get_progress() - 0.5) < 0.01, "Seeking must land on the right spot")
	player.scrub(0.5)
	_check(not player.is_playing, "A plain scrub must still stop the clip")
	print("  ✅ PASS: the clip can be slowed down and seeked through while it runs")


func _test_gem_detection() -> void:
	print("\n[TEST 18] The gem is found in the art:")
	for view in ["front", "back", "left", "right"]:
		var info := _make_player(view)
		var mage: MageModularBase = info["mage"]
		var staff: Sprite2D = mage.get_piece("staff")
		_check(mage.piece_gems.has("staff"), "[%s] The staff must have a gem found in it" % view)
		if not mage.piece_gems.has("staff"):
			continue
		var offset: Vector2 = mage.piece_gems["staff"]

		# the gem has to be sitting on the red gem in the picture.  The middle
		# of the gem can fall between pixels, so the pixels around it are
		# looked at too.
		var pivot: Vector2 = mage.piece_pivots.get("staff", Vector2.ZERO)
		var spot: Vector2 = staff.region_rect.position + pivot + offset
		var image: Image = staff.texture.get_image()
		var on_gem := false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var c: Color = image.get_pixel(int(spot.x) + dx, int(spot.y) + dy)
				if c.r > 0.75 and c.g <= 0.55 and (c.r - c.g) > 0.35:
					on_gem = true
		_check(on_gem, "[%s] The gem must sit on the red gem in the art" % view)
		_check(offset.length() < 20.0, "[%s] The gem must be near the staff" % view)

		# and it has to follow the staff when the staff is turned
		var before := mage.get_gem_position()
		mage.rotate_piece("staff", 0.6)
		var after := mage.get_gem_position()
		_check(before.distance_to(after) > 0.5,
			"[%s] The gem must follow the staff as it turns" % view)
	print("  ✅ PASS: the gem is found in the pixels and follows the staff")


func _test_scaled_root_motion() -> void:
	print("\n[TEST 19] The mage travels the whole way, however big she is:")
	var info := _make_player("front")
	var mage: MageModularBase = info["mage"]
	var player: MageChoreoPlayer = info["player"]
	player.load_clip(MageAnims.METEORITE)

	# she floats 48 of her own pixels, which is four times as far when she is
	# drawn four times as big
	mage.scale = Vector2(4, 4)
	var rest_y := mage.position.y
	player.scrub_time(2.5)
	var travelled := rest_y - mage.position.y
	_check(travelled > 180.0,
		"The mage must travel the whole distance when she is scaled up, moved %f" % travelled)
	player.scrub_time(0.0)
	_check(absf(mage.position.y - rest_y) < 0.5, "The mage must come back to where she started")

	# and the place her feet are comes from the rig, not from a number
	var feet := mage.get_feet_centre()
	_check(feet.x > 0.0 and feet.y > 20.0, "The feet's place must come from the rig")
	print("  ✅ PASS: the mage travels the whole distance and her feet are found in the rig")


func _test_character_controller() -> void:
	print("\n[TEST 20] The shared controller and the universal motor:")
	# the motor holds the controller, and the controller holds the rigs
	var motor := UniversalMotor.new()
	var controller := MageController.new()
	motor.add_child(controller)
	root.add_child(motor)
	# the tree is not running yet inside the test, so the ready work is done
	# by hand
	controller._ready()
	motor._ready()

	_check(controller.rigs.size() == 4, "The controller must own a rig per perspective")
	_check(controller.players.size() == 4, "The controller must own a player per perspective")

	# only one rig is on show, and it is the one the character is facing
	controller.set_facing(Vector2.UP)
	_check(controller.active_perspective == "back", "Facing up must show the back rig")
	controller.set_facing(Vector2.DOWN)
	_check(controller.active_perspective == "front", "Facing down must show the front rig")
	controller.set_facing(Vector2.LEFT)
	_check(controller.active_perspective == "left", "Facing left must show the left rig")
	var shown: int = 0
	for key in controller.rigs:
		if (controller.rigs[key] as Node2D).visible:
			shown += 1
	_check(shown == 1, "Only one rig may be on show, %d were" % shown)

	# the motor drives it
	_check(motor.controller == controller, "The motor must find its controller")
	motor.set_direction(Vector2.RIGHT)
	for i in range(30):
		motor._process(1.0 / 60.0)
	_check(controller.get_facing().x > 0.9, "The character must turn to face the way it is going")
	_check(motor.position.x > 1.0, "The motor must move the character")
	_check(controller.is_walking, "The character must be walking")

	# The motor owns the character's place in the world, and a clip owns the
	# rig's own place.  They must never fight over the same value.
	var rig: Node2D = controller.active_rig
	var motor_y: float = motor.position.y
	controller.play_action(MageAnims.METEORITE)
	var player: MageChoreoPlayer = controller.active_player as MageChoreoPlayer
	_check(player != null, "The controller must give out a usable player")
	if player != null:
		player.scrub_time(2.5)
		_check(rig.position.y < -40.0, "The clip must be able to lift the rig off the ground")
		_check(is_equal_approx(motor.position.y, motor_y),
			"The clip must not move the character around the map")
	print("  ✅ PASS: the controller shows one rig and the motor drives it")


func _test_walk_cycle() -> void:
	print("\n[TEST 21] The walk cycle:")
	_check(MageAnims.WALK == "mage_walk", "The walk name must be stable")
	_check(MageAnims.all().has(MageAnims.WALK), "all() must list the walk")
	_check(FileAccess.file_exists(MageAnims.clip_path(MageAnims.WALK)),
		"The walk clip file must exist")

	for view in ["front", "back", "left", "right"]:
		var player_info := _make_player(view)
		var player: MageChoreoPlayer = player_info["player"]
		_check(player.load_clip(MageAnims.WALK), "[%s] The walk clip must load" % view)
		_check(player.clip_data.get("loop", false), "[%s] The walk must loop" % view)

		# the boots must move, and they must move in opposition
		var first: Dictionary = player.sample(0.0)
		var quarter: Dictionary = player.sample(0.15)
		var three_quarters: Dictionary = player.sample(0.45)
		_check(first.has("foot_a") and first.has("foot_b"),
			"[%s] The walk must animate both boots" % view)
		var a0: Vector2 = first["foot_a"]["pos"]
		var b0: Vector2 = first["foot_b"]["pos"]
		var a1: Vector2 = quarter["foot_a"]["pos"]
		var b1: Vector2 = quarter["foot_b"]["pos"]
		_check(not a0.is_equal_approx(a1) or not b0.is_equal_approx(b1),
			"[%s] The boots must move while she walks" % view)
		# one boot leads and the other follows, so they travel in opposite
		# directions.  The side views show it sideways, the front and back
		# views show it as a lift.
		var a_move: Vector2 = three_quarters["foot_a"]["pos"] - a1
		var b_move: Vector2 = three_quarters["foot_b"]["pos"] - b1
		_check(a_move.dot(b_move) < 0.0,
			"[%s] The two boots must swing in opposition, %s and %s" % [view, str(a_move), str(b_move)])

		# the body must ride up and down with them
		var body: Vector2 = first["torso"]["pos"]
		var body_mid: Vector2 = player.sample(0.075)["torso"]["pos"]
		_check(not body.is_equal_approx(body_mid), "[%s] The body must bob while she walks" % view)

		# and the loop must meet itself
		var last: Dictionary = player.sample(player.get_duration())
		var l0: Vector2 = last["foot_a"]["pos"]
		_check(l0.is_equal_approx(a0), "[%s] The walk must come back to where it started" % view)
	print("  ✅ PASS: the boots swing in opposition and the loop closes in every view")


func _test_contact_shadow() -> void:
	print("\n[TEST 22] The contact shadow:")
	for perspective in ["front", "back", "left", "right"]:
		var player_info := _make_player(perspective)
		var mage: MageModularBase = player_info["mage"]

		# the shadow has to be on the mage, or she floats on the ground
		var shadow := mage.get_node_or_null("ShadowFX")
		_check(shadow != null, "[%s] The mage scene must carry a ShadowFX node" % perspective)
		if shadow == null:
			continue
		var material := shadow.material as ShaderMaterial
		_check(material != null, "[%s] The shadow must carry a ShaderMaterial" % perspective)
		_check(material != null and material.shader != null
				and material.shader.resource_path.ends_with("mage_shadow.gdshader"),
			"[%s] The shadow must use the shadow shader" % perspective)

		# the driver is put to work by hand, the same way the mage is
		shadow._ready()

		# and it has to sit under her feet
		shadow._process(0.016)
		var feet: Vector2 = mage.get_feet_centre()
		var centre: Vector2 = shadow.position + shadow.size * 0.5
		_check(absf(centre.x - feet.x) < 0.01,
			"[%s] The shadow must sit under her feet, at %s and %s"
				% [perspective, str(centre.x), str(feet.x)])
		_check(absf(centre.y - 32.0) < 0.01,
			"[%s] The shadow must sit on the ground, at %s" % [perspective, str(centre.y)])

		# while she is in the air it spreads out and fades, the way a shadow
		# does when its caster moves away from the ground
		var radius: float = float(material.get_shader_parameter("radius"))
		var opacity: float = float(material.get_shader_parameter("opacity"))
		mage.position.y -= 40.0
		shadow._process(0.016)
		_check(float(material.get_shader_parameter("radius")) > radius,
			"[%s] The shadow must spread out while she is in the air" % perspective)
		_check(float(material.get_shader_parameter("opacity")) < opacity,
			"[%s] The shadow must fade while she is in the air" % perspective)
	print("  ✅ PASS: the mage stands on a shadow that follows her feet")


func _test_gem_light() -> void:
	print("\n[TEST 23] The gem lights the mage:")
	var player_info := _make_player("front")
	var player: MageChoreoPlayer = player_info["player"]
	var mage: MageModularBase = player_info["mage"]

	# the character material is the one every piece shares
	var staff: Sprite2D = mage.get_piece("staff")
	_check(staff != null and staff.material is ShaderMaterial,
		"The staff must carry the character clip material")
	if staff == null or not staff.material is ShaderMaterial:
		return
	var material := staff.material as ShaderMaterial

	# while the fireball is charging, the gem lights her up
	player.play(MageAnims.FIREBALL)
	player.scrub_time(0.6)
	_check(float(material.get_shader_parameter("gem_glow")) > 0.5,
		"The gem's light must reach the mage while the fireball is charging")

	# and the light knows where the gem is, so it follows the staff
	var gem: Vector2 = material.get_shader_parameter("gem_pos")
	_check(gem.is_equal_approx(mage.get_gem_position()),
		"The light must know where the gem is, at %s and %s"
			% [str(gem), str(mage.get_gem_position())])

	# and it goes out again with the gem
	player.scrub_time(player.get_duration())
	_check(float(material.get_shader_parameter("gem_glow")) <= 0.01,
		"The light must go out with the gem")
	print("  ✅ PASS: the gem lights the mage while the spell is charging")
