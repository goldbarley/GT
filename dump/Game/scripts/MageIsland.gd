extends Node2D
class_name MageIsland

## The mage on the sky island.
##
## The motor drives her, the grid keeps her on the island, and the camera
## turns with the map so her four views can be seen.  There is a button for
## each way she can walk and for each of her spells.

## How fast she walks, in pixels a second.
@export var walk_speed: float = 60.0

@onready var grid: SkyIslandGrid = $SkyIslandMap/Grid
@onready var motor: UniversalMotor = $Motor
@onready var controller: CharacterController = $Motor/Mage
@onready var camera: IslandCameraController = $IslandCamera
@onready var burst: MageBeamBurst = $Motor/MageBeam

@onready var btn_down: Button = $CanvasLayer/Panel/VBox/RowWalk/BtnDown
@onready var btn_left: Button = $CanvasLayer/Panel/VBox/RowWalk/BtnLeft
@onready var btn_up: Button = $CanvasLayer/Panel/VBox/RowWalk/BtnUp
@onready var btn_right: Button = $CanvasLayer/Panel/VBox/RowWalk/BtnRight
@onready var btn_stop: Button = $CanvasLayer/Panel/VBox/RowWalk/BtnStop
@onready var btn_rotate_left: Button = $CanvasLayer/Panel/VBox/RowCamera/BtnRotateLeft
@onready var btn_rotate_right: Button = $CanvasLayer/Panel/VBox/RowCamera/BtnRotateRight
@onready var btn_reset: Button = $CanvasLayer/Panel/VBox/RowCamera/BtnReset
@onready var btn_idle: Button = $CanvasLayer/Panel/VBox/RowActions/BtnIdle
@onready var btn_cast: Button = $CanvasLayer/Panel/VBox/RowActions/BtnCast
@onready var btn_teleport: Button = $CanvasLayer/Panel/VBox/RowActions/BtnTeleport
@onready var btn_reappear: Button = $CanvasLayer/Panel/VBox/RowActions/BtnReappear
@onready var btn_fireball: Button = $CanvasLayer/Panel/VBox/RowActions/BtnFireball
@onready var btn_barrier: Button = $CanvasLayer/Panel/VBox/RowActions/BtnBarrier
@onready var btn_meteorite: Button = $CanvasLayer/Panel/VBox/RowActions/BtnMeteorite
@onready var btn_beam: Button = $CanvasLayer/Panel/VBox/RowBeam/BtnBeam
@onready var lbl_readout: Label = $CanvasLayer/Panel/VBox/RowReadout/LabelReadout
@onready var marker: Polygon2D = $AimMarker

var _walking: Vector2 = Vector2.ZERO


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	motor.walk_speed = walk_speed
	motor.set_controller(controller)
	motor.position = grid.tile_to_world(Vector2i(6, 6))

	# the camera follows her, and the map turns under her
	camera.target_node = motor
	camera.position = motor.position
	camera.set_angle_degrees(0.0)

	_connect_buttons()
	_update_readout()


func _connect_buttons() -> void:
	# walking.  Each way she walks is one of her four views.
	btn_down.pressed.connect(_on_walk_pressed.bind(Vector2.DOWN))
	btn_left.pressed.connect(_on_walk_pressed.bind(Vector2.LEFT))
	btn_up.pressed.connect(_on_walk_pressed.bind(Vector2.UP))
	btn_right.pressed.connect(_on_walk_pressed.bind(Vector2.RIGHT))
	btn_stop.pressed.connect(_on_stop_pressed)

	# the map turning
	btn_rotate_left.pressed.connect(func(): camera.rotate_by_degrees(-90.0))
	btn_rotate_right.pressed.connect(func(): camera.rotate_by_degrees(90.0))
	btn_reset.pressed.connect(func(): camera.set_angle_degrees(0.0))

	# her spells
	btn_idle.pressed.connect(func(): controller.play_action(MageAnims.IDLE))
	btn_cast.pressed.connect(func(): controller.play_action(MageAnims.CAST))
	btn_teleport.pressed.connect(func(): controller.play_action(MageAnims.TELEPORT))
	btn_reappear.pressed.connect(func(): controller.play_action(MageAnims.TELEPORT_REAPPEAR))
	btn_fireball.pressed.connect(func(): controller.play_action(MageAnims.FIREBALL))
	btn_barrier.pressed.connect(func(): controller.play_action(MageAnims.BARRIER))
	btn_meteorite.pressed.connect(func(): controller.play_action(MageAnims.METEORITE))
	btn_beam.pressed.connect(func(): burst.fire())


func _on_walk_pressed(direction: Vector2) -> void:
	_walking = direction
	motor.set_direction(direction)


func _on_stop_pressed() -> void:
	_walking = Vector2.ZERO
	motor.stop()


func _process(_delta: float) -> void:
	# The motor moves itself, so she is put back on the island after it has
	# moved her.  She slides along the edge rather than stopping dead.
	if grid != null and _walking != Vector2.ZERO:
		var here := motor.position
		var step := _walking.normalized() * 6.0
		var wanted := here + step
		if _can_walk_to(wanted):
			motor.position = wanted
		elif _can_walk_to(Vector2(wanted.x, here.y)):
			motor.position = Vector2(wanted.x, here.y)
		elif _can_walk_to(Vector2(here.x, wanted.y)):
			motor.position = Vector2(here.x, wanted.y)

	# the beam comes out of the gem on her staff, which is in a different
	# place in every view
	burst.anchor_to_gem(controller.active_rig)

	# the marker sits on the tile the next spell is aimed at
	if marker != null and controller != null:
		marker.position = controller.cast_target

	_update_readout()


## Whether she may stand at a place on the island.
func _can_walk_to(world_pos: Vector2) -> bool:
	if grid == null:
		return true
	return grid.is_tile_walkable(grid.tile_at(world_pos))


## Clicks the map to aim the next spell at that tile.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world := get_global_mouse_position()
		if grid != null:
			controller.set_cast_tile(grid.world_to_tile(world), grid)
			marker.position = controller.cast_target
			marker.visible = true
		get_viewport().set_input_as_handled()


func _update_readout() -> void:
	if lbl_readout == null:
		return
	var view := controller.active_perspective if controller != null else "-"
	var facing := controller.get_facing() if controller != null else Vector2.ZERO
	var aimed := "none"
	if controller != null and controller.cast_target != Vector2.INF:
		var tile := grid.world_to_tile(controller.cast_target) if grid != null else Vector2i.ZERO
		aimed = "(%d, %d)" % [tile.x, tile.y]
	lbl_readout.text = "View: %s   facing %s   walking %s   busy %s   aimed at %s" % [
		view,
		str(facing),
		"yes" if motor.direction != Vector2.ZERO else "no",
		"yes" if controller != null and controller.is_busy() else "no",
		aimed]
