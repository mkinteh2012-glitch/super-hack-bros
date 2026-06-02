extends Node2D

@onready var raycast: RayCast2D = $RayCast2D
@onready var shadow_sprite: Sprite2D = $Sprite2D

@export var max_distance: float = 300.0

func _physics_process(_delta: float) -> void:
	# Keep the RayCast pointing straight down regardless of parent rotation
	raycast.global_rotation = 0.0
	
	if raycast.is_colliding():
		shadow_sprite.visible = true
		
		# 1. Find where the ground is relative to this node
		var collision_point: Vector2 = raycast.get_collision_point()
		var local_collision: Vector2 = to_local(collision_point)
		
		# 2. Lock horizontal (X) to the parent, move only vertical (Y) to the floor
		shadow_sprite.position.y = local_collision.y
		shadow_sprite.position.x = 0.0 # Stays perfectly centered under the parent
		shadow_sprite.global_rotation = 0.0 # Keeps shadow flat on the ground
		
		# 3. Calculate distance to scale and fade the shadow
		var distance: float = global_position.distance_to(collision_point)
		var ratio: float = clamp(distance / max_distance, 0.0, 1.0)
		
		# Smoothly fade out and shrink as the parent goes higher
		shadow_sprite.modulate.a = 1.0 - ratio
		var shadow_scale: float = lerp(1.0, 0.3, ratio)
		shadow_sprite.scale = Vector2(shadow_scale, shadow_scale)
	else:
		# Hide completely if no ground is detected within range
		shadow_sprite.visible = false
