extends CharacterBody2D

# --- Node References ---
@onready var sprite = $AnimatedSprite2D
@onready var hitbox = $CollisionPolygon2D
@onready var hurtbox = $Hurtbox 

# Punch Nodes
@onready var punch_box = $PunchBox
@onready var punch_hitbox = $PunchBox/PunchHitbox

# Skull Bash Nodes
@onready var skull_box = $SkullBox
@onready var skull_hitbox = $SkullBox/SkullBox 

@export_enum("Player 1:1", "Player 2:2") var player_id: int = 1

# --- Fast Movement Properties ---
@export var speed: float = 230.0          
@export var acceleration: float = 300.0    
@export var friction: float = 1600.0       

# --- Physics Constants ---
@export var Jump_Velocity: float = -650.0
@export var base_gravity_multiplier: float = 2.0
@export var fall_gravity_multiplier: float = 3.5
@export var knockback_resistance: float = 650.0 
@export var lunge_speed: float = 180.0     

# --- Skull Bash Custom Launch Velocity ---
@export var skull_bash_velocity_y: float = -850.0 

# --- Health Pool ---
var damage_percent: float = 0.0 

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_attacking: bool = false
var holding_last_frame: bool = false
var is_in_knockback: bool = false

# --- Special State Flags ---
var is_skull_bashing: bool = false 
var is_charging_bash: bool = false  

var input_left: String = ""
var input_right: String = ""
var input_up: String = ""
var input_attack: String = ""
var input_special: String = "" 

func _ready():
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_sprite_frame_changed)
	
	if punch_box: punch_box.area_entered.connect(_on_punch_box_area_entered)
	if skull_box: skull_box.area_entered.connect(_on_skull_box_area_entered)

	# --- Dynamic Input Strings Configuration ---
	input_left = "p%d_left" % player_id
	input_right = "p%d_right" % player_id
	input_up = "p%d_up" % player_id
	input_attack = "p%d_attack" % player_id
	input_special = "p%d_special" % player_id 
	
	if punch_hitbox: punch_hitbox.disabled = true
	if skull_hitbox: skull_hitbox.disabled = true

	_setup_collision_layers()

func _physics_process(delta):
	queue_redraw()

	# --- Gravity Processing ---
	if not is_on_floor():
		if velocity.y > 0:
			velocity.y += gravity * fall_gravity_multiplier * delta
			if is_skull_bashing:
				end_skull_bash_state()
		else:
			velocity.y += gravity * base_gravity_multiplier * delta
		
	# --- Input Checks: Dynamic Move Separation ---
	
	# FIX: Skull Bash requires BOTH input_special pressed AND input_up held down
	if Input.is_action_just_pressed(input_special) and Input.is_action_pressed(input_up) and not is_in_knockback and not is_attacking:
		trigger_skull_bash_charge()
			
	# Regular Combo attack configuration
	elif Input.is_action_just_pressed(input_attack) and not is_in_knockback and not is_attacking:
		trigger_combo_strike()

	# Normal Jump Mechanics
	if Input.is_action_just_pressed(input_up) and is_on_floor() and not is_attacking and not is_in_knockback:
		velocity.y = Jump_Velocity
	
	var direction = Input.get_axis(input_left, input_right)

	if not is_attacking and not is_in_knockback:
		if direction != 0:
			velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
			sprite.flip_h = (direction < 0)
			_flip_hitbox_directions(direction < 0)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	
	elif is_in_knockback:
		velocity.x = move_toward(velocity.x, 0.0, knockback_resistance * delta)
		if is_on_floor() and abs(velocity.x) < 30.0:
			is_in_knockback = false
	else:
		if is_charging_bash:
			velocity.x = move_toward(velocity.x, 0.0, friction * 0.2 * delta)
		elif is_skull_bashing:
			velocity.x = 0.0
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * 0.7 * delta)
		
	move_and_slide()
	queue_animations(direction)

# --- Attack Activation States ---

func trigger_combo_strike():
	is_attacking = true
	holding_last_frame = false
	
	var lunge_direction = -1.0 if sprite.flip_h else 1.0
	velocity.x = lunge_direction * lunge_speed
	
	if punch_hitbox: punch_hitbox.set_deferred("disabled", true) 
	if skull_hitbox: skull_hitbox.set_deferred("disabled", true)
		
	sprite.stop()
	sprite.frame = 0
	sprite.play("punch")

func trigger_skull_bash_charge():
	is_attacking = true
	is_charging_bash = true
	is_skull_bashing = false
	holding_last_frame = false
	
	if punch_hitbox: punch_hitbox.set_deferred("disabled", true)
	if skull_hitbox: skull_hitbox.set_deferred("disabled", true)
		
	sprite.stop()
	sprite.frame = 0
	sprite.play("skull_bash")

func release_skull_bash_launch():
	is_charging_bash = false
	is_skull_bashing = true
	
	velocity.y = skull_bash_velocity_y
	velocity.x = 0.0 
	
	if skull_hitbox:
		skull_hitbox.set_deferred("disabled", false)

func end_skull_bash_state():
	is_attacking = false
	is_skull_bashing = false
	is_charging_bash = false
	holding_last_frame = false
	
	if skull_hitbox:
		skull_hitbox.set_deferred("disabled", true)
		

		if is_on_floor(): sprite.play("idle")
		else: sprite.play("default")

# --- Frame & Animation Management ---

func _on_sprite_frame_changed():
	if is_charging_bash and sprite.animation == "skull_bash":
		var total_frames = sprite.sprite_frames.get_frame_count("skull_bash")
		if sprite.frame == total_frames - 1:
			release_skull_bash_launch()
			
	elif is_attacking and sprite.animation == "punch":
		var total_frames = sprite.sprite_frames.get_frame_count("punch")
		if sprite.frame == total_frames - 1:
			if punch_hitbox:
				punch_hitbox.set_deferred("disabled", false)

func queue_animations(direction: float):
	if is_in_knockback:
		sprite.play("default") 
		return

	if is_attacking:
		if is_skull_bashing or holding_last_frame:
			var total_frames = sprite.sprite_frames.get_frame_count(sprite.animation)
			sprite.frame = total_frames - 1
			sprite.pause()
		return

	if is_on_floor():
		if direction == 0: sprite.play("idle")
		else: sprite.play("default")
	else:
		sprite.play("default")

func _on_animation_finished():
	if sprite.animation == "punch":
		holding_last_frame = true
		if punch_hitbox: punch_hitbox.set_deferred("disabled", true)
		
		get_tree().create_timer(0.04).timeout.connect(func():
			if holding_last_frame:
				is_attacking = false
				holding_last_frame = false
		)

# --- Hit Detection Loops ---

func _on_punch_box_area_entered(area):
	if area.name == "Hurtbox":
		var opponent = area.get_parent()
		if opponent != self and opponent.has_method("universal_take_damage"):
			var knockback_dir = -1.0 if sprite.flip_h else 1.0
			var random_damage = randi_range(3, 7)
			opponent.universal_take_damage(random_damage, knockback_dir, 160.0, -140.0, 1.2)

func _on_skull_box_area_entered(area):
	if area.name == "Hurtbox":
		var opponent = area.get_parent()
		if opponent != self and opponent.has_method("universal_take_damage"):
			var knockback_dir = -1.0 if sprite.flip_h else 1.0
			opponent.universal_take_damage(14.0, knockback_dir, 0.0, -380.0, 4.0)
			if skull_hitbox:
				skull_hitbox.set_deferred("disabled", true)

# --- Universal Receiver Damage Function ---
func universal_take_damage(damage: float, hit_dir: float, base_kb_x: float, base_kb_y: float, kb_scaling: float):
	damage_percent += damage
	print("[HIT] Player ", player_id, " took ", damage, "%. Total: ", damage_percent, "%")
	
	if hit_dir == 0: hit_dir = 1.0
	
	var launch_chance = clamp(damage_percent / 150.0, 0.0, 0.95)
	var random_roll = randf()
	
	var final_x = 0.0
	var final_y = 0.0
	
	if random_roll < launch_chance:
		print("[COMBAT] CRITICAL LAUNCH TRIGGERED!")
		final_x = (base_kb_x + (damage_percent * kb_scaling)) * hit_dir * 1.3
		final_y = (base_kb_y - (damage_percent * kb_scaling)) * 1.3
	else:
		print("[COMBAT] Standard Flinch.")
		final_x = base_kb_x * hit_dir
		final_y = base_kb_y * 0.75

	velocity = Vector2(final_x, final_y)
	is_in_knockback = true
	is_attacking = false 
	is_skull_bashing = false
	is_charging_bash = false
	holding_last_frame = false
	
	if punch_hitbox: punch_hitbox.set_deferred("disabled", true)
	if skull_hitbox: skull_hitbox.set_deferred("disabled", true)

# --- Helpers ---
func _flip_hitbox_directions(is_flipped: bool):
	var flip_scale = -1.0 if is_flipped else 1.0
	if hitbox: hitbox.scale.x = flip_scale
	if punch_box: punch_box.scale.x = flip_scale
	if hurtbox: hurtbox.scale.x = flip_scale
	if skull_box: skull_box.scale.x = flip_scale

func _setup_collision_layers():
	for i in [1, 2]:
		set_collision_layer_value(i, true)
		set_collision_mask_value(i, true)
		if hurtbox: hurtbox.set_collision_layer_value(i, true); hurtbox.set_collision_mask_value(i, true)
		if punch_box: punch_box.set_collision_layer_value(i, true); punch_box.set_collision_mask_value(i, true)
		if skull_box: skull_box.set_collision_layer_value(i, true); skull_box.set_collision_mask_value(i, true)
