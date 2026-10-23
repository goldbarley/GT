class_name HitEffect
extends Node2D

## Reusable Hit Impact Animation Component
##
## Plays a 9-frame starburst hit impact animation using hit_effect.gdshader.
## Can be placed directly into a scene or spawned dynamically by CharacterController / UniversalMotor.

signal hit_finished

const HitShader := preload("res://shaders/hit_effect.gdshader")
const HitTexture := preload("res://sprites/effects/hit/hit_spark_sheet.png")

@export var duration: float = 0.28
@export var hit_color: Color = Color.WHITE

var _spark: ColorRect = null
var _material: ShaderMaterial = null
var _elapsed: float = 0.0
var _playing: bool = false


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _ready() -> void:
	set_process(false)
	if _spark == null:
		_setup_nodes()


func _setup_nodes() -> void:
	_material = ShaderMaterial.new()
	_material.shader = HitShader
	_material.set_shader_parameter("hit_texture", HitTexture)
	_material.set_shader_parameter("num_frames", 9.0)
	_material.set_shader_parameter("progress", 0.0)
	_material.set_shader_parameter("hit_color", hit_color)
	_material.set_shader_parameter("overlay_on_sprite", false)

	_spark = ColorRect.new()
	_spark.name = "Spark"
	_spark.size = Vector2(128, 128)
	# Center the 128x128 quad around local (0, 0)
	_spark.position = Vector2(-64, -64)
	_spark.material = _material
	_spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spark.visible = false
	add_child(_spark)


func _process(delta: float) -> void:
	advance(delta)


## Advances the hit effect by delta time.
func advance(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	var d := duration if duration > 0.0 else 0.28
	var p := clampf(_elapsed / d, 0.0, 1.0)
	_set_progress(p)
	if _elapsed >= d:
		_on_finished()


## Plays the 9-frame hit animation sequence.
func play(custom_duration: float = -1.0, tint: Color = Color.WHITE) -> void:
	if _spark == null:
		_setup_nodes()

	duration = duration if custom_duration <= 0.0 else custom_duration
	_elapsed = 0.0
	_playing = true
	_set_progress(0.0)
	_material.set_shader_parameter("hit_color", tint if tint != Color.WHITE else hit_color)
	_spark.visible = true
	set_process(true)


func _set_progress(val: float) -> void:
	if _material:
		_material.set_shader_parameter("progress", val)


func _on_finished() -> void:
	_playing = false
	set_process(false)
	_set_progress(0.0)
	if _spark:
		_spark.visible = false
	hit_finished.emit()


func is_playing() -> bool:
	return _playing


## Convenience method to spawn, play, and auto-cleanup.
static func spawn_at(parent: Node, world_pos: Vector2, scale_factor: float = 1.0, custom_duration: float = 0.28, tint: Color = Color.WHITE) -> Node2D:
	if parent == null:
		return null
	var effect = load("res://scripts/hit_effect.gd").new()
	effect.scale = Vector2(scale_factor, scale_factor)
	parent.add_child(effect)
	effect.global_position = world_pos
	effect.hit_finished.connect(func(): effect.queue_free())
	effect.play(custom_duration, tint)
	return effect
