class_name BattleProjectile
extends Node2D

var target: BattleUnit
var damage: int = 1
var is_crit: bool = false
var speed: float = 310.0
var use_animation: bool = false
var sprite_frames: SpriteFrames
var _life_time: float = 2.5
var _sprite: AnimatedSprite2D
var _fallback: Polygon2D

func _ready() -> void:
	_sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	_fallback = get_node_or_null("Fallback") as Polygon2D

func setup(
	projectile_target: BattleUnit,
	projectile_damage: int,
	projectile_crit: bool,
	frames: SpriteFrames,
	animated: bool,
	projectile_speed: float = 310.0
) -> void:
	target = projectile_target
	damage = maxi(1, projectile_damage)
	is_crit = projectile_crit
	sprite_frames = frames
	use_animation = animated and frames != null and frames.has_animation("projectile")
	speed = maxf(80.0, projectile_speed)
	if _sprite == null:
		_sprite = AnimatedSprite2D.new()
		_sprite.name = "Sprite"
		add_child(_sprite)
	if _fallback == null:
		_fallback = Polygon2D.new()
		_fallback.name = "Fallback"
		_fallback.polygon = PackedVector2Array([
			Vector2(-8.0, 0.0), Vector2(8.0, 0.0), Vector2(0.0, -6.0)
		])
		_fallback.color = Color(1.0, 0.72, 0.20, 0.95)
		add_child(_fallback)
	if use_animation:
		_sprite.sprite_frames = sprite_frames
		_sprite.animation = "projectile"
		_sprite.scale = Vector2.ONE * 0.65
		_sprite.play()
		_fallback.visible = false
	else:
		_sprite.visible = false
		_fallback.visible = true

func _process(delta: float) -> void:
	_life_time -= delta
	if _life_time <= 0.0:
		queue_free()
		return
	if target == null or not is_instance_valid(target) or not target.is_alive():
		queue_free()
		return
	var target_position: Vector2 = target.global_position
	var current_position: Vector2 = global_position
	var direction: Vector2 = target_position - current_position
	var distance: float = direction.length()
	if distance <= 14.0:
		target.take_damage(damage, is_crit)
		queue_free()
		return
	if direction.length_squared() > 0.001:
		position += direction.normalized() * speed * delta
	if not use_animation:
		rotation = direction.angle()
