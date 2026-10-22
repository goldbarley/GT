extends SceneTree

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	print("--- Testing ArcherShowcase.tscn ---")
	var scene: PackedScene = load("res://scenes/ArcherShowcase.tscn")
	assert(scene != null, "Failed to load ArcherShowcase.tscn")
	var showcase = scene.instantiate()
	root.add_child(showcase)
	await process_frame
	
	# Check buttons
	assert(showcase.btn_play_attack != null, "btn_play_attack is null")
	assert(showcase.btn_play_skill != null, "btn_play_skill is null")
	assert(showcase.btn_play_strong_skill != null, "btn_play_strong_skill is null")
	assert(showcase.btn_play_shot != null, "btn_play_shot is null")
	assert(showcase.btn_play_idle != null, "btn_play_idle is null")
	assert(showcase.btn_play_walk != null, "btn_play_walk is null")
	print("✓ All Showcase buttons instantiated and found successfully")

	var player: ArcherChoreoPlayer = showcase.players[0]
	var rig: ArcherModularBase = showcase.archers[0]
	var bow = rig.get_piece("bow")

	# Test Basic Attack
	print("Testing Basic Attack button press...")
	showcase.btn_play_attack.emit_signal("pressed")
	assert(showcase.active_clip == ArcherAnims.BASIC_ATTACK, "Active clip should be BASIC_ATTACK")
	# Scrub to arm raise / frame 10 (t=0.17s)
	player.scrub_percent(35.0, true)
	print("  Basic Attack bow rotation at aim: %f rad (%f deg)" % [bow.rotation, rad_to_deg(bow.rotation)])
	# Advance to impact (t=0.25s)
	player.scrub_percent(55.0, true)
	# Check spawned arrow
	var arrows := showcase.find_children("*", "ArrowProjectile", true, false)
	assert(not arrows.is_empty(), "ArrowProjectile should be spawned")
	var basic_arrow: ArrowProjectile = arrows[-1]
	print("  Arrow direction: %s, rotation: %f deg" % [basic_arrow.direction, rad_to_deg(basic_arrow.rotation)])
	assert(absf(basic_arrow.direction.y) < 0.001, "Arrow direction must be parallel to the ground (y=0)")
	assert(absf(basic_arrow.rotation) < 0.001, "Arrow rotation must be parallel to the ground (0 deg)")
	print("✓ Basic Attack played and fired parallel to ground successfully")

	# Test Skill
	print("Testing Skill button press...")
	showcase.btn_play_skill.emit_signal("pressed")
	assert(showcase.active_clip == ArcherAnims.SKILL, "Active clip should be SKILL")
	player.scrub_percent(50.0, true) # past impact
	arrows = showcase.find_children("*", "ArrowProjectile", true, false)
	var skill_arrow: ArrowProjectile = arrows[-1]
	print("  Skill Arrow direction: %s, rotation: %f deg" % [skill_arrow.direction, rad_to_deg(skill_arrow.rotation)])
	assert(absf(skill_arrow.direction.y) < 0.001, "Skill Arrow must be parallel to the ground")
	assert(absf(skill_arrow.rotation) < 0.001, "Skill Arrow rotation must be 0 deg")
	print("✓ Skill played and fired parallel to ground successfully")

	# Test Strong Skill
	print("Testing Strong Skill button press...")
	showcase.btn_play_strong_skill.emit_signal("pressed")
	assert(showcase.active_clip == ArcherAnims.STRONG_SKILL, "Active clip should be STRONG_SKILL")
	player.scrub_percent(70.0, true) # past impact
	var charged_arrows := showcase.find_children("*", "ChargedArrowProjectile", true, false)
	assert(not charged_arrows.is_empty(), "ChargedArrowProjectile should be spawned")
	var strong_arrow: ChargedArrowProjectile = charged_arrows[-1]
	print("  Strong Skill Arrow direction: %s, rotation: %f deg" % [strong_arrow.direction, rad_to_deg(strong_arrow.rotation)])
	assert(absf(strong_arrow.direction.y) < 0.001, "Strong Skill Arrow must be parallel to the ground")
	assert(absf(strong_arrow.rotation) < 0.001, "Strong Skill Arrow rotation must be 0 deg")
	print("✓ Strong Skill played and fired parallel to ground successfully")

	# Test Ultimate
	print("Testing Ultimate button press...")
	showcase.btn_play_shot.emit_signal("pressed")
	assert(showcase.active_clip == ArcherAnims.CHARGED_SHOT, "Active clip should be CHARGED_SHOT")
	# At hold/release (around 70%-80% progress)
	player.scrub_percent(75.0, true)
	print("  Ultimate bow rotation at draw/hold: %f rad (%f deg)" % [bow.rotation, rad_to_deg(bow.rotation)])
	# Bow rotation in ultimate should NOT have -35° applied (it was -30° in rest, 0 relative to aim)
	assert(absf(rad_to_deg(bow.rotation) - (-35.0)) > 2.0, "Ultimate bow must NOT have -35 deg tilt applied")
	player.scrub_percent(80.0, true) # past impact
	var beams := showcase.find_children("*", "ArcherBeam", true, false)
	assert(not beams.is_empty(), "ArcherBeam should be spawned")
	var beam: ArcherBeam = beams[-1]
	print("  Beam rotation: %f deg" % [rad_to_deg(beam.rotation)])
	assert(absf(beam.rotation) < 0.05, "Beam rotation must be horizontal")
	print("✓ Ultimate played successfully and beam is horizontal")

	# Test ArcherController directly
	print("Testing ArcherController...")
	var controller := ArcherController.new()
	root.add_child(controller)
	await process_frame
	controller.play_basic_attack()
	controller.play_skill()
	controller.play_strong_skill()
	controller.play_charged_shot()
	print("✓ ArcherController skill & attack methods executed successfully")

	print("--- All Archer Skill & Attack tests passed! ---")
	quit(0)
