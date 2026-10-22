extends Node2D

# Perspective & Model references
@onready var knight_right: KnightDev = $Knight
@onready var knight: KnightDev = $Knight
@onready var knight_back: KnightBack = $KnightBack
@onready var ref_overlay: Sprite2D = $ReferenceOverlay
@onready var camera: Camera2D = $Camera2D

var tex_ref_right: Texture2D = preload("res://sprites/assembled_reference.png")
var tex_ref_back: Texture2D = preload("res://knight_back/sprites/assembled_reference.png")

var active_knight: Node2D = null

# Top Bar
@onready var btn_view_right: Button = $CanvasLayer/TopPanel/HBoxTop/BtnViewRight
@onready var btn_view_back: Button = $CanvasLayer/TopPanel/HBoxTop/BtnViewBack
@onready var check_overlay: CheckBox = $CanvasLayer/TopPanel/HBoxTop/CheckOverlay
@onready var check_pivots: CheckBox = $CanvasLayer/TopPanel/HBoxTop/CheckPivots

# Controls: Attacks & Speeds
@onready var btn_attack: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls/BtnAttack
@onready var btn_stab: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls/BtnStab
@onready var btn_plunge: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls/BtnPlunge

@onready var btn_speed_100: Button = $CanvasLayer/Panel/VBoxContainer/HBoxSpeeds/Btn100
@onready var btn_speed_50: Button = $CanvasLayer/Panel/VBoxContainer/HBoxSpeeds/Btn50
@onready var btn_speed_25: Button = $CanvasLayer/Panel/VBoxContainer/HBoxSpeeds/Btn25
@onready var btn_speed_10: Button = $CanvasLayer/Panel/VBoxContainer/HBoxSpeeds/Btn10

# Controls: Frame Steps & Scrub
@onready var btn_f1: Button = $CanvasLayer/Panel/VBoxContainer/HBoxFrames/BtnF1
@onready var btn_f2: Button = $CanvasLayer/Panel/VBoxContainer/HBoxFrames/BtnF2
@onready var btn_f3: Button = $CanvasLayer/Panel/VBoxContainer/HBoxFrames/BtnF3
@onready var btn_f4: Button = $CanvasLayer/Panel/VBoxContainer/HBoxFrames/BtnF4
@onready var btn_f5: Button = $CanvasLayer/Panel/VBoxContainer/HBoxFrames/BtnF5
@onready var btn_f6: Button = $CanvasLayer/Panel/VBoxContainer/HBoxFrames/BtnF6
@onready var btn_f7: Button = $CanvasLayer/Panel/VBoxContainer/HBoxFrames/BtnF7
@onready var btn_f8: Button = $CanvasLayer/Panel/VBoxContainer/HBoxFrames/BtnF8
@onready var btn_f9: Button = $CanvasLayer/Panel/VBoxContainer/HBoxFrames/BtnF9
@onready var btn_f10: Button = $CanvasLayer/Panel/VBoxContainer/HBoxFrames/BtnF10
@onready var slider_scrub: HSlider = $CanvasLayer/Panel/VBoxContainer/HBoxScrub/SliderScrub

# Telemetry
@onready var label_frame: Label = $CanvasLayer/Panel/VBoxContainer/GridTelemetry/ValFrame
@onready var label_phase: Label = $CanvasLayer/Panel/VBoxContainer/GridTelemetry/ValPhase
@onready var label_wrist_status: Label = $CanvasLayer/Panel/VBoxContainer/GridTelemetry/ValWristStatus
@onready var label_slash: Label = $CanvasLayer/Panel/VBoxContainer/GridTelemetry/ValSlash
@onready var label_shoulder: Label = $CanvasLayer/Panel/VBoxContainer/GridTelemetry/ValShoulder
@onready var label_wrist: Label = $CanvasLayer/Panel/VBoxContainer/GridTelemetry/ValWrist
@onready var label_scale: Label = $CanvasLayer/Panel/VBoxContainer/GridTelemetry/ValScale
@onready var label_y_offset: Label = $CanvasLayer/Panel/VBoxContainer/GridTelemetry/ValYOffset

# Live Tuning Sliders & Labels
@onready var slider_sh_x: HSlider = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxShoulderX/Slider
@onready var val_sh_x: Label = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxShoulderX/Val
@onready var slider_sh_y: HSlider = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxShoulderY/Slider
@onready var val_sh_y: Label = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxShoulderY/Val
@onready var slider_sh_rot: HSlider = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxShoulderRot/Slider
@onready var val_sh_rot: Label = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxShoulderRot/Val

@onready var slider_wr_x: HSlider = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxWristX/Slider
@onready var val_wr_x: Label = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxWristX/Val
@onready var slider_wr_y: HSlider = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxWristY/Slider
@onready var val_wr_y: Label = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxWristY/Val
@onready var slider_wr_rot: HSlider = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxWristRot/Slider
@onready var val_wr_rot: Label = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxWristRot/Val

@onready var slider_sw_x: HSlider = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxSwordX/Slider
@onready var val_sw_x: Label = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxSwordX/Val
@onready var slider_sw_y: HSlider = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxSwordY/Slider
@onready var val_sw_y: Label = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxSwordY/Val

@onready var slider_sw_scale: HSlider = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxSwordScale/Slider
@onready var val_sw_scale: Label = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxSwordScale/Val
@onready var slider_ar_scale: HSlider = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxArmScale/Slider
@onready var val_ar_scale: Label = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxArmScale/Val
@onready var slider_b_x: HSlider = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxBodyX/Slider
@onready var val_b_x: Label = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxBodyX/Val
@onready var slider_b_y: HSlider = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxBodyY/Slider
@onready var val_b_y: Label = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxBodyY/Val

@onready var check_arm_z: CheckBox = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxChecks/CheckArmZ
@onready var check_sword_z: CheckBox = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxChecks/CheckSwordZ

@onready var btn_sync_pose: Button = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxButtons/BtnSyncPose
@onready var btn_reset_rest: Button = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/HBoxButtons/BtnResetRest
@onready var btn_copy_pose: Button = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/BtnCopyPose
@onready var text_pose_output: TextEdit = $CanvasLayer/TuningScroll/TuningPanel/VBoxTuning/TextPoseOutput

var is_user_scrubbing: bool = false
var is_updating_sliders_programmatically: bool = false
var trauma: float = 0.0
var trauma_power: float = 2.0
var max_shake_offset: float = 14.0
var max_shake_roll: float = 0.04
var _is_initialized: bool = false

func _ready() -> void:
	if _is_initialized:
		return
	_is_initialized = true
	if knight_right:
		knight_right._ready()
		knight_right.camera_shake_requested.connect(_on_camera_shake_requested)
	if knight_back:
		knight_back._ready()
		knight_back.camera_shake_requested.connect(_on_camera_shake_requested)
		
	# Connect perspective buttons
	if btn_view_right:
		btn_view_right.pressed.connect(func(): set_perspective(false))
	if btn_view_back:
		btn_view_back.pressed.connect(func(): set_perspective(true))
	if check_overlay:
		check_overlay.toggled.connect(_on_overlay_toggled)
	if check_pivots:
		check_pivots.toggled.connect(_on_pivots_toggled)
		
	# Connect attack buttons
	if btn_attack:
		btn_attack.pressed.connect(func(): if active_knight: active_knight.trigger_slash())
	if btn_stab:
		btn_stab.pressed.connect(func(): if active_knight: active_knight.trigger_stab())
	if btn_plunge:
		btn_plunge.pressed.connect(func(): if active_knight: active_knight.trigger_plunge())
		
	# Connect speeds
	if btn_speed_100: btn_speed_100.pressed.connect(func(): set_playback_speed(1.0))
	if btn_speed_50: btn_speed_50.pressed.connect(func(): set_playback_speed(0.5))
	if btn_speed_25: btn_speed_25.pressed.connect(func(): set_playback_speed(0.25))
	if btn_speed_10: btn_speed_10.pressed.connect(func(): set_playback_speed(0.10))
	
	# Connect frame buttons
	var frame_btns = [btn_f1, btn_f2, btn_f3, btn_f4, btn_f5, btn_f6, btn_f7, btn_f8, btn_f9, btn_f10]
	for idx in range(frame_btns.size()):
		var b = frame_btns[idx]
		if b:
			var f_num = idx + 1
			b.pressed.connect(func(): _on_frame_button_pressed(f_num))
			
	# Connect scrub slider
	if slider_scrub:
		slider_scrub.drag_started.connect(func(): is_user_scrubbing = true)
		slider_scrub.drag_ended.connect(func(_val): is_user_scrubbing = false)
		slider_scrub.value_changed.connect(_on_scrub_value_changed)
		
	# Connect tuning sliders
	_connect_tuning_sliders()
	
	# Connect tuning buttons
	if btn_sync_pose:
		btn_sync_pose.pressed.connect(sync_tuning_sliders)
	if btn_reset_rest:
		btn_reset_rest.pressed.connect(_on_reset_rest_pressed)
	if btn_copy_pose:
		btn_copy_pose.pressed.connect(_on_copy_pose_pressed)
		
	# Start with Back Perspective by default (user's active task), or Right view
	set_perspective(true)
	_highlight_speed_button(1.0)

func set_perspective(is_back: bool) -> void:
	if is_back:
		if knight_right: knight_right.visible = false
		if knight_back:
			knight_back.visible = true
			active_knight = knight_back
		if ref_overlay:
			ref_overlay.texture = tex_ref_back
			ref_overlay.offset = Vector2(-16, -32)
		if btn_view_back: btn_view_back.modulate = Color(1.3, 1.3, 0.6)
		if btn_view_right: btn_view_right.modulate = Color.WHITE
	else:
		if knight_back: knight_back.visible = false
		if knight_right:
			knight_right.visible = true
			active_knight = knight_right
		if ref_overlay:
			ref_overlay.texture = tex_ref_right
			ref_overlay.offset = Vector2(-14, -32)
	if check_pivots and active_knight and "show_pivot_markers" in active_knight:
		active_knight.show_pivot_markers = check_pivots.button_pressed
		active_knight.queue_redraw()
		
	sync_tuning_sliders()

func _on_pivots_toggled(toggled_on: bool) -> void:
	if active_knight and "show_pivot_markers" in active_knight:
		active_knight.show_pivot_markers = toggled_on
		active_knight.queue_redraw()

func _connect_tuning_sliders() -> void:
	var sliders = [
		slider_sh_x, slider_sh_y, slider_sh_rot,
		slider_wr_x, slider_wr_y, slider_wr_rot,
		slider_sw_x, slider_sw_y,
		slider_sw_scale, slider_ar_scale,
		slider_b_x, slider_b_y
	]
	for s in sliders:
		if s:
			s.value_changed.connect(func(_v): _on_tuning_changed())
			s.drag_ended.connect(func(_v): _on_tuning_changed())
			
	if check_arm_z:
		check_arm_z.toggled.connect(func(_b): _on_tuning_changed())
	if check_sword_z:
		check_sword_z.toggled.connect(func(_b): _on_tuning_changed())

func _on_tuning_changed() -> void:
	if is_updating_sliders_programmatically or not active_knight:
		return
		
	var sh_pos = Vector2(slider_sh_x.value, slider_sh_y.value) if slider_sh_x and slider_sh_y else Vector2.ZERO
	var wr_pos = Vector2(slider_wr_x.value, slider_wr_y.value) if slider_wr_x and slider_wr_y else Vector2.ZERO
	var sw_pos = Vector2(slider_sw_x.value, slider_sw_y.value) if slider_sw_x and slider_sw_y else Vector2.ZERO
	var sh_rot = slider_sh_rot.value if slider_sh_rot else 0.0
	var wr_rot = slider_wr_rot.value if slider_wr_rot else 0.0
	var sw_sc = Vector2(slider_sw_scale.value, slider_sw_scale.value) if slider_sw_scale else Vector2.ONE
	var ar_sc = Vector2(slider_ar_scale.value, slider_ar_scale.value) if slider_ar_scale else Vector2.ONE
	var b_pos = Vector2(slider_b_x.value, slider_b_y.value) if slider_b_x and slider_b_y else Vector2.ZERO
	
	var ar_z = 1 if (check_arm_z and check_arm_z.button_pressed) else -1
	var sw_z = 1 if (check_sword_z and check_sword_z.button_pressed) else -1
	
	_update_tuning_labels(sh_pos, wr_pos, sw_pos, sh_rot, wr_rot, sw_sc.x, ar_sc.x, b_pos)
	
	if active_knight.has_method("apply_live_tuning"):
		active_knight.apply_live_tuning(sh_pos, wr_pos, sw_pos, sh_rot, wr_rot, sw_sc, ar_sc, b_pos, ar_z, sw_z)
	if active_knight.has_method("queue_redraw"):
		active_knight.queue_redraw()
		
	_display_pose_code()

func _update_tuning_labels(sh_pos: Vector2, wr_pos: Vector2, sw_pos: Vector2, sh_rot: float, wr_rot: float, sw_sc: float, ar_sc: float, b_pos: Vector2) -> void:
	if val_sh_x: val_sh_x.text = "%.1f" % sh_pos.x
	if val_sh_y: val_sh_y.text = "%.1f" % sh_pos.y
	if val_sh_rot: val_sh_rot.text = "%d°" % int(round(sh_rot))
	if val_wr_x: val_wr_x.text = "%.1f" % wr_pos.x
	if val_wr_y: val_wr_y.text = "%.1f" % wr_pos.y
	if val_wr_rot: val_wr_rot.text = "%d°" % int(round(wr_rot))
	if val_sw_x: val_sw_x.text = "%.1f" % sw_pos.x
	if val_sw_y: val_sw_y.text = "%.1f" % sw_pos.y
	if val_sw_scale: val_sw_scale.text = "%.2fx" % sw_sc
	if val_ar_scale: val_ar_scale.text = "%.2fx" % ar_sc
	if val_b_x: val_b_x.text = "%.1f" % b_pos.x
	if val_b_y: val_b_y.text = "%.1f" % b_pos.y

func sync_tuning_sliders() -> void:
	if not active_knight or not active_knight.has_method("get_live_tuning_state"):
		return
		
	var st: Dictionary = active_knight.get_live_tuning_state()
	is_updating_sliders_programmatically = true
	
	var sh_p: Vector2 = st.get("shoulder_pos", Vector2.ZERO)
	var wr_p: Vector2 = st.get("wrist_pos", Vector2.ZERO)
	var sw_p: Vector2 = st.get("sword_pos", Vector2.ZERO)
	var sh_deg: float = st.get("shoulder_deg", 0.0)
	var wr_deg: float = st.get("wrist_deg", 0.0)
	var sw_sc: Vector2 = st.get("sword_scale", Vector2.ONE)
	var ar_sc: Vector2 = st.get("arm_scale", Vector2.ONE)
	var b_p: Vector2 = st.get("body_pos", Vector2.ZERO)
	var ar_z: int = st.get("arm_z", 1)
	var sw_z: int = st.get("sword_z", -1)
	
	if slider_sh_x: slider_sh_x.value = sh_p.x
	if slider_sh_y: slider_sh_y.value = sh_p.y
	if slider_sh_rot: slider_sh_rot.value = sh_deg
	
	if slider_wr_x: slider_wr_x.value = wr_p.x
	if slider_wr_y: slider_wr_y.value = wr_p.y
	if slider_wr_rot: slider_wr_rot.value = wr_deg
	
	if slider_sw_x: slider_sw_x.value = sw_p.x
	if slider_sw_y: slider_sw_y.value = sw_p.y
	
	if slider_sw_scale: slider_sw_scale.value = sw_sc.x
	if slider_ar_scale: slider_ar_scale.value = ar_sc.x
	if slider_b_x: slider_b_x.value = b_p.x
	if slider_b_y: slider_b_y.value = b_p.y
	
	if check_arm_z: check_arm_z.button_pressed = (ar_z > 0)
	if check_sword_z: check_sword_z.button_pressed = (sw_z > 0)
	
	_update_tuning_labels(sh_p, wr_p, sw_p, sh_deg, wr_deg, sw_sc.x, ar_sc.x, b_p)
	
	is_updating_sliders_programmatically = false
	_display_pose_code()

func _display_pose_code() -> void:
	if not text_pose_output:
		return
	var code = _generate_pose_dict_string()
	text_pose_output.text = code

func _generate_pose_dict_string() -> String:
	var sh_p = Vector2(slider_sh_x.value, slider_sh_y.value) if slider_sh_x and slider_sh_y else Vector2.ZERO
	var wr_p = Vector2(slider_wr_x.value, slider_wr_y.value) if slider_wr_x and slider_wr_y else Vector2.ZERO
	var sw_p = Vector2(slider_sw_x.value, slider_sw_y.value) if slider_sw_x and slider_sw_y else Vector2.ZERO
	var sh_deg = slider_sh_rot.value if slider_sh_rot else 0.0
	var wr_deg = slider_wr_rot.value if slider_wr_rot else 0.0
	var sw_sc = slider_sw_scale.value if slider_sw_scale else 1.0
	var ar_sc = slider_ar_scale.value if slider_ar_scale else 1.0
	var b_p = Vector2(slider_b_x.value, slider_b_y.value) if slider_b_x and slider_b_y else Vector2.ZERO
	var ar_z = 1 if (check_arm_z and check_arm_z.button_pressed) else -1
	var sw_z = 1 if (check_sword_z and check_sword_z.button_pressed) else -1
	
	return '{\n\t"shoulder_pos": Vector2(%.1f, %.1f),\n\t"wrist_pos": Vector2(%.1f, %.1f),\n\t"sword_pos": Vector2(%.1f, %.1f),\n\t"shoulder_deg": %.1f,\n\t"wrist_deg": %.1f,\n\t"sword_scale": Vector2(%.2f, %.2f),\n\t"arm_scale": Vector2(%.2f, %.2f),\n\t"body_pos": Vector2(%.1f, %.1f),\n\t"arm_z": %d,\n\t"sword_z": %d\n}' % [
		sh_p.x, sh_p.y,
		wr_p.x, wr_p.y,
		sw_p.x, sw_p.y,
		sh_deg, wr_deg,
		sw_sc, sw_sc,
		ar_sc, ar_sc,
		b_p.x, b_p.y,
		ar_z, sw_z
	]

func _on_copy_pose_pressed() -> void:
	var pose_str = _generate_pose_dict_string()
	DisplayServer.clipboard_set(pose_str)
	print("\n=== CALIBRATED POSE COPIED TO CLIPBOARD ===\n" + pose_str + "\n==========================================\n")
	if btn_copy_pose:
		var orig_text = btn_copy_pose.text
		btn_copy_pose.text = "✅ COPIED TO CLIPBOARD!"
		get_tree().create_timer(1.2).timeout.connect(func(): if btn_copy_pose: btn_copy_pose.text = orig_text)

func _on_reset_rest_pressed() -> void:
	if active_knight and active_knight.has_method("reset_to_rest"):
		active_knight.reset_to_rest()
	sync_tuning_sliders()

func _on_frame_button_pressed(frame_num: int) -> void:
	if active_knight and active_knight.has_method("jump_to_frame"):
		active_knight.jump_to_frame(frame_num)
		sync_tuning_sliders()

func _on_scrub_value_changed(val: float) -> void:
	if is_user_scrubbing and active_knight and active_knight.has_method("set_scrub_progress"):
		active_knight.set_scrub_progress(val / 100.0)
		sync_tuning_sliders()

func _on_camera_shake_requested(intensity: float) -> void:
	trauma = clamp(trauma + intensity, 0.0, 1.0)

func _on_overlay_toggled(toggled_on: bool) -> void:
	if ref_overlay:
		ref_overlay.visible = toggled_on

func set_playback_speed(speed: float) -> void:
	if active_knight:
		active_knight.playback_speed = speed
	_highlight_speed_button(speed)

func _highlight_speed_button(speed: float) -> void:
	if btn_speed_100: btn_speed_100.modulate = Color.WHITE if speed != 1.0 else Color(1.2, 1.2, 0.5)
	if btn_speed_50: btn_speed_50.modulate = Color.WHITE if speed != 0.5 else Color(1.2, 1.2, 0.5)
	if btn_speed_25: btn_speed_25.modulate = Color.WHITE if speed != 0.25 else Color(1.2, 1.2, 0.5)
	if btn_speed_10: btn_speed_10.modulate = Color.WHITE if speed != 0.10 else Color(1.2, 1.2, 0.5)

func _process(delta: float) -> void:
	# Process screenshake decay
	if trauma > 0.0:
		trauma = max(trauma - delta * 1.6, 0.0)
		var shake: float = pow(trauma, trauma_power)
		if camera:
			camera.offset = Vector2(
				randf_range(-1.0, 1.0) * max_shake_offset * shake,
				randf_range(-1.0, 1.0) * max_shake_offset * shake
			)
			camera.rotation = randf_range(-1.0, 1.0) * max_shake_roll * shake
	else:
		if camera:
			camera.offset = Vector2.ZERO
			camera.rotation = 0.0

	if not active_knight or not active_knight.has_method("get_kinematic_readout"):
		return
		
	var info: Dictionary = active_knight.get_kinematic_readout()
	var is_plunge: bool = (info.get("attack_type", "") == "Plunge Attack")
	var max_f: int = 10 if is_plunge else 7
	
	if not is_user_scrubbing and slider_scrub:
		slider_scrub.value = info.get("progress", 0.0) * 100.0
		
	if label_frame:
		label_frame.text = "Frame %d / %d" % [info.get("frame", 1), max_f]
	if label_phase:
		label_phase.text = str(info.get("phase", ""))
	if label_wrist_status:
		if info.get("wrist_locked", false):
			label_wrist_status.text = "LOCKED (0.0°)"
			label_wrist_status.modulate = Color(0.4, 1.0, 0.4)
		else:
			label_wrist_status.text = "Active"
			label_wrist_status.modulate = Color(1.0, 0.8, 0.4)
	if label_slash:
		label_slash.text = str(info.get("slash_status", info.get("fx_status", "Off")))
	if label_shoulder:
		label_shoulder.text = "%.1f°" % info.get("shoulder_deg", 0.0)
	if label_wrist:
		label_wrist.text = "%.1f°" % info.get("wrist_deg", 0.0)
	if label_scale:
		var sc: float = float(info.get("sword_scale", 1.0))
		label_scale.text = "%.2fx" % sc
		label_scale.modulate = Color(1.0, 0.7, 0.2) if sc > 1.05 else Color(0.6, 0.9, 1.0)
	if label_y_offset:
		var y_off: float = float(info.get("y_offset", info.get("height_offset", 0.0)))
		label_y_offset.text = "%.1f px" % y_off
		if y_off < -5.0:
			label_y_offset.modulate = Color(0.4, 0.9, 1.0)
		elif y_off > 1.0:
			label_y_offset.modulate = Color(1.0, 0.8, 0.3)
		else:
			label_y_offset.modulate = Color(0.7, 0.75, 0.85)
		
	_highlight_frame_button(info.get("frame", 1), is_plunge)

func _highlight_frame_button(current_f: int, is_plunge: bool) -> void:
	var btns = [btn_f1, btn_f2, btn_f3, btn_f4, btn_f5, btn_f6, btn_f7, btn_f8, btn_f9, btn_f10]
	for idx in range(btns.size()):
		var b = btns[idx]
		if b:
			if not is_plunge and idx >= 7:
				b.visible = false
			else:
				b.visible = true
				b.modulate = Color(1.3, 1.3, 0.6) if (idx + 1) == current_f else Color.WHITE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			# Toggle perspective with Tab
			set_perspective(active_knight != knight_back)
		elif event.keycode == KEY_Q:
			if active_knight: active_knight.trigger_slash()
		elif event.keycode == KEY_E:
			if active_knight: active_knight.trigger_stab()
		elif event.keycode == KEY_SPACE or event.keycode == KEY_W:
			if active_knight: active_knight.trigger_plunge()
		elif event.keycode == KEY_R:
			if check_overlay:
				check_overlay.button_pressed = not check_overlay.button_pressed
		elif event.keycode == KEY_P:
			if check_pivots:
				check_pivots.button_pressed = not check_pivots.button_pressed
		elif event.keycode == KEY_1:
			set_playback_speed(1.0)
		elif event.keycode == KEY_2:
			set_playback_speed(0.5)
		elif event.keycode == KEY_3:
			set_playback_speed(0.25)
		elif event.keycode == KEY_4:
			set_playback_speed(0.10)
		elif event.keycode == KEY_F1:
			_on_frame_button_pressed(1)
		elif event.keycode == KEY_F2:
			_on_frame_button_pressed(2)
		elif event.keycode == KEY_F3:
			_on_frame_button_pressed(3)
		elif event.keycode == KEY_F4:
			_on_frame_button_pressed(4)
		elif event.keycode == KEY_F5:
			_on_frame_button_pressed(5)
		elif event.keycode == KEY_F6:
			_on_frame_button_pressed(6)
		elif event.keycode == KEY_F7:
			_on_frame_button_pressed(7)
		elif event.keycode == KEY_F8:
			_on_frame_button_pressed(8)
		elif event.keycode == KEY_F9:
			_on_frame_button_pressed(9)
		elif event.keycode == KEY_F10:
			_on_frame_button_pressed(10)
