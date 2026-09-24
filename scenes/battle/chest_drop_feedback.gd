class_name ChestDropFeedback
extends Node2D

@onready var _label: Label = $Label

var _life_time: float = 1.15
var _velocity: Vector2 = Vector2(0.0, -28.0)

func _ready() -> void:
	z_index = 25
	set_process(true)

func setup(chest_type: String) -> void:
	var display_name: String = "白箱"
	var color: Color = Color(0.92, 0.92, 0.92)
	if chest_type == "blue":
		display_name = "藍箱"
		color = Color(0.30, 0.65, 1.0)
	elif chest_type == "act_boss":
		display_name = "幕箱"
		color = Color(1.0, 0.55, 0.16)
	_label.text = display_name
	_label.add_theme_color_override("font_color", color)

func _process(delta: float) -> void:
	_life_time -= delta
	position += _velocity * delta
	_velocity.y += 18.0 * delta
	_label.modulate.a = clampf(_life_time / 1.15, 0.0, 1.0)
	if _life_time <= 0.0:
		queue_free()
