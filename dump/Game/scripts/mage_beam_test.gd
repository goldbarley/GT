extends Node2D

## Shows the mage under the universal motor, throwing the beam shot in four
## directions at once.
##
## The motor owns the character and the burst, so walking about carries the
## shot with her.  While the shot is out she stands still, the way a
## character stands still for any other action, and picks up walking again
## when it is over.
##
## The shot comes out of the gem on her staff.  The gem sits in a different
## place in every view, so the burst is moved onto it every frame, which
## keeps it right whether she is turned one way or another and whether her
## staff is moving.

## The four ways she can be turned, and the way the motor walks for each.
const FACINGS := {
	"Face right": Vector2.RIGHT,
	"Face front": Vector2.DOWN,
	"Face left": Vector2.LEFT,
	"Face back": Vector2.UP,
}

## The stretch of the map she keeps to.
@export var walk_from: float = 260.0
@export var walk_to: float = 1020.0
@export var walk_near: float = 400.0
@export var walk_far: float = 470.0

@onready var motor: UniversalMotor = $Motor
@onready var controller: CharacterController = $Motor/Controller
@onready var burst: MageBeamBurst = $Motor/BeamBurst
@onready var fire_button: Button = $CanvasLayer/Panel/VBox/RowButtons/BtnFire
@onready var facing_row: HBoxContainer = $CanvasLayer/Panel/VBox/RowFacings
@onready var direction_label: Label = $CanvasLayer/Panel/VBox/RowReadout/LabelDirection

var _facing_buttons: Array[Button] = []
var _wanted := Vector2.RIGHT


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fire_button.pressed.connect(func(): burst.fire())
	for label in FACINGS.keys():
		var button := Button.new()
		button.text = str(label)
		button.custom_minimum_size = Vector2(110, 32)
		button.pressed.connect(_on_facing_pressed.bind(FACINGS[label]))
		facing_row.add_child(button)
		_facing_buttons.append(button)
	burst.fire()


func _on_facing_pressed(direction: Vector2) -> void:
	_wanted = direction


func _process(_delta: float) -> void:
	# she keeps to her stretch of the map
	motor.position.x = clampf(motor.position.x, walk_from, walk_to)
	motor.position.y = clampf(motor.position.y, walk_near, walk_far)

	# a busy character stands still, and the shot is a busy moment
	var casting := burst.is_playing()
	motor.set_direction(Vector2.ZERO if casting else _wanted)

	# the shot comes out of the gem, which is somewhere else in every view
	burst.anchor_to_gem(controller.active_rig)

	direction_label.text = "View %s   facing %s   casting %s" % [
		controller.active_perspective,
		str(motor.controller.get_facing()) if motor.controller != null else "-",
		"yes" if casting else "no"]
