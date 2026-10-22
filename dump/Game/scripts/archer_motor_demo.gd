extends Node2D

## A small demonstration of the universal motor driving the modular archer.
##
## The archer walks back and forth on her own, turning as she goes, so the
## perspective change can be seen.  This is the same motor that drives the
## knight and the mage: it only ever talks to the CharacterController, so it
## knows nothing about the archer at all.

## How fast she walks, in pixels a second.
@export var walk_speed: float = 42.0
## How far she walks before turning round.
@export var patrol_width: float = 260.0

var motor: UniversalMotor
var controller: ArcherController

var _home_x: float = 0.0
var _travelling_right: bool = true


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# the ground she walks on
	var ground := ColorRect.new()
	ground.color = Color(0.15, 0.17, 0.21, 1.0)
	ground.size = Vector2(1280, 60)
	ground.position = Vector2(0, 560)
	add_child(ground)

	# the motor holds the controller, the controller holds the four rigs
	motor = UniversalMotor.new()
	motor.walk_speed = walk_speed
	controller = ArcherController.new()
	motor.add_child(controller)
	add_child(motor)

	controller.scale = Vector2(5, 5)
	motor.position = Vector2(320, 560)
	_home_x = motor.position.x


func _process(delta: float) -> void:
	# she walks to one side, then turns round and walks back
	var edge := _home_x + (patrol_width if _travelling_right else -patrol_width)
	if motor.position.x >= edge:
		_travelling_right = false
	elif motor.position.x <= _home_x:
		_travelling_right = true
	motor.set_direction(Vector2.RIGHT if _travelling_right else Vector2.LEFT)
