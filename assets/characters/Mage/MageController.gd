class_name MageController
extends CharacterController

## The Mage's controller: four rigs, one per perspective, each with its own
## player, all of them sitting on the shared CharacterController.

const RIG_SCENES := {
	"front": "res://assets/characters/Mage/mage_front/mage_front.tscn",
	"back": "res://assets/characters/Mage/mage_back/mage_back.tscn",
	"left": "res://assets/characters/Mage/mage_left/mage_left.tscn",
	"right": "res://assets/characters/Mage/mage_right/mage_right.tscn",
}

const PERSPECTIVES := ["front", "back", "left", "right"]

## Where the pillar of fire is cut off, in world space.  A cut of no size
## means no cut at all.
@export var explosion_clip: Rect2 = Rect2()

## Where the next spell is aimed, in the world.  The scene works out the
## tile and hands over the place.
var cast_target: Vector2 = Vector2.INF


## Aims the next spell at a place in the world.
func set_cast_target(world_point: Vector2) -> void:
	cast_target = world_point
	for key in rigs.keys():
		var rig: Node = rigs[key]
		if rig != null:
			rig.set("cast_target", world_point)


## Aims the next spell at a tile, given anything that can turn a tile into a
## place.  The grid is whatever can answer tile_to_world, so the mage does
## not have to know what a map is.
func set_cast_tile(tile: Vector2i, grid: Object) -> void:
	if grid != null and grid.has_method("tile_to_world"):
		var place: Variant = grid.call("tile_to_world", tile)
		if place is Vector2:
			set_cast_target(place)


var _rig_angle: float = 0.0


func _init() -> void:
	idle_action = MageAnims.IDLE
	walk_action = MageAnims.WALK


func _process(_delta: float) -> void:
	_turn_rigs_to_camera()


## Turns the rigs to match the camera, so the mage stays upright when the
## map is turned under her.
##
## The rigs are drawn from the top of her hat down, so the turn has to be
## about her feet and not about the middle of the picture, or she swings
## round when the camera turns.
func _turn_rigs_to_camera() -> void:
	var camera := get_viewport().get_camera_2d()
	var angle := camera.global_rotation if camera != null else 0.0
	if is_equal_approx(angle, _rig_angle):
		return
	_rig_angle = angle
	for key in rigs.keys():
		var rig: Node = rigs[key]
		if rig == null:
			continue
		var height := _canvas_height(rig)
		rig.transform = Transform2D(-angle, Vector2(0.0, -height).rotated(-angle))


## How tall the mage's canvas is, which is how far her feet are below her
## origin.
func _canvas_height(rig: Node) -> float:
	var mage := rig as MageModularBase
	if mage == null:
		return 0.0
	return mage.canvas_size.y


func _build() -> void:
	for perspective in PERSPECTIVES:
		var scene := load(RIG_SCENES[perspective]) as PackedScene
		if scene == null:
			push_error("MageController: cannot load " + RIG_SCENES[perspective])
			continue
		var rig := scene.instantiate()
		# The mage's canvas has its origin at the top of her hat, while the
		# knight's is at his feet.  The rig is moved so both characters stand
		# on the same line, and the motor can place either of them.
		rig.position = Vector2(0.0, -_canvas_height(rig))
		add_child(rig)
		rigs[perspective] = rig

		var player := MageChoreoPlayer.new()
		player.target = rig
		add_child(player)
		players[perspective] = player

		# the pillar of fire is cut off at the edge of the map
		var explosion := rig.get_node_or_null("ExplosionFX")
		if explosion != null and "clip_rect" in explosion:
			explosion.set("clip_rect", explosion_clip)
