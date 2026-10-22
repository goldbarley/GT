extends Node

## Renders the Knight showcase with the ultimate playing, so the four views
## can be looked at together, the way the reference drawing shows them.

func _ready() -> void:
	var showcase: Node = load("res://scenes/KnightShowcase.tscn").instantiate()
	add_child(showcase)
	await get_tree().process_frame
	await get_tree().process_frame
	# cast the ultimate in every view
	for player: KnightChoreoPlayer in showcase.get("players"):
		player.play(KnightAnims.ULTIMATE)
		player.manual_scrub = true
	# and scrub it to the moment the fire is at its fullest
	var best := 0.0
	var best_score := -1.0
	for player: KnightChoreoPlayer in showcase.get("players"):
		for i in range(80):
			var t: float = float(i) / 79.0 * player.get_duration()
			var params: Dictionary = player.sample_fx(t)
			var slash := float(params.get("slash", 0.0))
			var slash_t := float(params.get("slash_t", 0.0))
			var score := slash - absf(slash_t - 0.42)
			if score > best_score:
				best_score = score
				best = t
	for player: KnightChoreoPlayer in showcase.get("players"):
		player.elapsed = best
		player.evaluate(best)
	print("scrubbed to t=%.2f" % best)
	# let the effect place the fire first
	for i in range(4):
		await get_tree().process_frame
	# take the darkness away, so the knight and the fire can be seen together
	for rig in showcase.get("rigs"):
		var dark: Node = rig.get_node_or_null("KnightUltimateDarkLayer/KnightUltimateDark")
		var fx: Node = rig.get_node_or_null("KnightUltimateLayer/KnightUltimateFX")
		if fx != null:
			fx.process_mode = Node.PROCESS_MODE_DISABLED
		if dark != null:
			dark.visible = false
	for rig in showcase.get("rigs"):
		var fx: Node = rig.get_node_or_null("KnightUltimateLayer/KnightUltimateFX")
		var dark: Node = rig.get_node_or_null("KnightUltimateDarkLayer/KnightUltimateDark")
		print(rig.name, " fx ", fx != null, " dark ", dark != null,
			" dim ", (dark.material as ShaderMaterial).get_shader_parameter("dim") if dark != null else -1,
			" visible ", dark.visible if dark != null else false,
			" fx dim ", (fx.material as ShaderMaterial).get_shader_parameter("dim") if fx != null else -1,
			" fx slash ", (fx.material as ShaderMaterial).get_shader_parameter("slash") if fx != null else -1)
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	image.save_png("/tmp/opencode/showcase_edge.png")
	print("wrote the render: ", image.get_size())
	get_tree().quit(0)
