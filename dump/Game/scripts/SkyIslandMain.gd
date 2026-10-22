extends Node2D
class_name SkyIslandMain

@onready var island_map: Node2D = $SkyIslandMap
@onready var grid: SkyIslandGrid = $SkyIslandMap/Grid
@onready var knight: KnightIslandController = $KnightIsland
@onready var camera: IslandCameraController = $IslandCamera
@onready var explosion: ExplosionColumn = $Explosion

# UI Elements
@onready var btn_rotate_left: Button = $CanvasLayer/TopPanel/VBoxTop/HBoxButtons/BtnRotateLeft
@onready var btn_rotate_right: Button = $CanvasLayer/TopPanel/VBoxTop/HBoxButtons/BtnRotateRight
@onready var btn_reset: Button = $CanvasLayer/TopPanel/VBoxTop/HBoxButtons/BtnReset
@onready var btn_attack: Button = $CanvasLayer/TopPanel/VBoxTop/HBoxButtons/BtnAttack
@onready var btn_explosion: Button = $CanvasLayer/TopPanel/VBoxTop/HBoxButtons/BtnExplosion
@onready var check_grid: CheckBox = $CanvasLayer/TopPanel/VBoxTop/HBoxButtons/CheckGrid
@onready var label_status: Label = $CanvasLayer/TopPanel/VBoxTop/LabelStatus
@onready var label_hint: Label = $CanvasLayer/TopPanel/VBoxTop/LabelHint

var _initialized: bool = false

func _ready() -> void:
	if _initialized:
		return
	_initialized = true
	# 1. Setup Grid & Knight
	if grid and knight:
		knight.set_grid_reference(grid)
		# Spawn Knight at central walkable courtyard tile (6, 6)
		var spawn_tile := Vector2i(6, 6)
		knight.position = grid.tile_to_world(spawn_tile)
		
	# 2. Setup Camera
	if camera and knight:
		camera.target_node = knight
		camera.position = knight.position
		camera.set_angle_degrees(0.0)
		camera.camera_angle_changed.connect(_on_camera_angle_changed)
		
	if knight:
		knight.perspective_changed.connect(_on_knight_perspective_changed)
		
	# 3. Connect UI
	if btn_rotate_left:
		btn_rotate_left.pressed.connect(func(): if camera: camera.rotate_by_degrees(-90.0))
	if btn_rotate_right:
		btn_rotate_right.pressed.connect(func(): if camera: camera.rotate_by_degrees(90.0))
	if btn_reset:
		btn_reset.pressed.connect(func(): if camera: camera.set_angle_degrees(0.0))
	if btn_attack:
		btn_attack.pressed.connect(func(): if knight: knight.trigger_attack())
	if btn_explosion:
		btn_explosion.pressed.connect(_fire_explosion)
	if check_grid:
		check_grid.toggled.connect(func(pressed: bool): if grid: grid.debug_show_grid = pressed)

	_update_status_display()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				if camera:
					camera.rotate_by_degrees(-90.0)
			KEY_E:
				if camera:
					camera.rotate_by_degrees(90.0)
			KEY_R:
				if camera:
					camera.set_angle_degrees(0.0)
			KEY_SPACE:
				if knight:
					knight.trigger_attack()
			KEY_X:
				_fire_explosion()

## Throws a pillar of fire up where the knight is standing.
func _fire_explosion() -> void:
	if explosion == null:
		return
	if knight != null:
		explosion.position = knight.position
	explosion.fire()


func _on_camera_angle_changed(_angle_deg: float) -> void:
	_update_status_display()

func _on_knight_perspective_changed(_persp_name: String, _angle_deg: float) -> void:
	_update_status_display()

func _update_status_display() -> void:
	if not label_status:
		return
		
	var angle_deg: float = camera.current_angle_deg if camera else 0.0
	var persp: String = knight.get_perspective_name() if knight else "FRONT"
	var tile_coords := Vector2i.ZERO
	if grid and knight:
		tile_coords = grid.world_to_tile(knight.position)
		
	var persp_symbol: String = "⬇️"
	match persp:
		"FRONT":
			persp_symbol = "⬇️ FRONT (facing camera)"
		"RIGHT":
			persp_symbol = "➡️ RIGHT FLANK (side profile)"
		"LEFT":
			persp_symbol = "⬅️ LEFT FLANK (side profile)"
		"BACK":
			persp_symbol = "⬆️ BACK (rear view)"
			
	label_status.text = "CAMERA ANGLE: %+.0f°  |  KNIGHT VIEW: %s  |  TILE: (%d, %d)" % [
		angle_deg,
		persp_symbol,
		tile_coords.x,
		tile_coords.y
	]
	
	if label_hint:
		if persp == "RIGHT" or persp == "LEFT":
			label_hint.text = "Side profile active! Attack animations operate in horizontal profile. [Space] to test attack."
		else:
			label_hint.text = "Front/Back view active. Press Q / E to rotate 90° into side-profile attack perspective."
