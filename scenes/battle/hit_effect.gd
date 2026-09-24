class_name BattleHitEffect
extends Node2D

@onready var _sprite: AnimatedSprite2D = $Sprite

func setup(frames: SpriteFrames, is_crit: bool) -> void:
	if _sprite == null or frames == null or frames.get_animation_names().is_empty():
		queue_free()
		return
	_sprite.sprite_frames = frames
	var animation_name: String = frames.get_animation_names()[0]
	if is_crit and frames.has_animation("impactredsmall"):
		animation_name = "impactredsmall"
	elif frames.has_animation("impactorangemedium"):
		animation_name = "impactorangemedium"
	elif frames.has_animation("impactbluemedium"):
		animation_name = "impactbluemedium"
	_sprite.animation = animation_name
	_sprite.scale = Vector2.ONE * (0.75 if is_crit else 0.55)
	_sprite.play()
	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(0.65)
	cleanup_timer.timeout.connect(queue_free)
