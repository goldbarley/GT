extends Node2D

## Interactive test bench for the 9-frame hit animation shader and HitEffect component.

const HitEffectClass := preload("res://scripts/hit_effect.gd")

@onready var archer_container: Node2D = $ArcherContainer
@onready var duration_slider: HSlider = $CanvasLayer/Panel/VBoxContainer/HBoxDuration/SliderDuration
@onready var duration_label: Label = $CanvasLayer/Panel/VBoxContainer/HBoxDuration/ValDuration
@onready var scale_slider: HSlider = $CanvasLayer/Panel/VBoxContainer/HBoxScale/SliderScale
@onready var scale_label: Label = $CanvasLayer/Panel/VBoxContainer/HBoxScale/ValScale

var archer_controller: ArcherController
var current_duration: float = 0.28
var current_scale: float = 2.5
var current_color: Color = Color.WHITE

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Setup an archer character to receive hits
	archer_controller = ArcherController.new()
	archer_controller.scale = Vector2(4, 4)
	archer_controller.position = Vector2(640, 420)
	archer_container.add_child(archer_controller)

	# Wire up UI
	$CanvasLayer/Panel/VBoxContainer/HBoxButtons/BtnNormal.pressed.connect(func():
		current_color = Color.WHITE
		_play_hit_on_archer()
	)
	$CanvasLayer/Panel/VBoxContainer/HBoxButtons/BtnCrit.pressed.connect(func():
		current_color = Color(1.0, 0.85, 0.2, 1.0) # Gold
		_play_hit_on_archer()
	)
	$CanvasLayer/Panel/VBoxContainer/HBoxButtons/BtnFire.pressed.connect(func():
		current_color = Color(1.0, 0.3, 0.1, 1.0) # Fire red
		_play_hit_on_archer()
	)
	$CanvasLayer/Panel/VBoxContainer/HBoxButtons/BtnIce.pressed.connect(func():
		current_color = Color(0.2, 0.8, 1.0, 1.0) # Ice cyan
		_play_hit_on_archer()
	)

	duration_slider.value_changed.connect(func(val):
		current_duration = val
		duration_label.text = "%.2fs" % val
	)
	scale_slider.value_changed.connect(func(val):
		current_scale = val
		scale_label.text = "%.1fx" % val
	)

func _play_hit_on_archer() -> void:
	if archer_controller:
		archer_controller.play_hit(Vector2(0, -15), current_duration, current_color)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		HitEffectClass.spawn_at(self, event.position, current_scale, current_duration, current_color)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_H:
			_play_hit_on_archer()
