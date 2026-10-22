extends Node2D

## Compares how much pixel art churns per frame when it turns.
##
## A piece boils when the pixels at its far end travel more than about half a
## pixel per frame, because nearest neighbour sampling then has to pick a
## different texel every frame:
##
##     tip travel per frame = radius from the pivot * radians per frame
##
## The archer keeps that number small by using short segments and modest
## rotation speeds. This probe puts the archer's draw arm and the mage's staff
## side by side, each turning at the rate it actually uses, and counts the
## pixels that change on screen every frame.
##
## Run with:  godot --path . res://scenes/MageBoilProbe.tscn

const SAMPLES := 6


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# the archer's draw arm: 26 degrees over 0.4s, a 5x10 segment, far end ~7px out
	var archer := _make_piece("res://sprites/archer_placeholder/arm_upper.png",
			Vector2(200, 100), Rect2(), 7.0)
	# the mage's staff during the cast: an 18x20 piece whose far end is ~13px out
	var mage := _make_piece("res://Mage/mage_right/Mage_right_clean.png",
			Vector2(200, 220), Rect2(27, 0, 18, 20), 13.0)

	await get_tree().process_frame
	var previous := _grab()
	print("\n  piece        | deg/frame | tip travel/frame | pixels changed/frame")
	print("---------------+-----------+------------------+--------------------")
	for i in range(SAMPLES):
		archer.rotation += deg_to_rad(1.1)
		mage.rotation += deg_to_rad(3.2)
		await RenderingServer.frame_post_draw
		var current := _grab()
		print("  archer arm   |   %5.2f   |      %5.2f px    |        %d"
				% [1.1, 7.0 * deg_to_rad(1.1), _count(previous, current)])
		print("  mage staff   |   %5.2f   |      %5.2f px    |        %d"
				% [3.2, 13.0 * deg_to_rad(3.2), _count(previous, current)])
		previous = current
	get_tree().quit(0)


func _make_piece(texture_path: String, pos: Vector2, region: Rect2, radius: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(texture_path)
	if region.size != Vector2.ZERO:
		s.region_enabled = true
		s.region_rect = region
		s.centered = false
		s.offset = Vector2(-region.size.x * 0.5, -region.size.y * 0.5)
	else:
		s.centered = true
	s.position = pos
	add_child(s)
	return s


func _grab() -> Image:
	return get_viewport().get_texture().get_image()


func _count(a: Image, b: Image) -> int:
	var changed := 0
	var pa := a.get_data()
	var pb := b.get_data()
	for p in range(0, pa.size(), 4):
		if pa[p] != pb[p] or pa[p+1] != pb[p+1] or pa[p+2] != pb[p+2]:
			changed += 1
	return changed
