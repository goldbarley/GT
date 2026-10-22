extends CharacterBody2D
class_name ArcherPlaceholder

# Archer Poses
enum Pose {
	IDLE,
	AIM,
	DRAW,
	RELEASE,
	CHARGED_F1_RAISE,
	CHARGED_F2_GRIP,
	CHARGED_F3_DRAW,
	CHARGED_F4_MAX_CHARGE,
	CHARGED_F5_RELEASE
}

const ArrowScene = preload("res://scenes/arrow_projectile.tscn")
const ShockwaveScene = preload("res://scenes/arrow_shockwave.tscn")
const ChargedArrowProjScene = preload("res://scenes/charged_arrow_projectile.tscn")
const GroundTearScene = preload("res://scenes/ground_tear.tscn")

var tex_bow_red: Texture2D = preload("res://sprites/archer_placeholder/bow_red.png")
var tex_bow_bent: Texture2D = preload("res://sprites/archer_placeholder/bow_red_bent.png")

# --- CHARGED ATTACK TUNABLES ---
@export_group("Charged Attack Timing")
@export var raise_duration: float = 0.25
@export var grip_duration: float = 0.20
@export var draw_duration: float = 0.40
@export var hold_duration: float = 0.35
@export var release_duration: float = 0.80

@export_group("Charged Attack Motion & FX")
@export var arrow_speed: float = 1500.0
@export var arrow_max_range: float = 1400.0
@export var shockwave_duration: float = 0.15
@export var shockwave_max_radius: float = 80.0
@export var knockback_distance: float = 16.0
@export var knockback_duration: float = 0.20
@export var camera_shake_amplitude: float = 3.0
@export var camera_shake_duration: float = 0.20
@export var trail_max_length: float = 260.0
@export var trail_fade_duration: float = 0.50
@export var ground_tear_lag: float = 40.0
@export var ground_tear_fade_duration: float = 0.50

# Movement configuration
@export var grid_movement_enabled: bool = true
@export var grid_step_speed: float = 65.0
@export var sprint_step_speed: float = 100.0
@export var recenter_speed: float = 90.0

# Node references
@onready var visuals: Node2D = $Visuals
@onready var skeleton: Node2D = $Visuals/Skeleton
@onready var torso_pivot: Node2D = $Visuals/Skeleton/Torso_Pivot
@onready var head_pivot: Node2D = $Visuals/Skeleton/Torso_Pivot/Head_Pivot

@onready var arm_l_upper_pivot: Node2D = $Visuals/Skeleton/Torso_Pivot/ArmL_Upper_Pivot
@onready var arm_l_lower_pivot: Node2D = $Visuals/Skeleton/Torso_Pivot/ArmL_Upper_Pivot/ArmL_Lower_Pivot
@onready var hand_l_pivot: Node2D = $Visuals/Skeleton/Torso_Pivot/ArmL_Upper_Pivot/ArmL_Lower_Pivot/HandL_Pivot
@onready var bow_pivot: Node2D = $Visuals/Skeleton/Torso_Pivot/ArmL_Upper_Pivot/ArmL_Lower_Pivot/HandL_Pivot/Bow_Pivot
@onready var bow_sprite: Sprite2D = $Visuals/Skeleton/Torso_Pivot/ArmL_Upper_Pivot/ArmL_Lower_Pivot/HandL_Pivot/Bow_Pivot/BowSprite

@onready var arm_r_upper_pivot: Node2D = $Visuals/Skeleton/Torso_Pivot/ArmR_Upper_Pivot
@onready var arm_r_lower_pivot: Node2D = $Visuals/Skeleton/Torso_Pivot/ArmR_Upper_Pivot/ArmR_Lower_Pivot
@onready var hand_r_pivot: Node2D = $Visuals/Skeleton/Torso_Pivot/ArmR_Upper_Pivot/ArmR_Lower_Pivot/HandR_Pivot
@onready var arrow_pivot: Node2D = get_node_or_null("Visuals/Skeleton/Torso_Pivot/ArmL_Upper_Pivot/ArmL_Lower_Pivot/HandL_Pivot/Bow_Pivot/Arrow_Pivot")
@onready var arrow_sprite: Sprite2D = get_node_or_null("Visuals/Skeleton/Torso_Pivot/ArmL_Upper_Pivot/ArmL_Lower_Pivot/HandL_Pivot/Bow_Pivot/Arrow_Pivot/ArrowSprite")

@onready var leg_l_upper_pivot: Node2D = $Visuals/Skeleton/Torso_Pivot/LegL_Upper_Pivot
@onready var leg_l_lower_pivot: Node2D = $Visuals/Skeleton/Torso_Pivot/LegL_Upper_Pivot/LegL_Lower_Pivot
@onready var foot_l_pivot: Node2D = $Visuals/Skeleton/Torso_Pivot/LegL_Upper_Pivot/LegL_Lower_Pivot/FootL_Pivot

@onready var leg_r_upper_pivot: Node2D = $Visuals/Skeleton/Torso_Pivot/LegR_Upper_Pivot
@onready var leg_r_lower_pivot: Node2D = $Visuals/Skeleton/Torso_Pivot/LegR_Upper_Pivot/LegR_Lower_Pivot
@onready var foot_r_pivot: Node2D = $Visuals/Skeleton/Torso_Pivot/LegR_Upper_Pivot/LegR_Lower_Pivot/FootR_Pivot

@onready var bowstring: Line2D = $Visuals/Bowstring
@onready var dust_puff: Node2D = $Visuals/DustPuff
@onready var shader_hook: Node2D = $Visuals/ShaderHook
@onready var charged_arrow: Node2D = $Visuals/ShaderHook/ChargedArrow
@onready var charged_arrow_sprite: Sprite2D = $Visuals/ShaderHook/ChargedArrow/ArrowSprite

# Joint registry
var joints: Dictionary = {}
var base_positions: Dictionary = {}
var base_rotations: Dictionary = {}

# Grid navigation state
var grid: Node = null
var current_tile: Vector2i = Vector2i(6, 7)
var target_tile: Vector2i = Vector2i(6, 7)
var is_moving_to_tile: bool = false
var walk_phase: float = 0.0

# Archery state
var current_pose: Pose = Pose.IDLE
var target_aim_angle: float = 0.0
var draw_strength: float = 0.0
var time_elapsed: float = 0.0
var is_facing_right: bool = true
var is_drawing_input: bool = false
var release_timer: float = 0.0

# Charged Attack state
var is_charging_attack: bool = false
var charge_elapsed: float = 0.0
var current_charged_frame: int = 1
var is_manual_frame_lock: bool = false
var knockback_offset: Vector2 = Vector2.ZERO

func _setup_nodes() -> void:
	if visuals == null: visuals = get_node_or_null("Visuals")
	if skeleton == null: skeleton = get_node_or_null("Visuals/Skeleton")
	if torso_pivot == null: torso_pivot = get_node_or_null("Visuals/Skeleton/Torso_Pivot")
	if head_pivot == null: head_pivot = get_node_or_null("Visuals/Skeleton/Torso_Pivot/Head_Pivot")
	if arm_l_upper_pivot == null: arm_l_upper_pivot = get_node_or_null("Visuals/Skeleton/Torso_Pivot/ArmL_Upper_Pivot")
	if arm_l_lower_pivot == null: arm_l_lower_pivot = get_node_or_null("Visuals/Skeleton/Torso_Pivot/ArmL_Upper_Pivot/ArmL_Lower_Pivot")
	if hand_l_pivot == null: hand_l_pivot = get_node_or_null("Visuals/Skeleton/Torso_Pivot/ArmL_Upper_Pivot/ArmL_Lower_Pivot/HandL_Pivot")
	if bow_pivot == null: bow_pivot = get_node_or_null("Visuals/Skeleton/Torso_Pivot/ArmL_Upper_Pivot/ArmL_Lower_Pivot/HandL_Pivot/Bow_Pivot")
	if bow_sprite == null: bow_sprite = get_node_or_null("Visuals/Skeleton/Torso_Pivot/ArmL_Upper_Pivot/ArmL_Lower_Pivot/HandL_Pivot/Bow_Pivot/BowSprite")
	if arm_r_upper_pivot == null: arm_r_upper_pivot = get_node_or_null("Visuals/Skeleton/Torso_Pivot/ArmR_Upper_Pivot")
	if arm_r_lower_pivot == null: arm_r_lower_pivot = get_node_or_null("Visuals/Skeleton/Torso_Pivot/ArmR_Upper_Pivot/ArmR_Lower_Pivot")
	if hand_r_pivot == null: hand_r_pivot = get_node_or_null("Visuals/Skeleton/Torso_Pivot/ArmR_Upper_Pivot/ArmR_Lower_Pivot/HandR_Pivot")
	if arrow_pivot == null: arrow_pivot = get_node_or_null("Visuals/Skeleton/Torso_Pivot/ArmR_Upper_Pivot/ArmR_Lower_Pivot/HandR_Pivot/Arrow_Pivot")
	if arrow_sprite == null: arrow_sprite = get_node_or_null("Visuals/Skeleton/Torso_Pivot/ArmR_Upper_Pivot/ArmR_Lower_Pivot/HandR_Pivot/Arrow_Pivot/ArrowSprite")
	if leg_l_upper_pivot == null: leg_l_upper_pivot = get_node_or_null("Visuals/Skeleton/Torso_Pivot/LegL_Upper_Pivot")
	if leg_l_lower_pivot == null: leg_l_lower_pivot = get_node_or_null("Visuals/Skeleton/Torso_Pivot/LegL_Upper_Pivot/LegL_Lower_Pivot")
	if foot_l_pivot == null: foot_l_pivot = get_node_or_null("Visuals/Skeleton/Torso_Pivot/LegL_Upper_Pivot/LegL_Lower_Pivot/FootL_Pivot")
	if leg_r_upper_pivot == null: leg_r_upper_pivot = get_node_or_null("Visuals/Skeleton/Torso_Pivot/LegR_Upper_Pivot")
	if leg_r_lower_pivot == null: leg_r_lower_pivot = get_node_or_null("Visuals/Skeleton/Torso_Pivot/LegR_Upper_Pivot/LegR_Lower_Pivot")
	if foot_r_pivot == null: foot_r_pivot = get_node_or_null("Visuals/Skeleton/Torso_Pivot/LegR_Upper_Pivot/LegR_Lower_Pivot/FootR_Pivot")
	if bowstring == null: bowstring = get_node_or_null("Visuals/Bowstring")
	if dust_puff == null: dust_puff = get_node_or_null("Visuals/DustPuff")
	if shader_hook == null: shader_hook = get_node_or_null("Visuals/ShaderHook")
	if charged_arrow == null: charged_arrow = get_node_or_null("Visuals/ShaderHook/ChargedArrow")
	if charged_arrow_sprite == null: charged_arrow_sprite = get_node_or_null("Visuals/ShaderHook/ChargedArrow/ArrowSprite")

func _ready() -> void:
	_setup_nodes()
	_register_joints()
	_cache_base_transforms()
	set_pose(Pose.IDLE)
	if bow_sprite and tex_bow_red:
		bow_sprite.texture = tex_bow_red
	
	if is_inside_tree():
		await get_tree().process_frame
		_locate_grid()

func _locate_grid() -> void:
	if not is_inside_tree():
		return
	var root_node: Node = get_tree().current_scene
	if root_node:
		grid = root_node.find_child("Grid", true, false)
	if grid:
		current_tile = grid.world_to_tile(global_position)
		target_tile = current_tile
		global_position = grid.tile_to_world(current_tile)

func _register_joints() -> void:
	joints = {
		"torso": torso_pivot,
		"head": head_pivot,
		"arm_l_upper": arm_l_upper_pivot,
		"arm_l_lower": arm_l_lower_pivot,
		"hand_l": hand_l_pivot,
		"bow": bow_pivot,
		"arm_r_upper": arm_r_upper_pivot,
		"arm_r_lower": arm_r_lower_pivot,
		"hand_r": hand_r_pivot,
		"arrow": arrow_pivot,
		"leg_l_upper": leg_l_upper_pivot,
		"leg_l_lower": leg_l_lower_pivot,
		"foot_l": foot_l_pivot,
		"leg_r_upper": leg_r_upper_pivot,
		"leg_r_lower": leg_r_lower_pivot,
		"foot_r": foot_r_pivot,
	}

func _cache_base_transforms() -> void:
	for joint_name in joints:
		var node = joints[joint_name] as Node2D
		if node:
			base_positions[joint_name] = node.position
			base_rotations[joint_name] = node.rotation

func get_joint_node(joint_name: String) -> Node2D:
	return joints.get(joint_name, null)

func set_joint_rotation(joint_name: String, radians: float) -> void:
	var node = get_joint_node(joint_name)
	if node:
		node.rotation = radians

func get_joint_rotation(joint_name: String) -> float:
	var node = get_joint_node(joint_name)
	return node.rotation if node else 0.0

func reset_joint(joint_name: String) -> void:
	var node = get_joint_node(joint_name)
	if node and base_positions.has(joint_name):
		node.position = base_positions[joint_name]
		node.rotation = base_rotations[joint_name]

func reset_all_joints() -> void:
	for joint_name in joints:
		reset_joint(joint_name)

func get_shader_hook() -> Node2D:
	return shader_hook

# --- INPUT & GAMEPLAY PROCESS ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				start_charged_attack()
			else:
				if is_charging_attack:
					release_charged_attack()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_drawing_input = true
				draw_strength = 0.1
				current_pose = Pose.DRAW
			else:
				if is_drawing_input:
					if draw_strength > 0.2:
						fire_arrow()
					else:
						current_pose = Pose.IDLE
					is_drawing_input = false
					draw_strength = 0.0

func _physics_process(delta: float) -> void:
	time_elapsed += delta
	
	if is_charging_attack and not is_manual_frame_lock:
		charge_elapsed += delta
		_process_charge_progression(delta)
	
	if release_timer > 0.0:
		release_timer -= delta
		if release_timer <= 0.0 and not is_drawing_input and not is_charging_attack:
			current_pose = Pose.IDLE
			if charged_arrow:
				charged_arrow.visible = false
			if bow_sprite:
				bow_sprite.texture = tex_bow_red
			knockback_offset = Vector2.ZERO
			if dust_puff: dust_puff.visible = false
	
	# Grid movement (only if not charging)
	if grid_movement_enabled and grid and not is_charging_attack:
		_process_grid_movement(delta)
	
	# Aim direction
	var mouse_world = get_global_mouse_position() if get_viewport() else global_position + (Vector2(50, 0) if is_facing_right else Vector2(-50, 0))
	var center = global_position + Vector2(0, -14)
	var diff = mouse_world - center
	var raw_angle = diff.angle()
	
	if not is_manual_frame_lock:
		if diff.x < -10.0:
			is_facing_right = false
			visuals.scale.x = -1.0
			target_aim_angle = wrapf(PI - raw_angle, -PI, PI)
		elif diff.x > 10.0:
			is_facing_right = true
			visuals.scale.x = 1.0
			target_aim_angle = raw_angle
		target_aim_angle = clamp(target_aim_angle, -0.75, 0.75)
	else:
		is_facing_right = true
		visuals.scale.x = 1.0
		target_aim_angle = 0.0
	
	if is_drawing_input and not is_manual_frame_lock:
		draw_strength = clamp(draw_strength + delta * 2.2, 0.0, 1.0)
	
	if not is_manual_frame_lock:
		var is_moving = is_moving_to_tile or velocity.length_squared() > 1.0
		match current_pose:
			Pose.IDLE:
				_animate_idle(delta, is_moving)
			Pose.AIM:
				_animate_aim(delta, is_moving)
			Pose.DRAW:
				_animate_draw(delta, is_moving)
			Pose.RELEASE:
				_animate_release(delta, is_moving)
			Pose.CHARGED_F1_RAISE:
				evaluate_charged_timeline(1, 1.0)
			Pose.CHARGED_F2_GRIP:
				evaluate_charged_timeline(2, 1.0)
			Pose.CHARGED_F3_DRAW:
				evaluate_charged_timeline(3, 1.0)
			Pose.CHARGED_F4_MAX_CHARGE:
				evaluate_charged_timeline(4, 1.0)
			Pose.CHARGED_F5_RELEASE:
				evaluate_charged_timeline(5, 1.0)

# --- PURE TIME-DRIVEN TIMELINE EVALUATOR (0.0 to 1.0 per phase) ---

func evaluate_charged_timeline(phase: int, t: float) -> void:
	_setup_nodes()
	t = clamp(t, 0.0, 1.0)
	
	match phase:
		1:
			# FRAME 1: RAISE BOW
			# Bow arm extends forward and up to shoulder height, holding bow upright at center grip.
			# Draw hand hangs relaxed at side and does not touch string.
			current_pose = Pose.CHARGED_F1_RAISE
			current_charged_frame = 1
			
			torso_pivot.rotation = lerp_angle(0.0, 0.0, t)
			head_pivot.rotation = 0.0
			
			# Bow arm: extended forward to shoulder height (horizontal line +X)
			arm_l_upper_pivot.rotation = -1.57
			arm_l_lower_pivot.rotation = 0.0
			hand_l_pivot.rotation = 0.0
			
			# Upright bow orientation: top limb up (-Y), bottom limb down (+Y), curve to target (+X)
			_keep_bow_upright()
			if bow_sprite:
				bow_sprite.texture = tex_bow_red
				bow_sprite.rotation = 0.0
			
			# Draw hand: hangs relaxed at side, does not touch string
			arm_r_upper_pivot.rotation = -0.22
			arm_r_lower_pivot.rotation = 0.15
			hand_r_pivot.rotation = 0.0
			
			# Legs standing upright
			leg_l_upper_pivot.rotation = -0.08
			leg_r_upper_pivot.rotation = 0.08
			
			# String is single straight line connecting tips
			_update_single_bowstring(false, 0.0)
			
			# Arrow hidden
			if charged_arrow: charged_arrow.visible = false
			if dust_puff: dust_puff.visible = false
			knockback_offset = Vector2.ZERO
			visuals.position = Vector2.ZERO
			
		2:
			# FRAME 2: GRIP STRING
			# Draw hand moves to midpoint of the bow's own straight string and pinches it.
			# Bow stays upright and unchanged. Do not rotate it or add anything.
			current_pose = Pose.CHARGED_F2_GRIP
			current_charged_frame = 2
			
			torso_pivot.rotation = 0.0
			head_pivot.rotation = 0.0
			
			# Bow arm: remains extended forward at shoulder height
			arm_l_upper_pivot.rotation = -1.57
			arm_l_lower_pivot.rotation = 0.0
			hand_l_pivot.rotation = 0.0
			_keep_bow_upright()
			if bow_sprite:
				bow_sprite.texture = tex_bow_red
				bow_sprite.rotation = 0.0
				
			# Draw hand: moves from relaxed side position to the midpoint of straight string
			arm_r_upper_pivot.rotation = lerp_angle(-0.22, -1.52, t)
			arm_r_lower_pivot.rotation = lerp_angle(0.15, 0.82, t)
			hand_r_pivot.rotation = lerp_angle(0.0, 0.32, t)
			
			leg_l_upper_pivot.rotation = -0.12
			leg_r_upper_pivot.rotation = 0.12
			
			# String stays straight vertical
			_update_single_bowstring(false, 0.0)
			
			if charged_arrow: charged_arrow.visible = false
			if dust_puff: dust_puff.visible = false
			knockback_offset = Vector2.ZERO
			visuals.position = Vector2.ZERO

		3:
			# FRAME 3: DRAW AND ENERGY ARROW
			# Draw hand pulls string straight back along aim axis (-X) to cheek over about 0.4s.
			# String becomes a "<" shape and limbs bend.
			# Yellow energy arrow fades in at string's nock point and sits on bow grip, horizontal (0°), moving back with string.
			current_pose = Pose.CHARGED_F3_DRAW
			current_charged_frame = 3
			
			torso_pivot.rotation = lerp(0.0, 0.06, t)
			head_pivot.rotation = 0.0
			
			# Bow arm holds bow steady forward
			arm_l_upper_pivot.rotation = -1.57
			arm_l_lower_pivot.rotation = 0.0
			hand_l_pivot.rotation = 0.0
			_keep_bow_upright()
			
			# Bow limbs bend under tension
			if bow_sprite:
				bow_sprite.texture = tex_bow_bent if t > 0.15 else tex_bow_red
				bow_sprite.rotation = 0.0
			
			# Draw hand pulls straight back along aim axis (-X) to cheek
			arm_r_upper_pivot.rotation = lerp_angle(-1.52, -1.98, t)
			arm_r_lower_pivot.rotation = lerp_angle(0.82, 2.30, t)
			hand_r_pivot.rotation = lerp_angle(0.32, 0.18, t)
			
			# Legs brace
			leg_l_upper_pivot.rotation = lerp_angle(-0.12, -0.25, t)
			leg_r_upper_pivot.rotation = lerp_angle(0.12, 0.28, t)
			
			# String pulled back into acute "<" shape
			_update_single_bowstring(true, t)
			
			# Energy arrow: fades in at string nock point, horizontal 0°, moving back with string
			if charged_arrow:
				charged_arrow.visible = (t > 0.02)
				charged_arrow.global_rotation = 0.0
				var nock_x = hand_r_pivot.global_position.x
				var aim_y = bow_pivot.global_position.y
				charged_arrow.global_position = Vector2(nock_x, aim_y)
				
				if charged_arrow_sprite and charged_arrow_sprite.material:
					var mat = charged_arrow_sprite.material as ShaderMaterial
					mat.set_shader_parameter("charge_progress", t)
					mat.set_shader_parameter("opacity", t)
					mat.set_shader_parameter("tip_radiance", 0.0) # Zero radiance in Frame 3
					
			if dust_puff: dust_puff.visible = false
			knockback_offset = Vector2.ZERO
			visuals.position = Vector2.ZERO

		4:
			# FRAME 4: MAX CHARGE (HOLD)
			# Pose: fully drawn and held. Arrow stays horizontal (0°).
			# Tip energy: radiates from arrow TIP only, never shaft. Forms two streaks sweeping backward at +45° and -45° from aim axis ("<" opening toward archer).
			# Red helix completely removed.
			current_pose = Pose.CHARGED_F4_MAX_CHARGE
			current_charged_frame = 4
			
			var tension_shake = sin(t * 50.0 + time_elapsed * 40.0) * 0.012
			torso_pivot.rotation = 0.06 + tension_shake
			head_pivot.rotation = 0.0
			
			arm_l_upper_pivot.rotation = -1.57 + tension_shake
			arm_l_lower_pivot.rotation = 0.0
			hand_l_pivot.rotation = 0.0
			_keep_bow_upright()

			
			if bow_sprite:
				bow_sprite.texture = tex_bow_bent
				bow_sprite.rotation = 0.0
				
			arm_r_upper_pivot.rotation = -1.98 - tension_shake
			arm_r_lower_pivot.rotation = 2.30
			hand_r_pivot.rotation = 0.18
			
			leg_l_upper_pivot.rotation = -0.28
			leg_r_upper_pivot.rotation = 0.32
			
			_update_single_bowstring(true, 1.0)
			
			# Arrow horizontal, tip radiance active
			if charged_arrow:
				charged_arrow.visible = true
				charged_arrow.global_rotation = 0.0
				var nock_x = hand_r_pivot.global_position.x
				var aim_y = bow_pivot.global_position.y
				charged_arrow.global_position = Vector2(nock_x, aim_y)
				
				if charged_arrow_sprite and charged_arrow_sprite.material:
					var mat = charged_arrow_sprite.material as ShaderMaterial
					mat.set_shader_parameter("charge_progress", 1.0)
					mat.set_shader_parameter("opacity", 1.0)
					mat.set_shader_parameter("tip_radiance", clamp(t * 1.5, 0.0, 1.0))
					
			if dust_puff: dust_puff.visible = false
			knockback_offset = Vector2.ZERO
			visuals.position = Vector2.ZERO

		5:
			# FRAME 5: RELEASE
			# String snaps forward. Character pushed backward (-X) ~16px with ease-out over 0.2s, leaning back, dust puff at feet, settles.
			current_pose = Pose.CHARGED_F5_RELEASE
			current_charged_frame = 5
			
			# String snaps forward immediately
			_update_single_bowstring(false, 0.0)
			if bow_sprite:
				bow_sprite.texture = tex_bow_red
				bow_sprite.rotation = 0.0
				
			# Recoil arm posture
			arm_r_upper_pivot.rotation = lerp_angle(-1.98, -1.15, clamp(t * 5.0, 0.0, 1.0))
			arm_r_lower_pivot.rotation = lerp_angle(2.30, 0.30, clamp(t * 5.0, 0.0, 1.0))
			_keep_bow_upright()
			
			# Knockback over 0.2s (fraction of release_duration: kb_ratio = knockback_duration / release_duration)
			var kb_ratio = clamp(knockback_duration / max(0.01, release_duration), 0.05, 1.0)
			if t < kb_ratio:
				var t_kb = t / kb_ratio
				var ease_kb = 1.0 - pow(1.0 - t_kb, 3.0)
				# Push backward -X about 16 px, then settle back
				var kb_dist = -knockback_distance * (1.0 - ease_kb)
				knockback_offset = Vector2(kb_dist, 0.0)
				torso_pivot.rotation = -0.16 * (1.0 - t_kb) # Leaning back
				if dust_puff:
					dust_puff.visible = true
					dust_puff.modulate.a = (1.0 - t_kb)
			else:
				knockback_offset = Vector2.ZERO
				torso_pivot.rotation = 0.0
				if dust_puff:
					dust_puff.visible = false
					
			visuals.position = knockback_offset
			
			# Arrow on bow is hidden upon release (now flying in workbench)
			if charged_arrow:
				charged_arrow.visible = false

func _keep_bow_upright(extra_angle: float = 0.0) -> void:
	if bow_pivot and arm_l_upper_pivot and arm_l_lower_pivot and hand_l_pivot and torso_pivot:
		bow_pivot.rotation = - (torso_pivot.rotation + arm_l_upper_pivot.rotation + arm_l_lower_pivot.rotation + hand_l_pivot.rotation) + extra_angle
		if is_inside_tree():
			bow_pivot.global_rotation = extra_angle

# --- SINGLE DYNAMIC BOWSTRING (No second string) ---

func _update_single_bowstring(is_drawn: bool, pull_t: float) -> void:
	if not bowstring or not bow_pivot or not hand_r_pivot:
		return
		
	var bow_pos = bow_pivot.global_position
	# Top tip at y = -11, Bottom tip at y = +11 relative to bow center
	var p_top_world = bow_pos + Vector2(0, -11)
	var p_bottom_world = bow_pos + Vector2(0, 11)
	
	var p_mid_world: Vector2
	if is_drawn:
		# Center pinched and pulled back to hand
		p_mid_world = Vector2(hand_r_pivot.global_position.x, bow_pos.y)
	else:
		# Straight vertical line between limb tips
		p_mid_world = (p_top_world + p_bottom_world) * 0.5
		
	var local_top = bowstring.to_local(p_top_world)
	var local_mid = bowstring.to_local(p_mid_world)
	var local_bot = bowstring.to_local(p_bottom_world)
	
	bowstring.points = PackedVector2Array([local_top, local_mid, local_bot])

# --- CONVENIENCE & WORKBENCH API ---

func set_charged_attack_frame(frame_num: int) -> void:
	evaluate_charged_timeline(frame_num, 1.0)

func start_charged_attack() -> void:
	is_charging_attack = true
	charge_elapsed = 0.0
	current_charged_frame = 1
	is_manual_frame_lock = false
	evaluate_charged_timeline(1, 1.0)

func release_charged_attack() -> void:
	is_charging_attack = false
	evaluate_charged_timeline(5, 0.0)
	release_timer = release_duration
	fire_charged_arrow()

func fire_charged_arrow() -> void:
	var shoot_origin = bow_pivot.global_position
	var shoot_dir = Vector2.RIGHT if is_facing_right else Vector2.LEFT
	var p = get_parent() if get_parent() else (get_tree().current_scene if get_tree() else self)
	var char_scale = scale.abs()
	
	var shockwave = ShockwaveScene.instantiate() as ArrowShockwave
	if shockwave and p:
		shockwave.scale = char_scale
		shockwave.global_position = shoot_origin + shoot_dir * 10.0 * char_scale.x
		shockwave.rotation = 0.0
		p.add_child(shockwave)
			
	var proj = ChargedArrowProjScene.instantiate() as ChargedArrowProjectile
	if proj and p:
		proj.scale = char_scale
		proj.global_position = shoot_origin + shoot_dir * 14.0 * char_scale.x
		proj.direction = shoot_dir
		proj.speed = arrow_speed
		proj.ground_y_level = global_position.y
		p.add_child(proj)

	var tear_scene = preload("res://scenes/ground_tear.tscn")
	var tear = tear_scene.instantiate()
	if tear and p:
		tear.scale = char_scale
		tear.global_position = Vector2(shoot_origin.x + 8.0 * char_scale.x, global_position.y)
		p.add_child(tear)

func _process_charge_progression(delta: float) -> void:
	var t1 = raise_duration
	var t2 = t1 + grip_duration
	var t3 = t2 + draw_duration
	
	if charge_elapsed < t1:
		var t = charge_elapsed / max(0.001, t1)
		evaluate_charged_timeline(1, t)
	elif charge_elapsed < t2:
		var t = (charge_elapsed - t1) / max(0.001, grip_duration)
		evaluate_charged_timeline(2, t)
	elif charge_elapsed < t3:
		var t = (charge_elapsed - t2) / max(0.001, draw_duration)
		evaluate_charged_timeline(3, t)
	else:
		var t = clamp((charge_elapsed - t3) / max(0.001, hold_duration), 0.0, 1.0)
		evaluate_charged_timeline(4, t)

# --- NORMAL POSES FOR WALKING & AIMING ---

func _animate_idle(delta: float, is_moving: bool) -> void:
	var breath = sin(time_elapsed * 2.5)
	torso_pivot.position.y = base_positions["torso"].y + (breath * 0.8 if not is_moving else sin(walk_phase * 2.0) * 1.2)
	head_pivot.rotation = sin(time_elapsed * 1.8) * 0.04
	
	arm_l_upper_pivot.rotation = lerp_angle(arm_l_upper_pivot.rotation, 0.35 + breath * 0.05, 8.0 * delta)
	arm_l_lower_pivot.rotation = lerp_angle(arm_l_lower_pivot.rotation, 0.20, 8.0 * delta)
	hand_l_pivot.rotation = lerp_angle(hand_l_pivot.rotation, -0.10, 8.0 * delta)
	bow_pivot.rotation = lerp_angle(bow_pivot.rotation, 0.0, 8.0 * delta)
	
	arm_r_upper_pivot.rotation = lerp_angle(arm_r_upper_pivot.rotation, -0.25 - breath * 0.05, 8.0 * delta)
	arm_r_lower_pivot.rotation = lerp_angle(arm_r_lower_pivot.rotation, 0.15, 8.0 * delta)
	hand_r_pivot.rotation = lerp_angle(hand_r_pivot.rotation, 0.0, 8.0 * delta)
	arrow_pivot.position = Vector2.ZERO
	if arrow_sprite: arrow_sprite.visible = false
	if charged_arrow: charged_arrow.visible = false
	if bow_sprite: bow_sprite.texture = tex_bow_red
	_update_single_bowstring(false, 0.0)
	
	if is_moving:
		_animate_legs_walk(delta)
	else:
		leg_l_upper_pivot.rotation = lerp_angle(leg_l_upper_pivot.rotation, 0.0, 10.0 * delta)
		leg_l_lower_pivot.rotation = lerp_angle(leg_l_lower_pivot.rotation, 0.0, 10.0 * delta)
		leg_r_upper_pivot.rotation = lerp_angle(leg_r_upper_pivot.rotation, 0.0, 10.0 * delta)
		leg_r_lower_pivot.rotation = lerp_angle(leg_r_lower_pivot.rotation, 0.0, 10.0 * delta)

func _animate_aim(delta: float, is_moving: bool) -> void:
	if arrow_sprite: arrow_sprite.visible = true
	torso_pivot.rotation = lerp_angle(torso_pivot.rotation, 0.05, 10.0 * delta)
	head_pivot.rotation = lerp_angle(head_pivot.rotation, target_aim_angle * 0.4, 10.0 * delta)
	
	arm_l_upper_pivot.rotation = lerp_angle(arm_l_upper_pivot.rotation, target_aim_angle - 1.57, 12.0 * delta)
	arm_l_lower_pivot.rotation = lerp_angle(arm_l_lower_pivot.rotation, 0.0, 12.0 * delta)
	hand_l_pivot.rotation = lerp_angle(hand_l_pivot.rotation, 0.0, 12.0 * delta)
	bow_pivot.rotation = lerp_angle(bow_pivot.rotation, 0.0, 12.0 * delta)
	
	arm_r_upper_pivot.rotation = lerp_angle(arm_r_upper_pivot.rotation, target_aim_angle - 1.40, 12.0 * delta)
	arm_r_lower_pivot.rotation = lerp_angle(arm_r_lower_pivot.rotation, 1.20, 12.0 * delta)
	hand_r_pivot.rotation = lerp_angle(hand_r_pivot.rotation, 0.40, 12.0 * delta)
	arrow_pivot.position = Vector2.ZERO
	_update_single_bowstring(false, 0.0)
	
	if is_moving:
		_animate_legs_walk(delta)

func _animate_draw(delta: float, is_moving: bool) -> void:
	if arrow_sprite: arrow_sprite.visible = true
	torso_pivot.rotation = lerp_angle(torso_pivot.rotation, 0.08, 10.0 * delta)
	head_pivot.rotation = lerp_angle(head_pivot.rotation, target_aim_angle * 0.35, 10.0 * delta)
	
	arm_l_upper_pivot.rotation = lerp_angle(arm_l_upper_pivot.rotation, target_aim_angle - 1.57, 14.0 * delta)
	arm_l_lower_pivot.rotation = lerp_angle(arm_l_lower_pivot.rotation, 0.0, 14.0 * delta)
	bow_pivot.rotation = lerp_angle(bow_pivot.rotation, 0.0, 14.0 * delta)
	
	var pull_angle = lerp(1.20, 2.25, draw_strength)
	arm_r_upper_pivot.rotation = lerp_angle(arm_r_upper_pivot.rotation, target_aim_angle - 1.85, 14.0 * delta)
	arm_r_lower_pivot.rotation = lerp_angle(arm_r_lower_pivot.rotation, pull_angle, 14.0 * delta)
	hand_r_pivot.rotation = lerp_angle(hand_r_pivot.rotation, 0.20, 14.0 * delta)
	arrow_pivot.position.x = -8.0 * draw_strength
	_update_single_bowstring(true, draw_strength)
	
	if is_moving:
		_animate_legs_walk(delta)
	else:
		leg_l_upper_pivot.rotation = lerp_angle(leg_l_upper_pivot.rotation, -0.15, 10.0 * delta)
		leg_r_upper_pivot.rotation = lerp_angle(leg_r_upper_pivot.rotation, 0.20, 10.0 * delta)

func _animate_release(delta: float, is_moving: bool) -> void:
	arm_r_lower_pivot.rotation = lerp_angle(arm_r_lower_pivot.rotation, 0.40, 16.0 * delta)
	bow_pivot.rotation = lerp_angle(bow_pivot.rotation, -0.15, 16.0 * delta)
	if arrow_sprite: arrow_sprite.visible = false
	_update_single_bowstring(false, 0.0)
	if is_moving:
		_animate_legs_walk(delta)

func _animate_legs_walk(delta: float) -> void:
	walk_phase += delta * 12.0
	leg_l_upper_pivot.rotation = sin(walk_phase) * 0.55
	leg_l_lower_pivot.rotation = max(0.0, -sin(walk_phase)) * 0.50
	leg_r_upper_pivot.rotation = -sin(walk_phase) * 0.55
	leg_r_lower_pivot.rotation = max(0.0, sin(walk_phase)) * 0.50

func _process_grid_movement(delta: float) -> void:
	var input_dir: Vector2i = Vector2i.ZERO
	if Input.is_action_pressed("move_left"): input_dir.x -= 1
	if Input.is_action_pressed("move_right"): input_dir.x += 1
	if Input.is_action_pressed("move_up"): input_dir.y -= 1
	if Input.is_action_pressed("move_down"): input_dir.y += 1
	
	var is_sprinting: bool = Input.is_action_pressed("sprint")
	var active_speed: float = sprint_step_speed if is_sprinting else grid_step_speed
	
	if input_dir != Vector2i.ZERO:
		if input_dir.x != 0 and input_dir.y != 0:
			input_dir.y = 0
			
		if is_moving_to_tile:
			var target_pos: Vector2 = grid.tile_to_world(target_tile)
			var diff: Vector2 = target_pos - global_position
			var dist: float = diff.length()
			var step: float = active_speed * delta
			
			if dist <= step:
				global_position = target_pos
				current_tile = target_tile
				var next_tile: Vector2i = current_tile + input_dir
				if grid.is_tile_walkable(next_tile):
					target_tile = next_tile
					is_moving_to_tile = true
				else:
					is_moving_to_tile = false
					velocity = Vector2.ZERO
			else:
				velocity = diff.normalized() * active_speed
				global_position += velocity * delta
		else:
			var candidate_tile: Vector2i = current_tile + input_dir
			if grid.is_tile_walkable(candidate_tile):
				target_tile = candidate_tile
				is_moving_to_tile = true
				var target_pos: Vector2 = grid.tile_to_world(target_tile)
				var diff: Vector2 = target_pos - global_position
				velocity = diff.normalized() * active_speed
				global_position += velocity * delta
			else:
				velocity = Vector2.ZERO
	else:
		is_moving_to_tile = false
		var nearest_tile: Vector2i = grid.world_to_tile(global_position)
		if not grid.is_tile_walkable(nearest_tile):
			nearest_tile = current_tile
			
		current_tile = nearest_tile
		target_tile = nearest_tile
		var center_pos: Vector2 = grid.tile_to_world(nearest_tile)
		var offset: Vector2 = center_pos - global_position
		var dist: float = offset.length()
		
		if dist > 0.3:
			var recenter_step: float = recenter_speed * delta
			if dist <= recenter_step:
				global_position = center_pos
				velocity = Vector2.ZERO
			else:
				velocity = offset.normalized() * recenter_speed
				global_position += velocity * delta
		else:
			velocity = Vector2.ZERO

func fire_arrow() -> void:
	current_pose = Pose.RELEASE
	release_timer = 0.58
	
	var shoot_origin = global_position + Vector2(0, -14)
	var shoot_target = get_global_mouse_position() if get_viewport() else shoot_origin + (Vector2.RIGHT if is_facing_right else Vector2.LEFT) * 50.0
	var shoot_dir = (shoot_target - shoot_origin).normalized()
	
	var shockwave_inst = ShockwaveScene.instantiate() as ArrowShockwave
	if shockwave_inst:
		shockwave_inst.global_position = shoot_origin + shoot_dir * 8.0
		shockwave_inst.rotation = 0.0
		if get_parent(): get_parent().add_child(shockwave_inst)
		else: add_child(shockwave_inst)
	
	var arrow_inst = ArrowScene.instantiate() as ArrowProjectile
	if arrow_inst:
		arrow_inst.global_position = shoot_origin + shoot_dir * 12.0
		arrow_inst.direction = shoot_dir
		arrow_inst.speed = lerp(200.0, 380.0, draw_strength)
		if get_parent(): get_parent().add_child(arrow_inst)
		else: add_child(arrow_inst)

func set_pose(pose: Pose) -> void:
	current_pose = pose
