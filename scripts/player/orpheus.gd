extends CharacterBody2D

# --- 🌐 NETWORK SYNCHRONIZATION VARIABLES ---
# The MultiplayerSynchronizer node will monitor and replicate these variables automatically
@export var sync_direction: float = 0.0
@export var sync_jump_pressed: bool = false
@export var sync_attack_pressed: bool = false
@export var sync_special_pressed: bool = false
@export var sync_shield_held: bool = false
@export var sync_holding_up: bool = false
@export var sync_moving_sideways: bool = false

# --- Nodes and variables ---
@onready var sprite = $AnimatedSprite2D
@onready var hitbox = $CollisionPolygon2D
@onready var hurtbox = $Hurtbox 
@onready var launch_trail = $LaunchTrail

var max_super_meter: float = 100.0
var current_super_meter: float = 100.0
var super_meter_ui: ProgressBar = null
var player_name: String = ""

@onready var punch_box = $PunchBox
@onready var punch_hitbox = $PunchBox/PunchHitbox

@onready var skull_box = $SkullBox
@onready var skull_hitbox = $SkullBox/SkullBox 

@export_enum("Player 1:1", "Player 2:2") var player_id: int = 1

@onready var orph_board: Sprite2D = $OrphBoard
@onready var board_box = $Area2D/BoardBox

@onready var marker_1: Marker2D = $BoardTrail
@onready var marker_2: Marker2D = $BoardTrail2

@onready var board_trail: CPUParticles2D = $Trail
@onready var board_trail_2: CPUParticles2D = $Trail2

@export var speed: float = 210.0          
@export var acceleration: float = 200.0    
@export var friction: float = 900.0       

@export var Jump_Velocity: float = -550.0
@export var base_gravity_multiplier: float = 1.5
@export var fall_gravity_multiplier: float = 1.5
@export var knockback_resistance: float = 650.0 
@export var lunge_speed: float = 230.0    

# --- 🛡️ SHIELD SYSTEM SETTINGS ---
@onready var shield_sprite: Sprite2D = $ShieldBox/Sprite2D
@onready var shield_box: Area2D = $ShieldBox
@onready var shield_collision: CollisionShape2D = $ShieldBox/CollisionShape2D

@export var max_shield_health: float = 100.0
var current_shield_health: float = 100.0

@export var shield_decay_rate: float = 25.0  # Lost per second while holding button
@export var shield_regen_rate: float = 15.0  # Recovered per second when dropped
var is_shielding: bool = false
@export var base_shield_scale: float = 2.4

@export var skull_bash_velocity_y: float = -850.0 
const LAG_SPIKE_SCENE = preload("res://scenes/characters/CharacterAssets/lag_spike.tscn")

@export var max_air_skull_bashes: int = 3
var air_skull_bash_count: int = 0         

# 🏃‍♂️ Base stats
var base_move_speed: float = 400.0
var move_speed: float = 400.0 

# ⚔️ Passive Buff Flags
var is_in_overdrive: bool = false
const DAMAGE_BUFF_MULTIPLIER: float = 1.15  
const SPEED_BUFF_MULTIPLIER: float = 1.20   

var is_shipping: bool = false
var board_dash_dir: float = 1.0
@export var damage_percent: float = 0.0 

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_attacking: bool = false
var holding_last_frame: bool = false
var is_in_knockback: bool = false
var is_hovering: bool = false

var is_skull_bashing: bool = false 
var is_charging_bash: bool = false  

var input_left: String = ""
var input_right: String = ""
var input_up: String = ""
var input_attack: String = ""
var input_special: String = "" 
var input_shield: String = ""

# --- 🕹️ VIRTUAL INPUT CONTROLLER INTERFACE ---
@export var is_ai_controlled: bool = false

var input_left_strength: float = 0.0
var input_right_strength: float = 0.0
var input_jump_pressed: bool = false
var input_attack_pressed: bool = false
var input_special_pressed: bool = false
var input_shield_held: bool = false

var hitstun_frames: int = 0
const DI_STRENGTH: float = 35.0 

# ⏱️ JUICE TIMERS
var coyote_timer: float = 0.0
const COYOTE_DURATION: float = 0.1 

var down_special_buffer_timer: float = 0.0
const BUFFER_DURATION: float = 0.15 

var block_shader_updates: bool = false
var combo_hit_count: int = 0
var input_buffer: Array[Dictionary] = []
const BUFFER_WINDOW_MS = 130 


func _ready():
	print("[DEBUG] Player spawned into the scene tree with the exact name: ", name)
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_sprite_frame_changed)
	
	if punch_box: punch_box.area_entered.connect(_on_punch_box_area_entered)
	if skull_box: skull_box.area_entered.connect(_on_skull_box_area_entered)
	launch_trail.scale_amount_min = 0.3
	
	if punch_hitbox: punch_hitbox.disabled = true
	if skull_hitbox: skull_hitbox.disabled = true
	if shield_collision: shield_collision.disabled = true # Start with shield off

	if sprite:
		sprite.sprite_frames = sprite.sprite_frames.duplicate(true)
		if sprite.material:
			sprite.material = sprite.material.duplicate(true)
			
	_setup_collision_layers()
	_determine_control_type()

func setup_fighter(id: int, character_name: String, bot_mode: bool) -> void:
	if "character_size_multiplier" in GlobalGameData:
		var size_factor = GlobalGameData.character_size_multiplier
		scale = Vector2(size_factor, size_factor)
	player_id = id
	player_name = character_name
	is_ai_controlled = bot_mode
	_determine_control_type()
	if has_node("OverheadNameLabel"):
		$OverheadNameLabel.text = player_name

func _determine_control_type() -> void:
	if "online" in GlobalGameData and GlobalGameData.online:
		if is_multiplayer_authority():
			input_left = "p1_left"
			input_right = "p1_right"
			input_up = "p1_up"
			input_attack = "p1_attack"
			input_special = "p1_special" 
			input_shield = "p1_shield"
			is_ai_controlled = false
			print("Online Node '%s' has network authority. Bound to Local P1 Input Hardware Maps." % name)
		else:
			input_left = ""
			input_right = ""
			input_up = ""
			input_attack = ""
			input_special = "" 
			input_shield = ""
			is_ai_controlled = false
			print("Online Node '%s' belongs to remote peer. Input maps bypassed." % name)
	else:
		input_left = "p%d_left" % player_id
		input_right = "p%d_right" % player_id
		input_up = "p%d_up" % player_id
		input_attack = "p%d_attack" % player_id
		input_special = "p%d_special" % player_id 
		input_shield = "p%d_shield" % player_id

		if is_ai_controlled:
			print("Offline Node '%s' (Player ID: %d) routed to AUTOMATED AI CONTROL." % [name, player_id])
		else:
			print("Offline Node '%s' (Player ID: %d) routed to HUMAN HARDWARE INPUT via mapping prefixes: '%s_'" % [name, player_id, "p" + str(player_id)])

	input_left_strength = 0.0
	input_right_strength = 0.0
	input_jump_pressed = false
	input_attack_pressed = false
	input_special_pressed = false
	input_shield_held = false

func _physics_process(delta):
	if GlobalGameData.online and (multiplayer.multiplayer_peer == null or not is_instance_valid(multiplayer.multiplayer_peer)):
		return
		
	if input_left == "" and not ("online" in GlobalGameData and GlobalGameData.online):
		_determine_control_type()
	queue_redraw()

	if is_nan(velocity.x) or is_inf(velocity.x): velocity.x = 0.0
	if is_nan(velocity.y) or is_inf(velocity.y): velocity.y = 0.0

	# =========================================================================
	# 🔴 STEP 1: GATHER INPUT DATA (ONLY AUTHORIZED CONTROLLER COMPUTES THIS)
	# =========================================================================
	if "online" in GlobalGameData and GlobalGameData.online:
		if is_multiplayer_authority():
			# Owner parses local hardware hooks and saves into network-replicated states
			input_left_strength = Input.get_action_strength(input_left)
			input_right_strength = Input.get_action_strength(input_right)
			
			sync_direction = input_right_strength - input_left_strength
			sync_jump_pressed = Input.is_action_just_pressed(input_up)
			sync_attack_pressed = Input.is_action_just_pressed(input_attack)
			sync_special_pressed = Input.is_action_just_pressed(input_special)
			sync_shield_held = Input.is_action_pressed(input_shield)
			sync_holding_up = Input.is_action_pressed(input_up)
			sync_moving_sideways = (input_left_strength > 0.1 or input_right_strength > 0.1)
	else:
		# Offline processing flow
		if not is_ai_controlled:
			input_left_strength = Input.get_action_strength(input_left)
			input_right_strength = Input.get_action_strength(input_right)
			sync_direction = input_right_strength - input_left_strength
			sync_jump_pressed = Input.is_action_just_pressed(input_up)
			sync_attack_pressed = Input.is_action_just_pressed(input_attack)
			sync_special_pressed = Input.is_action_just_pressed(input_special)
			sync_shield_held = Input.is_action_pressed(input_shield)
			sync_holding_up = Input.is_action_pressed(input_up)
			sync_moving_sideways = (input_left_strength > 0.1 or input_right_strength > 0.1)
		else:
			if input_jump_pressed:    buffer_input("jump")
			if input_attack_pressed:  buffer_input("attack")
			if input_special_pressed: buffer_input("special")
			sync_direction = input_right_strength - input_left_strength
			sync_jump_pressed = input_jump_pressed
			sync_attack_pressed = input_attack_pressed
			sync_special_pressed = input_special_pressed
			sync_shield_held = input_shield_held
			sync_holding_up = input_jump_pressed
			sync_moving_sideways = (abs(sync_direction) > 0.1)

	# =========================================================================
	# 🔵 STEP 2: GAMEPLAY EXECUTION MATRIX (RUNS SIMULTANEOUSLY ON BOTH SIDES)
	# =========================================================================
	if is_ai_controlled and sync_special_pressed and (sync_jump_pressed or velocity.y > 0):
		if is_attacking and not is_skull_bashing and not is_charging_bash:
			is_attacking = false 

	# hitstun stuff
	if hitstun_frames > 0:
		hitstun_frames -= 1
		is_shielding = false 
		if shield_collision: shield_collision.disabled = true
		if shield_sprite: shield_sprite.visible = false
		
		if launch_trail and velocity.length() > 500.0:
			launch_trail.emitting = true

		if not is_on_floor():    
			if velocity.y > 0:
				velocity.y += gravity * fall_gravity_multiplier * delta
			else:
				velocity.y += gravity * base_gravity_multiplier * delta
		
		if sync_direction != 0:
			velocity.x += sync_direction * DI_STRENGTH * delta * 60.0
		
		velocity.x = move_toward(velocity.x, 0.0, knockback_resistance * delta)
		velocity.y = clamp(velocity.y, -3000.0, 800.0)
		move_and_slide()
		queue_animations(sync_direction)
		_assert_bounds_safety()
		return

	if is_down_special_active:
		if is_on_floor():
			velocity = Vector2.ZERO 
		move_and_slide()
		return

	# --- 🛡️ SHIELD PROCESSING USING SYNCED VALUES ---
	if sync_shield_held and not is_in_knockback and not is_attacking:
		if current_shield_health > 10.0: 
			is_shielding = true
		else:
			is_shielding = false
	else:
		is_shielding = false

	if is_shielding:
		velocity.x = 0.0 
		if shield_sprite: shield_sprite.visible = true
		if shield_collision: shield_collision.disabled = false
		
		current_shield_health = max(0.0, current_shield_health - shield_decay_rate * delta)
		
		var health_ratio = current_shield_health / max_shield_health
		var final_scale = health_ratio * base_shield_scale
		if shield_sprite: shield_sprite.scale = Vector2(final_scale, final_scale)
		if shield_box: shield_box.scale = Vector2(final_scale, final_scale)
		
		if current_shield_health <= 0.0:
			is_shielding = false
			if shield_sprite: shield_sprite.visible = false
			if shield_collision: shield_collision.set_deferred("disabled", true)
			universal_take_damage(0.0, 0.0, 0.0, -450.0, 0.0, 2.5) 
	else:
		if shield_sprite: shield_sprite.visible = false
		if shield_collision: shield_collision.disabled = true
		current_shield_health = min(max_shield_health, current_shield_health + shield_regen_rate * delta)

	if is_shielding:
		move_and_slide()
		queue_animations(0.0)
		return 
		
	# coyote time stuff
	if is_on_floor():
		coyote_timer = COYOTE_DURATION 
		air_skull_bash_count = 0
		if is_skull_bashing:
			end_skull_bash_state()
	else:
		coyote_timer = max(0.0, coyote_timer - delta)
		
	down_special_buffer_timer = max(0.0, down_special_buffer_timer - delta)
	
	if is_in_knockback and hitstun_frames <= 0:
		velocity.x = move_toward(velocity.x, 0.0, knockback_resistance * delta)
		if is_on_floor() and abs(velocity.x) < 30.0:
			is_in_knockback = false
			if launch_trail:
				launch_trail.emitting = false

	if not is_hovering:
		if not is_on_floor():
			if velocity.y > 0:
				velocity.y += gravity * fall_gravity_multiplier * delta
			else:
				velocity.y += gravity * base_gravity_multiplier * delta

	# --- ⚔️ COMBAT STATE MATRIX ---
	var buffered_action: String = ""
	if not is_in_knockback and hitstun_frames <= 0:
		buffered_action = _clean_and_get_buffered_input()
		
	if buffered_action == "jump":    sync_jump_pressed = true
	if buffered_action == "attack":  sync_attack_pressed = true
	if buffered_action == "special": sync_special_pressed = true

	# Local owner resets state consumption flags
	var take_jump = sync_jump_pressed
	var take_attack = sync_attack_pressed
	var take_special = sync_special_pressed

	if is_multiplayer_authority() or not GlobalGameData.online:
		if sync_jump_pressed: sync_jump_pressed = false
		if sync_attack_pressed: sync_attack_pressed = false
		if sync_special_pressed: sync_special_pressed = false

	# 1. SUPER MOVE
	if take_attack and take_special and not is_in_knockback and not is_attacking:
		trigger_super_ship_move()
		take_attack = false
		take_special = false

	# 2. UP SPECIAL (SKULL BASH)
	elif take_special and sync_holding_up and not is_in_knockback and (not is_attacking or (is_attacking and not is_charging_bash and not is_skull_bashing)):
		if not is_on_floor() and air_skull_bash_count >= max_air_skull_bashes:
			pass
		else:
			if not is_on_floor():
				air_skull_bash_count += 1
				print("[COMBAT] Air Up-Special counter allowed. Count: ", air_skull_bash_count)
			trigger_skull_bash_charge()
			take_special = false
			take_jump = false

	# 3. SIDE SPECIAL (LAG SPIKE)
	elif take_special and sync_moving_sideways and not is_in_knockback and not is_attacking:
		take_special = false
		if sync_direction < 0:
			$AnimatedSprite2D.flip_h = true
		elif sync_direction > 0:
			$AnimatedSprite2D.flip_h = false
		
		if is_ai_controlled:
			execute_down_special()
		else:
			down_special_buffer_timer = BUFFER_DURATION
			
	# 4. BASIC ATTACK (PUNCH)
	elif take_attack and not is_in_knockback and not is_attacking and sprite.animation != "punch":
		trigger_combo_strike()
		take_attack = false
	
	# --- 🏃‍♂️ MOVEMENT EXECUTION LAYER ---
	if take_jump and is_on_floor() and not is_attacking and not is_in_knockback:
		velocity.y = Jump_Velocity
	
	if not is_attacking and not is_in_knockback:
		if sync_direction != 0:
			if sign(sync_direction) != sign(velocity.x) and abs(velocity.x) > 10.0:
				velocity.x = move_toward(velocity.x, 0.0, friction * delta)
			else:
				velocity.x = move_toward(velocity.x, sync_direction * speed, acceleration * delta)
			sprite.flip_h = (sync_direction < 0)
			_flip_hitbox_directions(sync_direction < 0)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	
	if is_attacking:
		if is_charging_bash:
			velocity.x = move_toward(velocity.x, 0.0, friction * 0.2 * delta)
		elif is_skull_bashing:
			if take_attack or take_special:
				end_skull_bash_state()
			if sync_direction != 0:
				var skull_bash_drift_speed = speed * 0.8
				sprite.flip_h = (sync_direction < 0)
				_flip_hitbox_directions(sync_direction < 0)
				velocity.x = move_toward(velocity.x, sync_direction * skull_bash_drift_speed, acceleration * delta)
			else:
				velocity.x = move_toward(velocity.x, 0.0, friction * 0.3 * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * 0.7 * delta)
			
	if down_special_buffer_timer > 0.0 and (is_on_floor() or coyote_timer > 0.0) and not is_down_special_active:
		down_special_buffer_timer = 0.0 
		execute_down_special()

	move_and_slide()
	queue_animations(sync_direction)
	_assert_bounds_safety()

	if is_shipping:
		if board_trail and marker_1: board_trail.global_position = marker_1.global_position
		if board_trail_2 and marker_2: board_trail_2.global_position = marker_2.global_position
		velocity.x = board_dash_dir * 950.0
		velocity.y = 0.0
		
# 🚨 EMERGENCY TRACKING RESCUE OUT OF BOUNDS
func _assert_bounds_safety() -> void:
	if abs(global_position.x) > 8000.0 or abs(global_position.y) > 8000.0:
		print("⚠️ [ANTI-WARP ACTUATOR] Corruption checked at: ", global_position, ". Resetting coordinates.")
		global_position = Vector2(0, -200)
		velocity = Vector2.ZERO
		die()
		
var is_dead = false
func die() -> void:
	# 🛑 Safety latch: If already dead, break out immediately to avoid losing extra stocks!
	if "is_dead" in self and is_dead: 
		return 
	is_dead = true

	print("💀 Player ", player_id, " has been knocked out!")
	set_physics_process(false)
	velocity = Vector2.ZERO

	# Safely disable active combat hitboxes and shield collision layers
	if punch_hitbox: punch_hitbox.set_deferred("disabled", true)
	if skull_hitbox: skull_hitbox.set_deferred("disabled", true)
	if board_box: board_box.set_deferred("disabled", true)
	if shield_collision: shield_collision.set_deferred("disabled", true)
	if launch_trail: launch_trail.emitting = false

	# Visual blast-away polish: Flash white, then fade out smoothly
	sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
	await get_tree().create_timer(0.08).timeout
	
	var death_tween = create_tween()
	death_tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0.0), 0.35)
	await death_tween.finished
	
	# Complete character concealment until the StockManager's rebirth sequence kicks in
	visible = false
	sprite.modulate = Color(1, 1, 1, 1.0)

func respawn(spawn_position: Vector2) -> void:
	reset_combat_state()
	global_position = spawn_position
	visible = true
	set_physics_process(true)
	_trigger_respawn_invincibility()

func _trigger_respawn_invincibility() -> void:
	if hurtbox: hurtbox.set_deferred("monitorable", false)
	if hurtbox: hurtbox.set_deferred("monitoring", false)

	var flash_tween = create_tween().set_loops(8)
	flash_tween.tween_property(sprite, "modulate:a", 0.2, 0.12)
	flash_tween.tween_property(sprite, "modulate:a", 1.0, 0.13)

	await flash_tween.finished

	sprite.modulate = Color(1, 1, 1, 1.0)
	if hurtbox: hurtbox.set_deferred("monitorable", true)
	if hurtbox: hurtbox.set_deferred("monitoring", true)
	print("Respawn invincibility wore off for Player ", player_id)

func trigger_combo_strike():
	if sprite.animation == "punch" and is_attacking:
		return
		
	is_attacking = true
	holding_last_frame = false
	combo_hit_count = 0 
	
	var lunge_direction = -1.0 if sprite.flip_h else 1.0
	if is_on_floor():
		velocity.x = lunge_direction * lunge_speed
		sprite.stop()
		sprite.frame = 0
		sprite.play("punch")
	else:
		velocity.x = lunge_direction * lunge_speed * 2
		sprite.stop()
		sprite.frame = 0
		sprite.play("punch", -1, 2.0)
	
func trigger_skull_bash_charge():
	is_attacking = true
	is_charging_bash = true
	is_skull_bashing = false
	holding_last_frame = false
	combo_hit_count = 0 
	
	if punch_hitbox: punch_hitbox.set_deferred("disabled", true)
	if skull_hitbox: skull_hitbox.set_deferred("disabled", true)
		
	if is_on_floor():
		sprite.stop()
		sprite.frame = 0
		sprite.play("skull_bash")
	else:
		sprite.stop()
		sprite.frame = 0
		sprite.play("skull_bash",-1, 2.50)

func release_skull_bash_launch():
	is_charging_bash = false
	is_skull_bashing = true
	if is_on_floor():
		velocity.y = skull_bash_velocity_y
	else:
		velocity.y = skull_bash_velocity_y * 1.1
	
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

func _on_sprite_frame_changed():
	if is_charging_bash and sprite.animation == "skull_bash":
		var total_frames = sprite.sprite_frames.get_frame_count("skull_bash")
		if sprite.frame == total_frames - 1:
			release_skull_bash_launch()
			
	elif is_attacking and sprite.animation == "punch":
		if sprite.frame == 1:
			if punch_hitbox:
				punch_hitbox.set_deferred("disabled", false)
		
		var total_frames = sprite.sprite_frames.get_frame_count("punch")
		if sprite.frame == total_frames - 1:
			if punch_hitbox:
				punch_hitbox.set_deferred("disabled", true)
				
func queue_animations(direction: float):
	if is_in_knockback:
		sprite.play("default") 
		return
		
	if is_down_special_active:
		return

	if is_shielding:
		sprite.play("idle") 
		return

	if is_attacking:
		if is_skull_bashing or holding_last_frame:
			var total_frames = sprite.sprite_frames.get_frame_count(sprite.animation)
			sprite.frame = total_frames - 1
			sprite.pause()
		return

	if is_on_floor():
		if direction == 0: sprite.play("idle")
		else: sprite.play("run")
	else:
		sprite.play("default")

func _on_animation_finished():
	if sprite.animation == "punch":
		holding_last_frame = true
		if punch_hitbox: punch_hitbox.set_deferred("disabled", true)
		
		var clear_timer = get_tree().create_timer(0.04)
		clear_timer.timeout.connect(func():
			if holding_last_frame:
				is_attacking = false
				holding_last_frame = false
		)

func _on_punch_box_area_entered(area):
	if area.name == "Hurtbox":
		var opponent = area.get_parent()
		if opponent != self and opponent.has_method("universal_take_damage"):
			combo_hit_count += 1
			print("🥊 [PUNCH COMBO HIT DETECTED]")
			
			if punch_hitbox:
				punch_hitbox.set_deferred("disabled", true)
			
			if combo_hit_count > 1:
				return 

			var knockback_dir = -1.0 if sprite.flip_h else 1.0
			var punch_dmg = 4.0 if is_on_floor() else 6.0
			opponent.universal_take_damage(punch_dmg, knockback_dir, 450.0, -250.0, 3.5, 1.2, false)
			charge_super_meter(5.0) 

func _on_skull_box_area_entered(area):
	if area.name == "Hurtbox":
		var opponent = area.get_parent()
		if opponent != self and opponent.has_method("universal_take_damage"):
			combo_hit_count += 1
			print("💀 [SKULL BASH HIT DETECTED]")
			
			if skull_hitbox:
				skull_hitbox.set_deferred("disabled", true)
				
			if combo_hit_count > 1:
				return

			var knockback_dir = -1.0 if sprite.flip_h else 1.0
			opponent.universal_take_damage(10.0, knockback_dir, 0.0, -270.0, 4.0, 1.1, true)
			charge_super_meter(8.0) 
				
# --- 🌐 NETWORK-READY DAMAGE ENGINE ---
func universal_take_damage(damage: float, hit_dir: float, base_kb_x: float, base_kb_y: float, kb_scaling: float, hitstun_mult: float = 1.0, is_special: bool = false):
	# If we are online and we don't own this character, forward this call to the true owner!
	if GlobalGameData.online and not is_multiplayer_authority():
		rpc_id(get_multiplayer_authority(), "_rpc_apply_damage", damage, hit_dir, base_kb_x, base_kb_y, kb_scaling, hitstun_mult, is_special)
		return

	# Otherwise, we are either offline or we ARE the owner. Execute the damage locally!
	_execute_damage_calculations(damage, hit_dir, base_kb_x, base_kb_y, kb_scaling, hitstun_mult, is_special)


# 📡 Remote process proxy hook
@rpc("any_peer", "call_remote", "reliable")
func _rpc_apply_damage(damage: float, hit_dir: float, base_kb_x: float, base_kb_y: float, kb_scaling: float, hitstun_mult: float, is_special: bool):
	_execute_damage_calculations(damage, hit_dir, base_kb_x, base_kb_y, kb_scaling, hitstun_mult, is_special)


# 💥 Core Internal Damage Logic
func _execute_damage_calculations(damage: float, hit_dir: float, base_kb_x: float, base_kb_y: float, kb_scaling: float, hitstun_mult: float = 1.0, is_special: bool = false):
	# --- 💥 1. APPLY DAMAGE MULTIPLIER IMMEDIATELY ---
	var global_dmg_mult: float = GlobalGameData.damage_multiplier if "damage_multiplier" in GlobalGameData else 1.0
	damage *= global_dmg_mult

	if is_shielding and not is_special:
		current_shield_health -= damage * 1.5
		print("🛡️ Shield Intercepted Hit! Health Remaining: ", current_shield_health)
		return

	# --- 🔄 2. ACCUMULATE MODIFIED PERCENT ---
	if is_in_overdrive:
		damage *= DAMAGE_BUFF_MULTIPLIER
		damage_percent += damage
	else:
		damage_percent += damage
		
	if has_method("charge_super_meter"):
		charge_super_meter(2.0) 
	print("[HIT] Player ", player_id, " took ", damage, "%. Total: ", damage_percent, "%")
	
	var heavy_strike_check: bool = (abs(base_kb_y) > 250.0 or damage > 10.0)
	SignalBus.global_player_damaged.emit(player_id, damage_percent, heavy_strike_check)
	var dynamic_intensity: float = clamp(damage * 0.8, 0.0, 8.0)
	
	var main_camera = get_viewport().get_camera_2d()
	if main_camera and main_camera.has_method("start_shake"):
		main_camera.start_shake(dynamic_intensity, 12)
	
	var freeze_duration: float = clamp(damage * 0.015, 0.05, 0.2)
	
	if freeze_duration > 0.0:
		Engine.time_scale = 0.02
		await get_tree().create_timer(freeze_duration, true, false, true).timeout
		Engine.time_scale = 1.0
	
	if hit_dir == 0: hit_dir = 1.0
	
	var launch_chance = clamp(damage_percent / 150.0, 0.0, 0.95)
	var random_roll = randf()
	var final_x = 0.0
	var final_y = 0.0

	if base_kb_x == 0.0 and base_kb_y == 0.0:
		final_x = velocity.x
		final_y = velocity.y
		hitstun_frames = 0 
		
	elif random_roll < launch_chance:
		final_x = (base_kb_x + (damage_percent * (kb_scaling * 0.4))) * hit_dir * 0.8
		final_y = (base_kb_y - (damage_percent * (kb_scaling * 1.4))) * 1.5
		var calculated_frames = (6 + int(damage_percent * 0.12)) * hitstun_mult
		hitstun_frames = clamp(int(calculated_frames), 6, 30) 
	else:
		final_x = base_kb_x * hit_dir * 0.6
		final_y = base_kb_y * 1.2
		var calculated_frames = (6 + int(damage_percent * 0.12)) * hitstun_mult
		hitstun_frames = clamp(int(calculated_frames), 6, 30) 

	final_x = clamp(final_x, -2800.0, 2800.0)
	final_y = clamp(final_y, -2800.0, 2800.0)

	velocity = Vector2(final_x, final_y)
	
	if base_kb_x != 0.0 or base_kb_y != 0.0:
		is_in_knockback = true
		is_attacking = false 
		is_skull_bashing = false
		is_charging_bash = false
		holding_last_frame = false
		
		if launch_trail and velocity.length() > 500.0:
			launch_trail.emitting = true
		
		if punch_hitbox: punch_hitbox.set_deferred("disabled", true)
		if skull_hitbox: skull_hitbox.set_deferred("disabled", true)
		
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

func trigger_super_ship_move() -> void:
	if current_super_meter < max_super_meter or is_shipping: 
		return
	
	# 🌐 NETWORK PROTECTION: Movement calculations must happen on the true owner's instance
	if GlobalGameData.online and not is_multiplayer_authority():
		return

	is_attacking = true
	is_shipping = true
	current_super_meter = 0.0
	_update_super_meter_ui()
	board_dash_dir = -1.0 if sprite.flip_h else 1.0
	velocity = Vector2.ZERO 
	set_physics_process(false) 
	block_shader_updates = true
	
	# Broadcast cinematic presentation mechanics to everyone simultaneously
	if GlobalGameData.online:
		rpc("_rpc_broadcast_super_cinematics", board_dash_dir)
	else:
		_execute_local_super_cinematics(board_dash_dir)
	
	var cutscene_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	cutscene_tween.set_speed_scale(1.0) 
	
	cutscene_tween.tween_property(sprite, "offset:y", 6.0, 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	cutscene_tween.tween_property(sprite, "offset:y", -45.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	cutscene_tween.tween_property(sprite, "offset:y", -27.0, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Use wall-clock timers instead of global engine slowdowns to avoid ENet connection timeouts
	await get_tree().create_timer(0.21, true, false, true).timeout
	
	global_position.y += -27.0 
	is_hovering = true   
	sprite.offset.y = 0.0      
	
	if orph_board: 
		orph_board.visible = true 
		
	if board_trail and marker_1: 
		board_trail.global_position = marker_1.global_position
		board_trail.emitting = true
	if board_trail_2 and marker_2: 
		board_trail_2.global_position = marker_2.global_position
		board_trail_2.emitting = true
	if board_box: 
		board_box.set_deferred("disabled", false)
		
	await get_tree().create_timer(0.08, true, false, true).timeout
		
	set_physics_process(true) 
	velocity.x = board_dash_dir * 1100.0 
	velocity.y = 0.0 
	
	await get_tree().create_timer(0.6).timeout
	
	var parent_node = get_parent()
	if GlobalGameData.online:
		rpc("_rpc_broadcast_super_cleanup")
	else:
		_clean_up_final_smash_visuals(parent_node, 0.0)

func _execute_local_super_cinematics(_dash_direction: float) -> void:
	var main_camera = get_viewport().get_camera_2d()
	if main_camera and is_multiplayer_authority():
		main_camera.zoom = main_camera.zoom * 2.0
		main_camera.start_shake(4.0, 5.0)
		get_tree().create_timer(0.21).timeout.connect(func(): main_camera.start_shake(28.0, 35.0))

	if not get_tree().root.has_node("SuperDimLayer"):
		var canvas_layer = CanvasLayer.new()
		canvas_layer.name = "SuperDimLayer"
		
		var dim_overlay = ColorRect.new()
		dim_overlay.name = "DimOverlay"
		dim_overlay.color = Color(0.227, 0.227, 0.227, 0.0)
		dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim_overlay.anchors_preset = Control.PRESET_FULL_RECT
		dim_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE)

		canvas_layer.add_child(dim_overlay)
		get_tree().root.add_child(canvas_layer)

		var fade_in_tween = create_tween()
		fade_in_tween.tween_property(dim_overlay, "color:a", 0.75, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if orph_board: 
		orph_board.flip_h = sprite.flip_h
		orph_board.visible = false
		
	var marker_side = -1.0 if sprite.flip_h else 1.0
	if marker_1: marker_1.position.x = abs(marker_1.position.x) * -marker_side
	if marker_2: marker_2.position.x = abs(marker_2.position.x) * -marker_side

func _clean_up_final_smash_visuals(target_world_node: Node, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	
	if is_instance_valid(target_world_node):
		var tween = create_tween()
		tween.tween_property(target_world_node, "modulate", Color(1, 1, 1), 0.3)
		
	if orph_board: orph_board.visible = false
	if board_box: board_box.set_deferred("disabled", true)
	if board_trail: board_trail.emitting = false
	if board_trail_2: board_trail_2.emitting = false
	
	var dim_layer = get_tree().root.find_child("SuperDimLayer", true, false)
	if dim_layer:
		var dim_overlay = dim_layer.find_child("DimOverlay", true, false)
		if dim_overlay:
			var fade_out_tween = create_tween()
			fade_out_tween.tween_property(dim_overlay, "color:a", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			fade_out_tween.finished.connect(func(): dim_layer.queue_free())
		else:
			dim_layer.queue_free()
		
	is_attacking = false
	is_shipping = false
	is_hovering = false
	block_shader_updates = false
	if has_method("set_charge_glow"):
		set_charge_glow(false)
	
func end_super_ship_move() -> void:
	is_shipping = false
	is_attacking = false
	
	if orph_board: orph_board.visible = false
	if board_trail: board_trail.emitting = false
	if board_trail_2: board_trail_2.emitting = false
	
	if board_box: 
		board_box.set_deferred("disabled", true)
	
	velocity.x = move_toward(velocity.x, 0.0, friction)
	if has_method("_deactivate_overdrive_buffs"):
		_deactivate_overdrive_buffs()

func _on_board_box_area_entered(area: Area2D) -> void:
	if area.name == "Hurtbox":
		var opponent = area.get_parent()
		if opponent != self and opponent.has_method("universal_take_damage"):
			var launch_dir = board_dash_dir
			
			opponent.universal_take_damage(45.0, launch_dir, 2400.0, -450.0, 3.5, 2.5, true)
			
			if GlobalGameData.online:
				rpc("_rpc_local_hitstop_freeze")
			else:
				_execute_local_hitstop_freeze()
				
			position.x -= launch_dir * 15.0
			end_super_ship_move()
			print("[FINAL SMASH] Direct PCB Hoverboard impact! Opponent obliterated.")

func _execute_local_hitstop_freeze() -> void:
	if sprite: sprite.pause()
	await get_tree().create_timer(0.15, true, false, true).timeout
	if sprite: sprite.play()

# 📡 CINEMATIC SYSTEM BACKEND RPC CALLS
@rpc("any_peer", "call_local", "reliable")
func _rpc_broadcast_super_cinematics(dash_direction: float) -> void:
	_execute_local_super_cinematics(dash_direction)

@rpc("any_peer", "call_local", "reliable")
func _rpc_broadcast_super_cleanup() -> void:
	var parent_node = get_parent()
	_clean_up_final_smash_visuals(parent_node, 0.0)

@rpc("any_peer", "call_local", "reliable")
func _rpc_local_hitstop_freeze() -> void:
	_execute_local_hitstop_freeze()
func charge_super_meter(base_amount: float) -> void:
	if is_shipping: return 
	
	var comeback_multiplier: float = 1.0 + (damage_percent / 90.0)
	var final_charge_amount: float = base_amount * comeback_multiplier
	
	current_super_meter = clamp(current_super_meter + final_charge_amount, 0.0, max_super_meter)

	if current_super_meter >= max_super_meter and not is_in_overdrive:
		_activate_overdrive_buffs()

func _update_super_meter_ui() -> void:
	if super_meter_ui:
		super_meter_ui.max_value = max_super_meter
		super_meter_ui.value = current_super_meter

func _activate_overdrive_buffs() -> void:
	is_in_overdrive = true
	speed = base_move_speed * SPEED_BUFF_MULTIPLIER
	if sprite and sprite.material:
		sprite.material.set_shader_parameter("is_active", true)
	if sprite:
		sprite.modulate = Color(1.182, 0.973, 2.5, 1.0) 
	print("[OVERDRIVE] Player ", player_id, " is fully charged! Outline activated.")

func _deactivate_overdrive_buffs() -> void:
	is_in_overdrive = false
	if sprite and sprite.material:
		sprite.material.set_shader_parameter("is_active", false)
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1) 

var is_down_special_active = false

func execute_down_special() -> void:
	if is_down_special_active: 
		return
	is_down_special_active = true
	
	if not is_on_floor():
		velocity.x = 0
		while not is_on_floor():
			velocity.y = 1200.0 
			move_and_slide()
			await get_tree().process_frame
			
	velocity = Vector2.ZERO 
	
	var is_facing_left: bool = $AnimatedSprite2D.flip_h
	var direction_multiplier = -1.0 if is_facing_left else 1.0
	
	if $SpawnMaker:
		$SpawnMaker.position.x = abs($SpawnMaker.position.x) * direction_multiplier
	
	$AnimatedSprite2D.animation = "down_special"
	$AnimatedSprite2D.frame = 0
	$AnimatedSprite2D.play("down_special")
	
	var total_frames = $AnimatedSprite2D.sprite_frames.get_frame_count("down_special")
	while $AnimatedSprite2D.animation == "down_special" and $AnimatedSprite2D.frame < total_frames - 1:
		await $AnimatedSprite2D.frame_changed
		if not $AnimatedSprite2D.is_playing():
			break
			
	$AnimatedSprite2D.pause()
	
	# 📡 ONLY THE OWNER PLOTS THE MATH AND TELLS THE NETWORK TO SPAWN
	if is_multiplayer_authority():
		for i in range(5):
			var wave_step = 15.0 * i * direction_multiplier
			var spawn_x = $SpawnMaker.global_position.x + wave_step
			var spawn_y = $SpawnMaker.global_position.y 
			
			var space_state = get_world_2d().direct_space_state
			var ray_start = Vector2(spawn_x, spawn_y - 10.0)
			var ray_end = Vector2(spawn_x, spawn_y + 20.0)
			
			var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
			query.exclude = [self.get_rid()]
			
			var result = space_state.intersect_ray(query)
			if result.is_empty():
				break 
				
			# Send the precise positioning calculations over the network to both windows
			rpc("_rpc_spawn_spike", Vector2(spawn_x, result.position.y), is_facing_left)
			
			await get_tree().create_timer(0.08).timeout
		
	is_down_special_active = false
	if is_on_floor():
		$AnimatedSprite2D.play("idle")
	print("[ATTACK] Completed. Control released.")


# 📡 NETWORK HOOK FOR SIMULTANEOUS SPAWNING
@rpc("any_peer", "call_local", "reliable")
func _rpc_spawn_spike(spawn_pos: Vector2, look_left: bool) -> void:
	var spike_instance = LAG_SPIKE_SCENE.instantiate()
	
	# Dynamically hook creator logic based on network authority mapping
	spike_instance.creator = self
	spike_instance.global_position = spawn_pos
	
	if spike_instance.has_node("AnimatedSprite2D"):
		spike_instance.get_node("AnimatedSprite2D").flip_h = look_left
		
	get_parent().add_child(spike_instance)
	
func Tensor_charge_glow(enable: bool) -> void:
	if block_shader_updates and enable == true:
		return
	if sprite and sprite.material:
		sprite.material.set_shader_parameter("is_active", enable)

func set_charge_glow(enable: bool) -> void:
	if block_shader_updates and enable == true:
		return
	if sprite and sprite.material:
		sprite.material.set_shader_parameter("is_active", enable)

func reset_combat_state() -> void:
	print("🚨 [DEBUG] reset_combat_state() WAS CALLED ON PLAYER ", player_id)
	var main_camera = get_node_or_null("Camera2D") 
	if not main_camera:
		main_camera = get_viewport().get_camera_2d()
		
	if main_camera and main_camera.get_parent() == self:
		var level_root = get_parent()
		var final_world_pos = main_camera.global_position
		
		remove_child(main_camera)
		level_root.add_child(main_camera)
		main_camera.global_position = final_world_pos
		
		if "zoom" in main_camera:
			main_camera.zoom = Vector2(1.0, 1.0) 

	var dim_layer = get_tree().root.find_child("SuperDimLayer", true, false)
	if dim_layer:
		dim_layer.queue_free()

	Engine.time_scale = 1.0
	set_physics_process(true)

	damage_percent = 0.0
	air_skull_bash_count = 0 
	hitstun_frames = 0
	current_super_meter = current_super_meter * 0.25
	current_shield_health = max_shield_health 
	is_attacking = false
	is_shipping = false
	is_hovering = false
	is_in_knockback = false
	is_down_special_active = false
	is_charging_bash = false
	is_skull_bashing = false
	holding_last_frame = false
	block_shader_updates = false
	is_shielding = false
	velocity = Vector2.ZERO

	# Clear input values
	input_left_strength = 0.0
	input_right_strength = 0.0
	input_jump_pressed = false
	input_attack_pressed = false
	input_special_pressed = false
	input_shield_held = false

	if orph_board: orph_board.visible = false
	if board_box: board_box.set_deferred("disabled", true)
	if board_trail: board_trail.emitting = false
	if board_trail_2: board_trail_2.emitting = false
	if launch_trail: launch_trail.emitting = false
	
	if punch_hitbox: punch_hitbox.set_deferred("disabled", true)
	if skull_hitbox: skull_hitbox.set_deferred("disabled", true)
	if shield_collision: shield_collision.disabled = true
	if shield_sprite: 
		shield_sprite.visible = false
		shield_sprite.scale = Vector2(base_shield_scale, base_shield_scale)
	if shield_box:
		shield_box.scale = Vector2(base_shield_scale, base_shield_scale)

	set_charge_glow(false)
	sprite.offset = Vector2.ZERO
	sprite.modulate = Color(1, 1, 1, 1) 
	_deactivate_overdrive_buffs()
	
	sprite.play("idle")
	print("[RESPAWN CLEANUP] Player ", player_id, " combat and camera nodes safely restored.")
	
	SignalBus.global_player_damaged.emit(player_id, 0.0, false)
	
	var hud_node = get_tree().get_root().find_child("HUD", true, false)
	if hud_node:
		var container_name = "P1" if player_id == 1 else "P2"
		var target_container = hud_node.find_child(container_name, true, false)
		
		if target_container:
			var progress_bar = target_container.get_node_or_null("ProgressBar")
			if progress_bar:
				progress_bar.value = current_super_meter

#Storing buffered input data if the player is trying to attack in the middle of doing something
func buffer_input(action_name: String):
	var input_data = {
				"action": action_name,
				"timestamp": Time.get_ticks_msec()
	}
	input_buffer.append(input_data)

#storing and returning the action
func _clean_and_get_buffered_input() -> String:
	var current_time = Time.get_ticks_msec()
	while not input_buffer.is_empty() and (current_time - input_buffer[0]["timestamp"]) > BUFFER_WINDOW_MS:
		input_buffer.pop_front()	
	if input_buffer.is_empty():
		return ""
	var action = input_buffer[0]["action"]
	input_buffer.clear() 
	return action
	
	
	
	
	
	
	
	
	
	
	
	
	
	
