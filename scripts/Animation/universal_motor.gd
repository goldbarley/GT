class_name UniversalMotor
extends Node2D

## Drives a character: where it is, which way it is looking, and whether it
## is walking.
##
## It only ever talks to the CharacterController interface, so the same motor
## drives the knight and the mage.
##
## The motor is the character's body.  It moves itself, its controller stays
## at the origin, and the rig inside keeps its own local position for the
## root motion of a cast.  Nothing fights over the same value.

const CharacterControllerClass := preload("res://scripts/Animation/character_controller.gd")

## The controller being driven.
@export var controller: Node2D = null

## The way the character is travelling.  It turns to face this and walks.
@export var direction: Vector2 = Vector2.RIGHT

## How fast the character walks, in pixels a second.
@export var walk_speed: float = 48.0

## How quickly the character turns to face a new direction, in radians a
## second.
@export var turn_speed: float = 7.0

## Whether the character is walking at all.  A character that is busy with an
## action stands still.
@export var walking: bool = true

var _facing_angle: float = 0.0
var _ready_done: bool = false


func _ready() -> void:
	if controller == null:
		for child in get_children():
			if child is CharacterControllerClass:
				controller = child
				break
	# the ready work may be done by hand in a test, and then again by the
	# engine, so it only happens once
	if controller != null and not _ready_done:
		_ready_done = true
		_facing_angle = controller.get_facing().angle()


## Sets the way to travel and turns the character to face it.
func set_direction(dir: Vector2) -> void:
	direction = dir


## Points the motor at a different character, so one motor can drive
## whichever character is in the scene.
func set_controller(new_controller: Node2D) -> void:
	controller = new_controller
	_facing_angle = controller.get_facing().angle() if controller != null else 0.0


## Stops the character where it is.
func stop() -> void:
	direction = Vector2.ZERO
	if controller != null:
		controller.set_walking(false)


## Plays the hit spark animation on the driven character.
func play_hit(local_offset: Vector2 = Vector2(0, -12), duration: float = 0.28, tint: Color = Color.WHITE) -> void:
	if controller != null and controller.has_method("play_hit"):
		controller.play_hit(local_offset, duration, tint)



func _process(delta: float) -> void:
	if controller == null:
		return

	var wanted := direction.normalized() if direction != Vector2.ZERO else Vector2.ZERO
	if wanted != Vector2.ZERO:
		# Turn towards the way we are going, a step at a time.  The difference
		# is wrapped, so the character always takes the short way round and
		# settles on the new facing instead of swinging past it.
		var difference := wrapf(wanted.angle() - _facing_angle, -PI, PI)
		var step := clampf(difference, -turn_speed * delta, turn_speed * delta)
		_facing_angle = wrapf(_facing_angle + step, -PI, PI)
		controller.set_facing(Vector2.RIGHT.rotated(_facing_angle))

	# a busy character stands still
	var busy: bool = controller.is_busy() if controller != null else false
	controller.set_walking(walking and not busy and wanted != Vector2.ZERO)

	if wanted != Vector2.ZERO and not busy:
		position += wanted * walk_speed * delta
