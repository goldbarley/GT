extends Node2D

signal pressure_plate_activated(pressed: bool)

@onready var plate_sprite: Sprite2D = $Interactive/PressurePlate/Sprite2D
@onready var plate_area: Area2D = $Interactive/PressurePlate

var is_pressed := false

func _ready() -> void:
	plate_area.body_entered.connect(_on_plate_body_entered)
	plate_area.body_exited.connect(_on_plate_body_exited)

func _on_plate_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Knight":
		is_pressed = true
		plate_sprite.texture = preload("res://sprites/dungeon/button/frame_2.png")
		pressure_plate_activated.emit(true)

func _on_plate_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Knight":
		is_pressed = false
		plate_sprite.texture = preload("res://sprites/dungeon/button/frame_0.png")
		pressure_plate_activated.emit(false)
