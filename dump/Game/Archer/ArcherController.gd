class_name ArcherController
extends CharacterController

## The Archer's controller: four rigs, one per perspective, each with its own
## player, all of them sitting on the shared CharacterController.
##
## It is the same shape as the Mage's controller, so the universal motor
## drives the archer without knowing anything about her.

const RIG_SCENES := {
	"front": "res://Archer/archer_front/archer_front.tscn",
	"back": "res://Archer/archer_back/archer_back.tscn",
	"left": "res://Archer/archer_left/archer_left.tscn",
	"right": "res://Archer/archer_right/archer_right.tscn",
}

# Only the right view is in play for now.  The other three are still built by
# the tools and are still on disk, but the game does not use them yet.
const PERSPECTIVES := ["right"]

## How fast the charged arrow flies, in pixels a second.
@export var arrow_speed: float = 1500.0

## The way the last shot was aimed.
var shot_direction: Vector2 = Vector2.RIGHT


func _init() -> void:
	idle_action = ArcherAnims.IDLE
	walk_action = ArcherAnims.WALK


## Which rig is on show.  Only the right view is in play for now.
func _perspective_for(_dir: Vector2) -> String:
	return "right"


func _ready() -> void:
	super._ready()
	# The shot is fired on the clip's impact, which is the moment the string
	# actually lets go.
	action_impact.connect(_on_action_impact)


## How far the archer's feet are below her origin.
##
## The archer's canvas starts at the top of her head, so the rig has to be
## moved down by however far her feet are from the top before she stands on
## the same line as the knight.
func _feet_height(rig: Node) -> float:
	var archer := rig as ArcherModularBase
	if archer == null:
		return 0.0
	return archer.get_feet_centre().y


func _build() -> void:
	for perspective in PERSPECTIVES:
		var scene := load(RIG_SCENES[perspective]) as PackedScene
		if scene == null:
			push_error("ArcherController: cannot load " + RIG_SCENES[perspective])
			continue
		var rig := scene.instantiate()
		add_child(rig)
		# The rig has to be in the tree before its feet can be measured, so the
		# offset is applied once the pieces have registered themselves.
		rig.position = Vector2(0.0, -_feet_height(rig))
		rigs[perspective] = rig

		var player := ArcherChoreoPlayer.new()
		player.target = rig
		add_child(player)
		players[perspective] = player


## Basic attack: raises arm with upright bow -> Frame 10 glow -> Frame 11 burst -> arrow fires straight.
func play_basic_attack(direction: Vector2 = Vector2.RIGHT) -> void:
	shot_direction = direction.normalized()
	if shot_direction == Vector2.ZERO:
		shot_direction = Vector2.RIGHT
	play_action(ArcherAnims.BASIC_ATTACK)


## Swift draw and release of a regular arrow.
func play_skill(direction: Vector2 = Vector2.RIGHT) -> void:
	shot_direction = direction.normalized()
	if shot_direction == Vector2.ZERO:
		shot_direction = Vector2.RIGHT
	play_action(ArcherAnims.SKILL)


## Deep power draw and release of a charged energy arrow.
func play_strong_skill(direction: Vector2 = Vector2.RIGHT) -> void:
	shot_direction = direction.normalized()
	if shot_direction == Vector2.ZERO:
		shot_direction = Vector2.RIGHT
	play_action(ArcherAnims.STRONG_SKILL)


## Draws the bow back and lets it go.
##
## The shot leaves on the clip's impact, so the arrow and the burst happen on
## the same frame the string snaps.
func play_charged_shot(direction: Vector2 = Vector2.RIGHT) -> void:
	shot_direction = direction.normalized()
	if shot_direction == Vector2.ZERO:
		shot_direction = Vector2.RIGHT
	play_action(ArcherAnims.CHARGED_SHOT)


func _on_action_impact(action_name: String) -> void:
	match action_name:
		ArcherAnims.BASIC_ATTACK:
			fire_basic_attack()
		ArcherAnims.SKILL:
			fire_skill()
		ArcherAnims.STRONG_SKILL:
			fire_strong_skill()
		ArcherAnims.CHARGED_SHOT:
			fire_shot()


## Puts the basic attack arrow into the world in a straight line.
func fire_basic_attack() -> void:
	var rig := active_rig as ArcherModularBase
	if rig == null:
		return
	var bow := rig.get_piece("bow")
	if bow == null:
		return
	var origin: Vector2 = bow.global_position
	ArcherShot.fire_basic_attack(_shot_host(), origin, shot_direction, arrow_speed * 0.9,
			global_position.y, absf(scale.x), bow)


## Puts the basic skill arrow into the world, at the bow.
func fire_skill() -> void:
	var rig := active_rig as ArcherModularBase
	if rig == null:
		return
	var bow := rig.get_piece("bow")
	if bow == null:
		return
	var origin: Vector2 = bow.global_position
	ArcherShot.fire_skill(_shot_host(), origin, shot_direction, arrow_speed * 0.8,
			global_position.y, absf(scale.x), bow)


## Puts the strong skill charged arrow into the world, at the bow.
func fire_strong_skill() -> void:
	var rig := active_rig as ArcherModularBase
	if rig == null:
		return
	var bow := rig.get_piece("bow")
	if bow == null:
		return
	var origin: Vector2 = bow.global_position
	ArcherShot.fire_strong_skill(_shot_host(), origin, shot_direction, arrow_speed,
			global_position.y, absf(scale.x), bow)


## Puts the ultimate shot into the world, at the bow.
func fire_shot() -> void:
	var rig := active_rig as ArcherModularBase
	if rig == null:
		return
	var bow := rig.get_piece("bow")
	if bow == null:
		return
	# the bow's own origin is its pivot, which is the grip, so this is the
	# place the arrow leaves from
	var origin: Vector2 = bow.global_position
	ArcherShot.fire(_shot_host(), origin, shot_direction, arrow_speed,
			global_position.y, absf(scale.x), bow)


## Where the shot is put: the world the archer is standing in, not the motor
## that is carrying her, or the shot would be dragged along with her.
func _shot_host() -> Node:
	var node: Node = get_parent()
	while node is UniversalMotor and node.get_parent() != null:
		node = node.get_parent()
	return node
