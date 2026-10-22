extends Node2D
class_name GroundTear

@onready var tear_rect: ColorRect = $TearRect

@export var duration: float = 0.8
var elapsed: float = 0.0

func _process(delta: float) -> void:
	elapsed += delta
	var progress = clamp(elapsed / duration, 0.0, 1.0)
	
	if tear_rect and tear_rect.material:
		(tear_rect.material as ShaderMaterial).set_shader_parameter("tear_progress", progress)
		
	if elapsed >= duration:
		queue_free()
