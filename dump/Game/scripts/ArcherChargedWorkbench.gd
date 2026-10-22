extends Node2D
class_name ArcherChargedWorkbench

# --- TUNABLES (Exposed at top of script) ---
@export_group("Timeline & Timing")
@export var raise_duration: float = 0.25
@export var grip_duration: float = 0.20
@export var draw_duration: float = 0.40
@export var hold_duration: float = 0.35
@export var release_duration: float = 0.80

@export_group("Release FX")
@export var arrow_speed: float = 1500.0
@export var arrow_max_range: float = 1400.0
@export var shockwave_duration: float = 0.65
@export var shockwave_max_radius: float = 110.0
@export var knockback_distance: float = 16.0
@export var knockback_duration: float = 0.20
@export var camera_shake_amplitude: float = 3.0
@export var camera_shake_duration: float = 0.20
@export var trail_max_length: float = 280.0
@export var trail_fade_duration: float = 0.50
@export var ground_tear_lag: float = 45.0
@export var ground_tear_fade_duration: float = 0.50

# Node references
@onready var archer: ArcherPlaceholder = $ArcherPlaceholder
@onready var ground_line: ColorRect = $GroundLine
@onready var camera: Camera2D = $Camera2D

# Visual FX Nodes
@onready var shockwave_node: Node2D = $ShockwaveNode
@onready var projectile_node: Node2D = $ProjectileNode
@onready var trail_line: Line2D = $TrailLine
@onready var ground_tear_rect: ColorRect = $GroundTearRect

# UI Controls
@onready var btn_f1: Button = $CanvasLayer/Panel/VBoxContainer/HBoxFrames/BtnF1
@onready var btn_f2: Button = $CanvasLayer/Panel/VBoxContainer/HBoxFrames/BtnF2
@onready var btn_f3: Button = $CanvasLayer/Panel/VBoxContainer/HBoxFrames/BtnF3
@onready var btn_f4: Button = $CanvasLayer/Panel/VBoxContainer/HBoxFrames/BtnF4
@onready var btn_f5: Button = $CanvasLayer/Panel/VBoxContainer/HBoxFrames/BtnF5

@onready var btn_hold_charge: Button = $CanvasLayer/Panel/VBoxContainer/HBoxActions/BtnHoldCharge
@onready var btn_reset_idle: Button = $CanvasLayer/Panel/VBoxContainer/HBoxActions/BtnResetIdle
@onready var slider_scrub: HSlider = $CanvasLayer/Panel/VBoxContainer/HBoxScrub/SliderScrub

@onready var label_frame_info: Label = $CanvasLayer/Panel/VBoxContainer/LabelFrameInfo
@onready var label_details: Label = $CanvasLayer/Panel/VBoxContainer/LabelDetails

# Timeline state
var current_timeline_T: float = 1.0 # 1.0 to 5.0
var is_holding_charge_ui: bool = false
var is_playing_release: bool = false
var release_playback_time: float = 0.0

var archer_base_pos: Vector2 = Vector2(280, 420)
var bow_aim_world_pos: Vector2 = Vector2(280 + 36, 420 - 74)

# Shockwave rendering variables
var shockwave_radius: float = 0.0
var shockwave_alpha: float = 0.0

func _setup_nodes() -> void:
	if archer == null: archer = get_node_or_null("ArcherPlaceholder")
	if ground_line == null: ground_line = get_node_or_null("GroundLine")
	if camera == null: camera = get_node_or_null("Camera2D")
	if shockwave_node == null: shockwave_node = get_node_or_null("ShockwaveNode")
	if projectile_node == null: projectile_node = get_node_or_null("ProjectileNode")
	if trail_line == null: trail_line = get_node_or_null("TrailLine")
	if ground_tear_rect == null: ground_tear_rect = get_node_or_null("GroundTearRect")
	
	if btn_f1 == null: btn_f1 = get_node_or_null("CanvasLayer/Panel/VBoxContainer/HBoxFrames/BtnF1")
	if btn_f2 == null: btn_f2 = get_node_or_null("CanvasLayer/Panel/VBoxContainer/HBoxFrames/BtnF2")
	if btn_f3 == null: btn_f3 = get_node_or_null("CanvasLayer/Panel/VBoxContainer/HBoxFrames/BtnF3")
	if btn_f4 == null: btn_f4 = get_node_or_null("CanvasLayer/Panel/VBoxContainer/HBoxFrames/BtnF4")
	if btn_f5 == null: btn_f5 = get_node_or_null("CanvasLayer/Panel/VBoxContainer/HBoxFrames/BtnF5")
	if btn_hold_charge == null: btn_hold_charge = get_node_or_null("CanvasLayer/Panel/VBoxContainer/HBoxActions/BtnHoldCharge")
	if btn_reset_idle == null: btn_reset_idle = get_node_or_null("CanvasLayer/Panel/VBoxContainer/HBoxActions/BtnResetIdle")
	if slider_scrub == null: slider_scrub = get_node_or_null("CanvasLayer/Panel/VBoxContainer/HBoxScrub/SliderScrub")
	if label_frame_info == null: label_frame_info = get_node_or_null("CanvasLayer/Panel/VBoxContainer/LabelFrameInfo")
	if label_details == null: label_details = get_node_or_null("CanvasLayer/Panel/VBoxContainer/LabelDetails")

var _is_initialized: bool = false

func _ready() -> void:
	if _is_initialized:
		return
	_is_initialized = true
	_setup_nodes()
	
	if archer:
		archer.grid_movement_enabled = false
		archer.position = archer_base_pos
		archer.scale = Vector2(4.0, 4.0)
		archer.is_manual_frame_lock = true
	
	if shockwave_node:
		shockwave_node.manual_timeline = true
		shockwave_node.visible = false
	
	# Connect UI buttons
	if btn_f1: btn_f1.pressed.connect(func(): _select_frame(1))
	if btn_f2: btn_f2.pressed.connect(func(): _select_frame(2))
	if btn_f3: btn_f3.pressed.connect(func(): _select_frame(3))
	if btn_f4: btn_f4.pressed.connect(func(): _select_frame(4))
	if btn_f5: btn_f5.pressed.connect(func(): _select_frame(5))
	
	if btn_reset_idle:
		btn_reset_idle.pressed.connect(func():
			is_holding_charge_ui = false
			is_playing_release = false
			_evaluate_timeline(1.0)
			if slider_scrub: slider_scrub.set_value_no_signal(1.0)
			_update_ui_telemetry("FRAME 1: RAISE BOW", "Bow arm raised upright forward; draw hand relaxed at side.")
		)
		
	if btn_hold_charge:
		btn_hold_charge.button_down.connect(func():
			is_holding_charge_ui = true
			is_playing_release = false
			current_timeline_T = 1.0
		)
		btn_hold_charge.button_up.connect(func():
			if is_holding_charge_ui:
				is_holding_charge_ui = false
				is_playing_release = true
				release_playback_time = 0.0
				current_timeline_T = 4.0
				_update_ui_telemetry("FRAME 5: RELEASE", "Violent release: Shockwave + Arrow Launch + Knockback & Camera Shake + Ground Tear.")
		)
		
	if slider_scrub:
		slider_scrub.min_value = 1.0
		slider_scrub.max_value = 5.0
		slider_scrub.step = 0.01
		slider_scrub.value = 1.0
		slider_scrub.value_changed.connect(_on_slider_scrub_changed)
		
	_evaluate_timeline(1.0)

func _process(delta: float) -> void:
	if is_holding_charge_ui:
		# Advance through F1 -> F2 -> F3 -> F4, holding at F4 (4.0)
		if current_timeline_T < 2.0:
			current_timeline_T += delta / max(0.01, raise_duration)
			_update_ui_telemetry("FRAME 1: RAISE BOW", "Bow arm extends forward & up to shoulder height.")
		elif current_timeline_T < 3.0:
			current_timeline_T += delta / max(0.01, grip_duration)
			_update_ui_telemetry("FRAME 2: GRIP STRING", "Draw hand reaches to midpoint of straight bowstring and pinches it.")
		elif current_timeline_T < 4.0:
			current_timeline_T += delta / max(0.01, draw_duration)
			_update_ui_telemetry("FRAME 3: DRAW & ENERGY ARROW", "Drawing string straight back along aim axis to cheek. Yellow arrow materializes.")
		else:
			current_timeline_T = 4.0
			_update_ui_telemetry("FRAME 4: MAX CHARGE (HOLD)", "Fully drawn hold. 45° tip radiance streaks cutting through energy.")
			
		current_timeline_T = clamp(current_timeline_T, 1.0, 4.0)
		if slider_scrub: slider_scrub.set_value_no_signal(current_timeline_T)
		_evaluate_timeline(current_timeline_T)
		
	elif is_playing_release:
		# Advance through Frame 5 (4.0 to 5.0)
		release_playback_time += delta
		var rel_t = clamp(release_playback_time / max(0.01, release_duration), 0.0, 1.0)
		current_timeline_T = 4.0 + rel_t
		if slider_scrub: slider_scrub.set_value_no_signal(current_timeline_T)
		_evaluate_timeline(current_timeline_T)
		if rel_t >= 1.0:
			is_playing_release = false

func _on_slider_scrub_changed(val: float) -> void:
	is_holding_charge_ui = false
	is_playing_release = false
	current_timeline_T = val
	_evaluate_timeline(val)
	
	if val < 2.0:
		_update_ui_telemetry("FRAME 1: RAISE BOW", "Bow arm extends forward & up to shoulder height; draw hand relaxed at side.")
	elif val < 3.0:
		_update_ui_telemetry("FRAME 2: GRIP STRING", "Draw hand pinches the midpoint of the bow's own straight string.")
	elif val < 4.0:
		_update_ui_telemetry("FRAME 3: DRAW & ENERGY ARROW", "Pulls string back along aim axis to cheek over 0.4s. String becomes '<' shape; limbs bend; yellow arrow horizontal at 0°.")
	elif val < 4.05:
		_update_ui_telemetry("FRAME 4: MAX CHARGE (HOLD)", "Fully drawn hold. Tip energy radiates at +45° and -45° backward. Zero shaft radiance. No red helix.")
	else:
		_update_ui_telemetry("FRAME 5: RELEASE", "String snaps forward. Arrow launches along +X at 1500 px/s. Shockwave expands & fades. -16px knockback & 3px camera shake. Ground tear spreads strictly behind arrow.")

func _select_frame(frame_num: int) -> void:
	is_holding_charge_ui = false
	is_playing_release = false
	
	match frame_num:
		1:
			current_timeline_T = 1.0
			_update_ui_telemetry("FRAME 1: RAISE BOW", "Bow arm extends forward & up to shoulder height; draw hand relaxed at side.")
		2:
			current_timeline_T = 2.0
			_update_ui_telemetry("FRAME 2: GRIP STRING", "Draw hand pinches the midpoint of the bow's own straight string.")
		3:
			current_timeline_T = 3.0
			_update_ui_telemetry("FRAME 3: DRAW & ENERGY ARROW", "Pulls string back along aim axis to cheek over 0.4s. String becomes '<' shape; limbs bend; yellow arrow horizontal at 0°.")
		4:
			current_timeline_T = 4.0
			_update_ui_telemetry("FRAME 4: MAX CHARGE (HOLD)", "Fully drawn hold. Tip energy radiates at +45° and -45° backward. Zero shaft radiance. No red helix.")
		5:
			current_timeline_T = 4.18 # Active release moment in Frame 5 (peak shockwave + launched arrow)
			_update_ui_telemetry("FRAME 5: RELEASE", "String snaps forward. Arrow launches along +X at 1500 px/s. Multi-temperature shockwave shader blooms. -16px knockback & 3px camera shake. Ground tear spreads strictly behind arrow.")
			
	if slider_scrub:
		slider_scrub.set_value_no_signal(current_timeline_T)
	_evaluate_timeline(current_timeline_T)

# --- PURE TIME-DRIVEN TIMELINE EVALUATOR ---

func _evaluate_timeline(T: float) -> void:
	_setup_nodes()
	if not archer:
		return
		
	# Phase mapping:
	# [1.0, 2.0) -> Phase 1 (t = T - 1.0)
	# [2.0, 3.0) -> Phase 2 (t = T - 2.0)
	# [3.0, 4.0) -> Phase 3 (t = T - 3.0)
	# 4.0        -> Phase 4 (t = 1.0)
	# (4.0, 5.0] -> Phase 5 (t = T - 4.0)
	
	if T <= 1.001:
		archer.evaluate_charged_timeline(1, 1.0)
		_evaluate_release_fx(0.0, false)
	elif T <= 2.001:
		var t = clamp(T - 1.0, 0.0, 1.0)
		archer.evaluate_charged_timeline(2, t)
		_evaluate_release_fx(0.0, false)
	elif T <= 3.001:
		var t = clamp(T - 2.0, 0.0, 1.0)
		archer.evaluate_charged_timeline(3, t)
		_evaluate_release_fx(0.0, false)
	elif T <= 4.001:
		var t = clamp(T - 3.0, 0.0, 1.0)
		archer.evaluate_charged_timeline(4, t)
		_evaluate_release_fx(0.0, false)
	else:
		var rel_t = clamp(T - 4.0, 0.0, 1.0)
		archer.evaluate_charged_timeline(5, rel_t)
		_evaluate_release_fx(rel_t, true)

func _evaluate_release_fx(rel_t: float, is_release_active: bool) -> void:
	if not is_release_active:
		if shockwave_node:
			shockwave_node.visible = false
			if shockwave_node.has_method("reset"):
				shockwave_node.reset()
		shockwave_radius = 0.0
		shockwave_alpha = 0.0
		if projectile_node: projectile_node.visible = false
		if trail_line: trail_line.visible = false
		if ground_tear_rect:
			ground_tear_rect.visible = false
			if ground_tear_rect.material:
				(ground_tear_rect.material as ShaderMaterial).set_shader_parameter("lead_progress", 0.0)
		if camera: camera.offset = Vector2.ZERO
		return
		
	var rel_time = rel_t * release_duration
	var bow_x = archer_base_pos.x + 36.0
	var bow_y = archer_base_pos.y - 74.0
	var feet_x = archer_base_pos.x
	
	# 1. Projectile Flight: launches along +X at constant speed (1500 px/s)
	var arrow_travel_dist = arrow_speed * rel_time
	var arrow_x = bow_x + arrow_travel_dist
	var is_in_flight = (arrow_x <= arrow_max_range)
	
	if projectile_node:
		projectile_node.visible = is_in_flight
		projectile_node.global_position = Vector2(arrow_x, bow_y)
		projectile_node.rotation = 0.0 # Strictly 0° horizontal along aim axis
		
	# 2. Shockwave: Multi-temperature pixel-art shockwave shader + backwards particles
	if shockwave_node:
		if rel_time <= shockwave_duration:
			var s_t = clamp(rel_time / max(0.001, shockwave_duration), 0.0, 1.0)
			shockwave_node.visible = true
			shockwave_node.global_position = Vector2(bow_x, bow_y)
			if shockwave_node.has_method("evaluate_time"):
				shockwave_node.evaluate_time(rel_time)
			shockwave_radius = lerp(12.0, shockwave_max_radius, s_t)
			shockwave_alpha = (1.0 - s_t)
		else:
			shockwave_node.visible = false
			if shockwave_node.has_method("reset"):
				shockwave_node.reset()
			shockwave_radius = 0.0
			shockwave_alpha = 0.0
			
	# 3. Energy Trail: Attached to arrow tail, grows up to max length, trailing end fades
	if trail_line:
		var tail_x = arrow_x - 32.0 # Nock of arrow
		var trail_length = min(trail_max_length, arrow_travel_dist)
		var trail_start_x = tail_x - trail_length
		
		if trail_length > 5.0 and rel_time < (release_duration + trail_fade_duration):
			trail_line.visible = true
			trail_line.clear_points()
			# Sample along the recent trajectory
			var steps = 12
			for i in range(steps + 1):
				var px = lerp(trail_start_x, tail_x, float(i) / float(steps))
				trail_line.add_point(Vector2(px, bow_y))
				
			var fade = 1.0
			if arrow_x > arrow_max_range:
				fade = clamp(1.0 - (arrow_x - arrow_max_range) / 300.0, 0.0, 1.0)
			trail_line.modulate.a = fade
		else:
			trail_line.visible = false
			
	# 4. Ground Tear: Starts at archer's feet as mound, spreads along +X strictly behind arrow via lead_progress
	if ground_tear_rect and ground_tear_rect.material:
		ground_tear_rect.visible = true
		var tear_total_width = ground_tear_rect.size.x
		var tear_start_x = ground_tear_rect.global_position.x
		
		# Leading edge follows behind arrow and NEVER ahead of it
		var tear_lead_x = clamp(arrow_x - ground_tear_lag, tear_start_x, tear_start_x + tear_total_width)
		var lead_prog = clamp((tear_lead_x - tear_start_x) / max(1.0, tear_total_width), 0.0, 1.0)
		
		var fade_prog = 0.0
		if rel_time > 0.45:
			fade_prog = clamp((rel_time - 0.45) / max(0.01, ground_tear_fade_duration), 0.0, 1.0)
			
		var mat = ground_tear_rect.material as ShaderMaterial
		mat.set_shader_parameter("lead_progress", lead_prog)
		mat.set_shader_parameter("fade_progress", fade_prog)
		
	# 5. Camera Shake: Subtle, ~3px amplitude, decaying to 0 over 0.2s
	if camera:
		if rel_time <= camera_shake_duration:
			var shake_t = rel_time / max(0.001, camera_shake_duration)
			var decay = 1.0 - shake_t
			var shake_offset = sin(rel_time * 65.0) * camera_shake_amplitude * decay
			camera.offset = Vector2(0.0, shake_offset)
		else:
			camera.offset = Vector2.ZERO

func _update_ui_telemetry(title: String, desc: String) -> void:
	if label_frame_info:
		label_frame_info.text = "ACTIVE STATE: %s" % title
	if label_details:
		label_details.text = desc
