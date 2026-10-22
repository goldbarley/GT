extends Node2D

## Probes the difference between the animation maths and the rasteriser.
##
## Steps a clip at 60fps and reports, for each frame, the transform the player
## computed and how many pixels actually changed on screen.
##
## The transform is always perfectly smooth.  The pixel count is not: a
## continuous rotation still has to land on the pixel grid, so with nearest
## neighbour filtering several hundred pixels swap to a completely different
## texel every frame.  That swap is what reads as a stutter, and it is a
## rasterising problem, not an animation one.
##
## Run with:  godot --path . res://scenes/MageMotionProbe.tscn

var _mage: MageModularBase
var _player: MageChoreoPlayer


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mage = ModularMageUtility.instantiate_mage("right")
	_mage.scale = Vector2(6, 6)
	_mage.position = Vector2(100, 200)
	add_child(_mage)
	_player = MageChoreoPlayer.new()
	_player.target = _mage
	add_child(_player)
	_player.load_clip("mage_fireball")
	print("FILTER: ", "LINEAR (smooth)" if _player.smooth_rotation else "NEAREST (crisp)")

	var staff: Sprite2D = _mage.get_piece("staff")
	var previous: Image = null
	var region := Rect2i(60, 120, 260, 260)

	print("\n frame |  rotation (deg) | position        | pixels changed")
	print("-------+-----------------+-----------------+---------------")
	for i in range(10):
		var t: float = 0.60 + float(i) / 60.0
		_player.scrub_time(t)
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		var crop: Image = img.get_region(region)
		var changed := -1
		var delta := 0.0
		if previous != null:
			changed = 0
			var a := previous.get_data()
			var b := crop.get_data()
			for p in range(0, a.size(), 4):
				var d: int = absi(int(a[p]) - int(b[p])) + absi(int(a[p+1]) - int(b[p+1])) + absi(int(a[p+2]) - int(b[p+2]))
				if d > 0:
					changed += 1
				delta += float(d)
		previous = crop
		print("  %2d   |  %8.4f      | %-14s  | %5d px changed, %8.0f total colour shift" % [i, rad_to_deg(staff.rotation), str(staff.position), changed, delta])
	get_tree().quit(0)
