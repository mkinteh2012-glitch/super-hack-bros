extends Area2D

@export var damage: float = 3.0 # Slight damage bump for a special move!
var creator: Node2D = null
@onready var hitbox: CollisionShape2D = $CollisionShape2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	hitbox.disabled = true 
	
	sprite.stop()
	sprite.play("default") 
	
	if not sprite.frame_changed.is_connected(_on_frame_changed):
		sprite.frame_changed.connect(_on_frame_changed)
	if not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _on_frame_changed() -> void:
	if sprite.frame >= 2 and sprite.frame <= 6:
		hitbox.disabled = false 
	else:
		hitbox.disabled = true  

func _on_area_entered(area: Area2D) -> void:
	if area.name == "Hurtbox" or area.is_in_group("hurtbox"):
		var opponent = area.get_parent()
		if opponent == creator:
			return
			
		if opponent and opponent.has_method("universal_take_damage"):
			# --- CALC_DIRECTION ---
			# Figures out if the opponent is to the left or right of the spike
			var launch_dir = 1.0
			if opponent.global_position.x < global_position.x:
				launch_dir = -1.0

			# --- THE TWEAKED SPIKE PROFILE ---
			# 1. Damage: 7.0
			# 2. Base X Launch: 500.0 (Strong horizontal burst away from the explosion)
			# 3. Base Y Launch: -400.0 (High vertical pop to send them flying into the upper corners)
			# 4. Knockback Scaling: 3.8 (High multiplier so it kills easily at high %)
			# 5. Hitstun Multiplier: 1.3 (Keeps them locked out of movement while flying)
			opponent.universal_take_damage(damage, launch_dir, 500.0, -400.0, 3.8, 1.3)
			
			if creator and creator.has_method("charge_super_meter"):
				creator.charge_super_meter(3.0)
			
			hitbox.set_deferred("disabled", true)
			print("[SPIKE] Target hit! Exploding and deleting spike instance.")
			queue_free()

func _on_animation_finished() -> void:
	queue_free()
