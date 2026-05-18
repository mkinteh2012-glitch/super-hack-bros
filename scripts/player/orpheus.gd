extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D
@onready var hitbox = $CollisionPolygon2D
@onready var hurtbox = $Hurtbox 
@onready var punch_box = $PunchBox
@onready var punch_hitbox = $PunchBox/PunchHitbox

@export_enum("Player 1:1", "Player 2:2") var player_id: int = 1

# --- Fast Movement Properties ---
@export var speed: float = 230.0          
@export var acceleration: float = 300.0    
@export var friction: float = 1600.0       

# --- Combat & Scaling Physics ---
@export var Jump_Velocity: float = -650.0
@export var base_gravity_multiplier: float = 2.0
@export var fall_gravity_multiplier: float = 3.5
@export var knockback_resistance: float = 650.0 

# --- Combat & Combo Status Pool ---
var damage_percent: float = 0.0 
var combo_count: int = 0             
var combo_reset_timer: float = 0.0   

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_attacking: bool = false
var holding_last_frame: bool = false
var is_in_knockback: bool = false

var input_left: String = ""
var input_right: String = ""
var input_up: String = ""
var input_attack: String = ""

func _ready():
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_sprite_frame_changed)
	
	if punch_box:
		punch_box.area_entered.connect(_on_punch_box_area_entered)

	input_left = "p%d_left" % player_id
	input_right = "p%d_right" % player_id
	input_up = "p%d_up" % player_id
	input_attack = "p%d_attack" % player_id
	
	if punch_hitbox:
		punch_hitbox.disabled = true

	# --- Automatic Layer and Mask Setup ---
	set_collision_layer_value(1, true)
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	
	if hurtbox:
		hurtbox.set_collision_layer_value(1, true)
		hurtbox.set_collision_layer_value(2, true)
		hurtbox.set_collision_mask_value(1, true)
		hurtbox.set_collision_mask_value(2, true)
		
	if punch_box:
		punch_box.set_collision_layer_value(1, true)
		punch_box.set_collision_layer_value(2, true)
		punch_box.set_collision_mask_value(1, true)
		punch_box.set_collision_mask_value(2, true)

func _physics_process(delta):
	queue_redraw()

	# Manage combo window decline decay over time
	if combo_count > 0 and not is_attacking:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0:
			combo_count = 0
			print("[COMBO] Window expired. Reset to 0.")

	# Handle Constant Gravity
	if not is_on_floor():
		if velocity.y > 0:
			velocity.y += gravity * fall_gravity_multiplier * delta
		else:
			velocity.y += gravity * base_gravity_multiplier * delta
		
	# --- Fast Pace Input Buffer & Aerial Trigger Check ---
	# FIX: Removed 'is_on_floor()' constraint so it triggers mid-air!
	if Input.is_action_just_pressed(input_attack) and not is_in_knockback:
		if is_attacking:
			if combo_count < 3:
				trigger_combo_strike()
		else:
			trigger_combo_strike()

	if Input.is_action_just_pressed(input_up) and is_on_floor() and not is_attacking and not is_in_knockback:
		velocity.y = Jump_Velocity
	
	var direction = Input.get_axis(input_left, input_right)

	if not is_attacking and not is_in_knockback:
		if direction != 0:
			velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
			sprite.flip_h = (direction < 0)
			
			if hitbox: hitbox.scale.x = -1.0 if direction < 0 else 1.0
			if punch_box: punch_box.scale.x = -1.0 if direction < 0 else 1.0
			if hurtbox: hurtbox.scale.x = -1.0 if direction < 0 else 1.0
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	
	elif is_in_knockback:
		velocity.x = move_toward(velocity.x, 0.0, knockback_resistance * delta)
		if is_on_floor() and abs(velocity.x) < 30.0:
			is_in_knockback = false
	else:
		# Ground attacks stop you completely, Air attacks let you glide through space using momentum
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		else:
			# Minor air resistance while swinging mid-air
			velocity.x = move_toward(velocity.x, 0.0, friction * 0.15 * delta)
		
	move_and_slide()
	queue_animations(direction)

# Progressive strike command handler
func trigger_combo_strike():
	combo_count += 1
	print("[COMBO] Executing Hit #", combo_count)
	
	is_attacking = true
	holding_last_frame = false
	
	# FIX: Only zero out speed if we are running on the ground!
	if is_on_floor():
		velocity.x = 0.0
	
	if punch_hitbox:
		punch_hitbox.set_deferred("disabled", true) 
		
	sprite.stop()
	sprite.frame = 0
	sprite.play("punch")

func queue_animations(direction: float):
	if is_in_knockback:
		sprite.play("default") 
		return

	if is_attacking:
		if holding_last_frame:
			sprite.frame = sprite.sprite_frames.get_frame_count("punch") - 1
			sprite.pause()
		return

	if is_on_floor():
		if direction == 0:
			sprite.play("idle")
		else:
			sprite.play("default")
	else:
		sprite.play("default")

func _on_sprite_frame_changed():
	if is_attacking and sprite.animation == "punch":
		var total_frames = sprite.sprite_frames.get_frame_count("punch")
		var current_frame = sprite.frame
		
		if current_frame == total_frames - 1:
			if punch_hitbox and punch_hitbox.disabled:
				punch_hitbox.set_deferred("disabled", false)

# --- Combat Logic ---

func _on_punch_box_area_entered(area):
	if area.name == "Hurtbox":
		var opponent = area.get_parent()
		if opponent != self and opponent.has_method("take_damage_and_knockback"):
			var knockback_dir = -1.0 if sprite.flip_h else 1.0
			
			if knockback_dir == 0:
				knockback_dir = -1.0 if Input.is_action_pressed(input_left) else 1.0
				
			opponent.take_damage_and_knockback(5.0, knockback_dir, combo_count)

func take_damage_and_knockback(damage_amount: float, hit_direction: float, attacker_combo_tier: int = 1):
	damage_percent += damage_amount
	print("[DAMAGE] Player ", player_id, " hit! Total Damage: ", damage_percent, "%")
	
	if hit_direction == 0:
		hit_direction = 1.0
		
	var launch_chance = clamp(damage_percent / 150.0, 0.0, 0.95)
	
	if attacker_combo_tier >= 3:
		launch_chance += 0.45 
		print("[COMBO FINISHER] Boosted Launch Chance Evaluated: ", launch_chance * 100, "%")
		
	var random_roll = randf()
	var launch_x = 0.0
	var launch_y = 0.0
	
	if random_roll < launch_chance:
		# --- CRITICAL BLAST LAUNCH ---
		var power_multiplier = 1.4 if attacker_combo_tier >= 3 else 1.0
		print("[COMBAT] CRITICAL LAUNCH!")
		launch_x = (280.0 + (damage_percent * 4.0)) * hit_direction * power_multiplier
		launch_y = (-240.0 - (damage_percent * 4.5)) * power_multiplier
	else:
		# --- NORMAL FLINCH ---
		print("[COMBAT] Standard Flinch.")
		launch_x = (160.0 + (damage_percent * 1.5)) * hit_direction
		launch_y = -140.0 - (damage_percent * 0.8)

	velocity = Vector2(launch_x, launch_y)
	is_in_knockback = true
	is_attacking = false 
	holding_last_frame = false
	combo_count = 0 
	
	if punch_hitbox:
		punch_hitbox.set_deferred("disabled", true)

func _on_animation_finished():
	if sprite.animation == "punch":
		holding_last_frame = true
		
		if punch_hitbox:
			punch_hitbox.set_deferred("disabled", true)
		
		get_tree().create_timer(0.03).timeout.connect(func():
			if holding_last_frame:
				is_attacking = false
				holding_last_frame = false
				combo_reset_timer = 0.45 
				if combo_count >= 3:
					combo_count = 0 
		)

func _draw():
	var debug_color = Color.GREEN
	if is_in_knockback:
		debug_color = Color.BLUE
	elif is_attacking:
		debug_color = Color.YELLOW if holding_last_frame else Color.RED
	draw_circle(Vector2(0, -45), 5.0, debug_color)
