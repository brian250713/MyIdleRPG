class_name FloatingText
extends Label

var _life_time: float = 2.4
var _velocity: Vector2 = Vector2(0.0, -28.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	set_process(true)
	add_to_group("transient")

func setup(message: String, color: Color = Color.WHITE, font_size: int = 14) -> void:
	text = message
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	size = Vector2(220.0, 28.0)
	position -= Vector2(110.0, 14.0)
	add_theme_font_size_override("font_size", font_size)
	add_theme_color_override("font_color", color)
	add_theme_color_override("font_outline_color", Color(0.01, 0.01, 0.02, 1.0))
	add_theme_constant_override("outline_size", 6)
	add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	add_theme_constant_override("shadow_offset_x", 2)
	add_theme_constant_override("shadow_offset_y", 2)
	add_theme_constant_override("shadow_outline_size", 2)
	modulate = Color.WHITE

func _process(delta: float) -> void:
	_life_time -= delta
	position += _velocity * delta
	_velocity.y += 12.0 * delta
	modulate.a = clampf(_life_time / 2.4, 0.0, 1.0)
	if _life_time <= 0.0:
		queue_free()
