extends Node2D

## Shows the modular Knight's four views, walking, and casting his ultimate.
##
## The Mage has a scene like this one, and so does the Knight now: the rig on
## its own, in every view, so it can be looked at and compared with the old
## rig that the game still uses.
##
## Press space to cast Knight's Edge, the Knight's ultimate: the blade catches
## fire, the screen goes to pitch black, and the fire sweeps across the dark.

## The four views, and where they stand.
const VIEWS := ["front", "back", "left", "right"]
const SPOTS := [
	Vector2(120, 470), Vector2(420, 470), Vector2(720, 470), Vector2(1020, 470),
]
const SCALE := 5.0

var players: Array[KnightChoreoPlayer] = []
var rigs: Array[KnightModularBase] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for index in range(VIEWS.size()):
		var perspective: String = VIEWS[index]
		var path := "res://Knight/Knight_%s/Knight%s.tscn" % [perspective, perspective.capitalize()]
		var scene := load(path) as PackedScene
		if scene == null:
			push_error("KnightShowcase: cannot load " + path)
			continue
		var rig := scene.instantiate() as KnightModularBase
		if rig == null:
			continue
		rig.scale = Vector2(SCALE, SCALE)
		rig.position = SPOTS[index]
		add_child(rig)
		rigs.append(rig)

		# the player is a sibling of the rig, so the rig has already
		# registered its pieces by the time the player reads the rest pose
		var player := KnightChoreoPlayer.new()
		player.target = rig
		add_child(player)
		player.play(KnightAnims.WALK)
		players.append(player)

		_add_label(perspective, SPOTS[index])

	_add_hint()


## Puts a name under each view.
func _add_label(text: String, spot: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = spot + Vector2(-20, 12)
	add_child(label)


## Says how to cast the ultimate.
func _add_hint() -> void:
	var label := Label.new()
	label.text = "space: Knight's Edge"
	label.position = Vector2(120, 520)
	add_child(label)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_accept"):
		return
	for player in players:
		player.play(KnightAnims.ULTIMATE)
