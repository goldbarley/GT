extends Node2D

## Renders one view of the knight with the fire in front of his face, so the
## placement can be looked at.
##
##   godot ... RenderEdge.tscn -- <view>

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var args := OS.get_cmdline_user_args()
	var view: String = args[0] if args.size() > 0 else "right"
	var scene := load("res://Knight/Knight_%s/Knight%s.tscn" % [view, view.capitalize()]) as PackedScene
	var rig := scene.instantiate() as KnightModularBase
	rig.scale = Vector2(8, 8)
	rig.position = Vector2(150, 380)
	add_child(rig)
	var player := KnightChoreoPlayer.new()
	player.target = rig
	add_child(player)
	player.play(KnightAnims.ULTIMATE)
	player.manual_scrub = true
	# find the moment the fire is at its fullest
	var best := 0.0
	var best_score := -1.0
	for i in range(80):
		var t := float(i) / 79.0 * player.get_duration()
		var params: Dictionary = player.sample_fx(t)
		var slash := float(params.get("slash", 0.0))
		var slash_t := float(params.get("slash_t", 0.0))
		var score := slash - absf(slash_t - 0.42)
		if score > best_score:
			best_score = score
			best = t
	player.elapsed = best
	player.evaluate(best)
	print("%s: t=%.2f  %s" % [view, best, str(player.sample_fx(best))])

	for i in range(4):
		await get_tree().process_frame

	# freeze the effect and take the darkness away, so the knight and the
	# fire can be looked at together
	var fx: Node = rig.get_node_or_null("KnightUltimateLayer/KnightUltimateFX")
	var dark: Node = rig.get_node_or_null("KnightUltimateLayer/KnightUltimateDark")
	if dark != null:
		dark.visible = false
	if fx != null:
		fx.process_mode = Node.PROCESS_MODE_DISABLED
		var mat := fx.material as ShaderMaterial
		print("origin ", mat.get_shader_parameter("origin"))
		print("rotation ", mat.get_shader_parameter("rotation"))
		print("scale ", mat.get_shader_parameter("scale"))
		print("mirror ", mat.get_shader_parameter("mirror"))
		print("art_mouth ", mat.get_shader_parameter("art_mouth"))

	for i in range(3):
		await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	image.save_png("/tmp/opencode/edge_%s.png" % view)
	print("wrote the render: ", image.get_size())
	get_tree().quit(0)
