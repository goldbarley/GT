extends Node2D
class_name KnightIslandController

enum Perspective {
	FRONT,
	RIGHT,
	LEFT,
	BACK
}

# Perspective Textures
@export var tex_front: Texture2D = preload("res://Warrior_front.png")
@export var tex_right: Texture2D = preload("res://Warrior_right.png")
@export var tex_left: Texture2D = preload("res://Warrior_left.png")
@export var tex_back: Texture2D = preload("res://Warrior_back.png")

# Movement & Physics
@export var move_speed: float = 75.0
@export var anim_fps: float = 8.0

# Node references
@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: Sprite2D = $VisualRoot/Sprite2D
@onready var attack_slash: Sprite2D = $VisualRoot/AttackSlash

var grid: SkyIslandGrid = null
var current_perspective: Perspective = Perspective.FRONT
var current_angle_deg: float = 0.0

var is_moving: bool = false
var anim_timer: float = 0.0
var current_frame: int = 0
var is_attacking: bool = false
var attack_timer: float = 0.0

signal perspective_changed(persp_name: String, angle_deg: float)

func _setup_nodes() -> void:
	if visual_root == null:
		visual_root = get_node_or_null("VisualRoot")
	if sprite == null:
		sprite = get_node_or_null("VisualRoot/Sprite2D")
	if attack_slash == null:
		attack_slash = get_node_or_null("VisualRoot/AttackSlash")

func _ready() -> void:
	_setup_nodes()
	# Initialise in Front View
	set_perspective_from_angle(0.0)
	if attack_slash:
		attack_slash.visible = false

func set_grid_reference(p_grid: SkyIslandGrid) -> void:
	grid = p_grid

func set_perspective_from_angle(angle_deg: float) -> void:
	_setup_nodes()
	current_angle_deg = angle_deg
	# Normalize angle to range [-180, 180)
	var norm_angle: float = wrapf(angle_deg, -180.0, 180.0)
	
	var new_persp: Perspective
	if norm_angle >= -45.0 and norm_angle < 45.0:
		new_persp = Perspective.FRONT
	elif norm_angle >= 45.0 and norm_angle < 135.0:
		new_persp = Perspective.RIGHT
	elif norm_angle <= -45.0 and norm_angle > -135.0:
		new_persp = Perspective.LEFT
	else:
		new_persp = Perspective.BACK
		
	if new_persp != current_perspective or (sprite and sprite.texture == null):
		current_perspective = new_persp
		_update_sprite_texture()
		perspective_changed.emit(get_perspective_name(), current_angle_deg)

func get_perspective_name() -> String:
	match current_perspective:
		Perspective.FRONT:
			return "FRONT"
		Perspective.RIGHT:
			return "RIGHT"
		Perspective.LEFT:
			return "LEFT"
		Perspective.BACK:
			return "BACK"
		_:
			return "UNKNOWN"

func _update_sprite_texture() -> void:
	_setup_nodes()
	if not sprite:
		return
		
	match current_perspective:
		Perspective.FRONT:
			sprite.texture = tex_front
			sprite.flip_h = false
		Perspective.RIGHT:
			sprite.texture = tex_right
			sprite.flip_h = false
		Perspective.LEFT:
			sprite.texture = tex_left
			sprite.flip_h = false
		Perspective.BACK:
			sprite.texture = tex_back
			sprite.flip_h = false
			
	sprite.hframes = 4
	sprite.vframes = 1
	sprite.frame = 0

func _process(delta: float) -> void:
	# 1. Screen Billboarding: Ensure Knight always remains upright relative to the screen
	if visual_root:
		var vp = get_viewport()
		var cam = vp.get_camera_2d() if vp else null
		visual_root.global_rotation = cam.global_rotation if cam else 0.0
		
	# 2. Attack cooldown
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0.0:
			is_attacking = false
			if attack_slash:
				attack_slash.visible = false
		return
		
	# 3. Walking animation frame cycling
	if is_moving:
		anim_timer += delta
		var frame_duration: float = 1.0 / anim_fps
		if anim_timer >= frame_duration:
			anim_timer -= frame_duration
			# Frame 0 and 1 exist in all perspectives
			current_frame = (current_frame + 1) % 2
			if sprite:
				sprite.frame = current_frame
	else:
		anim_timer = 0.0
		current_frame = 0
		if sprite:
			sprite.frame = 0

func _physics_process(delta: float) -> void:
	if is_attacking:
		return
		
	# Get input vector
	var input_x: float = Input.get_axis("move_left", "move_right")
	var input_y: float = Input.get_axis("move_up", "move_down")
	var raw_input := Vector2(input_x, input_y)
	
	if raw_input.length_squared() > 0.001:
		raw_input = raw_input.normalized()
		is_moving = true
		
		# Camera-relative motion: W is always screen-up, S is screen-down
		var vp = get_viewport()
		var cam = vp.get_camera_2d() if vp else null
		var cam_rot: float = cam.rotation if cam else 0.0
		var world_move_dir = raw_input.rotated(cam_rot)
		
		var delta_pos = world_move_dir * move_speed * delta
		var candidate_pos = position + delta_pos
		
		if grid:
			# the tile is asked for without being clamped, so that the edge
			# of the island stops him rather than letting him walk off it
			var target_tile = grid.tile_at(candidate_pos)
			if grid.is_tile_walkable(target_tile):
				position = candidate_pos
			else:
				# Slide along X
				var test_x = Vector2(candidate_pos.x, position.y)
				if grid.is_tile_walkable(grid.tile_at(test_x)):
					position = test_x
				else:
					# Slide along Y
					var test_y = Vector2(position.x, candidate_pos.y)
					if grid.is_tile_walkable(grid.tile_at(test_y)):
						position = test_y
		else:
			position = candidate_pos
	else:
		is_moving = false

func trigger_attack() -> void:
	if is_attacking:
		return
	is_attacking = true
	attack_timer = 0.25
	
	if attack_slash and (current_perspective == Perspective.RIGHT or current_perspective == Perspective.LEFT):
		attack_slash.visible = true
		attack_slash.flip_h = (current_perspective == Perspective.LEFT)
		attack_slash.position = Vector2(16 if current_perspective == Perspective.RIGHT else -16, -14)
