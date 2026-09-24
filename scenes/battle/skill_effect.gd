class_name SkillEffect
extends Node2D

var _life_time: float = 0.72
var _sprite: AnimatedSprite2D
var _fallback: Polygon2D
var _label: Label

func _ready() -> void:
	z_index = 30
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "EffectSprite"
	add_child(_sprite)
	_fallback = Polygon2D.new()
	_fallback.name = "Fallback"
	_fallback.polygon = PackedVector2Array([
		Vector2(-10.0, 0.0), Vector2(0.0, -12.0), Vector2(10.0, 0.0), Vector2(0.0, 8.0)
	])
	add_child(_fallback)
	_label = Label.new()
	_label.name = "Label"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.position = Vector2(-55.0, -38.0)
	_label.size = Vector2(110.0, 22.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_constant_override("outline_size", 3)
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.95))
	add_child(_label)
	set_process(true)

func setup(fx_id: String, effect_name: String, element: String) -> void:
	var frames: SpriteFrames = load("res://addons/duelyst_animated_sprites/spriteframes/fx/%s.tres" % fx_id) as SpriteFrames
	if frames != null and not frames.get_animation_names().is_empty():
		_sprite.sprite_frames = frames
		_sprite.animation = frames.get_animation_names()[0]
		_sprite.scale = Vector2.ONE * 0.85
		_sprite.play()
		_fallback.visible = false
	else:
		_sprite.visible = false
		_fallback.color = CombatMath.get_element_color(element)
	_label.text = effect_name
	_label.add_theme_color_override("font_color", CombatMath.get_element_color(element))

func _process(delta: float) -> void:
	_life_time -= delta
	position.y -= 12.0 * delta
	var ratio: float = clampf(_life_time / 0.72, 0.0, 1.0)
	modulate.a = ratio
	if _life_time <= 0.0:
		queue_free()
