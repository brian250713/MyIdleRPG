class_name DamageNumber
extends Label

var _life_time: float = 0.85
var _velocity: Vector2 = Vector2(0.0, -35.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 30
	set_process(true)

func setup(amount: int, is_crit: bool, element: String = "physical") -> void:
	text = str(amount)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	size = Vector2(70.0, 24.0)
	position -= Vector2(35.0, 12.0)
	add_theme_font_size_override("font_size", 15 if is_crit else 12)
	var element_color: Color = CombatMath.get_element_color(element)
	if is_crit:
		element_color = element_color.lerp(Color(1.0, 0.95, 0.35, 1.0), 0.35)
	add_theme_color_override("font_color", element_color)
	add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.95))
	add_theme_constant_override("outline_size", 3)
	modulate = Color.WHITE

func _process(delta: float) -> void:
	_life_time -= delta
	position += _velocity * delta
	_velocity.y += 35.0 * delta
	modulate.a = clampf(_life_time / 0.85, 0.0, 1.0)
	if _life_time <= 0.0:
		queue_free()

func thirty_five() -> float:
	return 35.0
