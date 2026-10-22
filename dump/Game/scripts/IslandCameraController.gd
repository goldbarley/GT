extends Camera2D
class_name IslandCameraController

@export var target_node: Node2D = null
@export var rotation_duration: float = 0.35

var current_angle_deg: float = 0.0
var active_tween: Tween = null

signal camera_angle_changed(angle_deg: float)

func _ready() -> void:
	ignore_rotation = false
	zoom = Vector2(2.5, 2.5)
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	rotation = 0.0
	current_angle_deg = 0.0

func _process(_delta: float) -> void:
	if target_node:
		global_position = target_node.global_position

func rotate_by_degrees(delta_deg: float) -> void:
	var next_angle = wrapf(current_angle_deg + delta_deg, -180.0, 180.0)
	set_angle_degrees(next_angle)

func set_angle_degrees(target_deg: float) -> void:
	current_angle_deg = wrapf(target_deg, -180.0, 180.0)
	
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		
	active_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var target_rad = deg_to_rad(current_angle_deg)
	active_tween.tween_property(self, "rotation", target_rad, rotation_duration)
	
	camera_angle_changed.emit(current_angle_deg)
	if target_node and target_node.has_method("set_perspective_from_angle"):
		target_node.set_perspective_from_angle(current_angle_deg)
