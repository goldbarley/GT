extends Node2D

## Checks the Archer's clips: scrubs the idle and the walk through their whole
## length and reports what the rig actually did.
##
## The feet are the interesting part.  A walk that looks right is one where the
## boots move and the body rides up and down with them.
##
## Run with:  godot --headless --path . res://scenes/ArcherRigCheck.tscn

const CLIP_IDLE := ArcherAnims.IDLE
const CLIP_WALK := ArcherAnims.WALK
const SAMPLES := 12

var archers: Array[ArcherModularBase] = []
var players: Array[ArcherChoreoPlayer] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for perspective in ["front", "back", "left", "right"]:
		var archer := ModularArcherUtility.instantiate_archer(perspective)
		add_child(archer)
		archers.append(archer)
		var player := ArcherChoreoPlayer.new()
		player.target = archer
		add_child(player)
		players.append(player)
	await get_tree().process_frame

	_check(CLIP_IDLE)
	_check(CLIP_WALK)
	get_tree().quit(0)


func _check(clip_name: String) -> void:
	print("== %s" % clip_name)
	for perspective in ["front", "back", "left", "right"]:
		var index := ["front", "back", "left", "right"].find(perspective)
		var archer := archers[index]
		var player := players[index]
		if not player.load_clip(clip_name):
			print("   %-6s NO CLIP" % perspective)
			continue

		# where each piece starts, so the movement can be measured
		var start := {}
		for child in archer.get_children():
			if child is Sprite2D:
				start[child.name] = (child as Sprite2D).position

		var foot_range := Vector2.ZERO
		var body_range := Vector2.ZERO
		var arm_range := Vector2.ZERO
		for step in range(SAMPLES + 1):
			player.scrub(float(step) / float(SAMPLES), true)
			for child in archer.get_children():
				if not child is Sprite2D:
					continue
				var sprite := child as Sprite2D
				var was: Vector2 = start[sprite.name]
				var moved := sprite.position - was
				if sprite.name.begins_with("Foot"):
					foot_range = foot_range.max(moved.abs())
				elif sprite.name == "Body":
					body_range = body_range.max(moved.abs())
				elif sprite.name == "Arm":
					arm_range = arm_range.max(moved.abs())
		print("   %-6s feet %5.2f px (x %4.2f, y %4.2f)  body %4.2f px  arm %4.2f px" % [
			perspective, maxf(foot_range.x, foot_range.y),
			foot_range.x, foot_range.y,
			maxf(body_range.x, body_range.y),
			maxf(arm_range.x, arm_range.y)])
	player_stop()


func player_stop() -> void:
	for p in players:
		p.stop()
