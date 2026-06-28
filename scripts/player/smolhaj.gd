extends CharacterBody2D

# --- 🌐 NETWORK SYNCHRONIZATION VARIABLES ---
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

@export_enum("Player 1:1", "Player 2:2") var player_id: int = 1

@export var speed: float = 210.0
@export var acceleration: float = 200.0
@export var friction: float = 900.0

@export var Jump_Velocity: float = -550.0
@export var base_gravity_multiplier: float = 1.5
@export var fall_gravity_multiplier: float = 1.5
@export var knockback_resistance: float = 650.0
@export var lunge_speed: float = 230.0

# --- 🛡️ SHIELD SYSTEM ---
@onready var shield_sprite: Sprite2D = $ShieldBox/Sprite2D
@onready var shield_box: Area2D = $ShieldBox
@onready var shield_collision: CollisionShape2D = $ShieldBox/CollisionShape2D

@export var max_shield_health: float = 100.0
var current_shield_health: float = 100.0
@export var shield_decay_rate: float = 25.0
@export var shield_regen_rate: float = 15.0
var is_shielding: bool = false
@export var base_shield_scale: float = 2.4

# 🏃 Base stats
var base_move_speed: float = 400.0
var move_speed: float = 400.0

# ⚔️ Passive Buff Flags
var is_in_overdrive: bool = false
const DAMAGE_BUFF_MULTIPLIER: float = 1.15
const SPEED_BUFF_MULTIPLIER: float = 1.20

@export var damage_percent: float = 0.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_attacking: bool = false
var holding_last_frame: bool = false
var is_in_knockback: bool = false
var is_hovering: bool = false

var input_left: String = ""
var input_right: String = ""
var input_up: String = ""
var input_attack: String = ""
var input_special: String = ""
var input_shield: String = ""

# --- 🕹️ VIRTUAL INPUT INTERFACE ---
@export var is_ai_controlled: bool = false

var input_left_strength: float = 0.0
var input_right_strength: float = 0.0
var input_jump_pressed: bool = false
var input_attack_pressed: bool = false
var input_special_pressed: bool = false
var input_shield_held: bool = false

var hitstun_frames: int = 0
const DI_STRENGTH: float = 35.0

var coyote_timer: float = 0.0
const COYOTE_DURATION: float = 0.1

var block_shader_updates: bool = false
var combo_hit_count: int = 0
var input_buffer: Array[Dictionary] = []
const BUFFER_WINDOW_MS = 130

func _ready():
	print("[DEBUG] Player spawned: ", name)
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_sprite_frame_changed)

	launch_trail.scale_amount_min = 0.3

	if shield_collision: shield_collision.disabled = true

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
		else:
			input_left = ""
			input_right = ""
			input_up = ""
			input_attack = ""
			input_special = ""
			input_shield = ""
			is_ai_controlled = false
	else:
		input_left = "p%d_left" % player_id
		input_right = "p%d_right" % player_id
		input_up = "p%d_up" % player_id
		input_attack = "p%d_attack" % player_id
		input_special = "p%d_special" % player_id
		input_shield = "p%d_shield" % player_id

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

	# --- INPUT GATHERING ---
	if "online" in GlobalGameData and GlobalGameData.online:
		if is_multiplayer_authority():
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

	# --- HITSTUN ---
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

	# --- SHIELD ---
	if sync_shield_held and not is_in_knockback and not is_attacking:
		is_shielding = current_shield_health > 10.0
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

	# --- COYOTE TIME ---
	if is_on_floor():
		coyote_timer = COYOTE_DURATION
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

	if is_in_knockback and hitstun_frames <= 0:
		velocity.x = move_toward(velocity.x, 0.0, knockback_resistance * delta)
		if is_on_floor() and abs(velocity.x) < 30.0:
			is_in_knockback = false
			if launch_trail: launch_trail.emitting = false

	if not is_hovering:
		if not is_on_floor():
			if velocity.y > 0:
				velocity.y += gravity * fall_gravity_multiplier * delta
			else:
				velocity.y += gravity * base_gravity_multiplier * delta

	# --- INPUT BUFFER ---
	var buffered_action: String = ""
	if not is_in_knockback and hitstun_frames <= 0:
		buffered_action = _clean_and_get_buffered_input()

	if buffered_action == "jump":    sync_jump_pressed = true
	if buffered_action == "attack":  sync_attack_pressed = true
	if buffered_action == "special": sync_special_pressed = true

	var take_jump = sync_jump_pressed
	var take_attack = sync_attack_pressed
	var take_special = sync_special_pressed

	if is_multiplayer_authority() or not GlobalGameData.online:
		if sync_jump_pressed: sync_jump_pressed = false
		if sync_attack_pressed: sync_attack_pressed = false
		if sync_special_pressed: sync_special_pressed = false

	# =====================================================================
	# ⚔️ COMBAT GOES HERE — add your character's attacks below this line
	# Each attack should set is_attacking = true and play its animation
	# Use take_attack, take_special, sync_holding_up, sync_moving_sideways
	# =====================================================================

	# --- JUMP ---
	if take_jump and is_on_floor() and not is_attacking and not is_in_knockback:
		velocity.y = Jump_Velocity

	# --- MOVEMENT ---
	var direction = sync_direction

	if not is_attacking and not is_in_knockback:
		if direction != 0:
			if sign(direction) != sign(velocity.x) and abs(velocity.x) > 10.0:
				velocity.x = move_toward(velocity.x, 0.0, friction * delta)
			else:
				velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
			sprite.flip_h = (direction < 0)
			_flip_hitbox_directions(direction < 0)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if is_attacking:
		velocity.x = move_toward(velocity.x, 0.0, friction * 0.7 * delta)

	velocity.y = clamp(velocity.y, -3000.0, 800.0)
	move_and_slide()
	queue_animations(direction)
	_assert_bounds_safety()

func _assert_bounds_safety() -> void:
	if abs(global_position.x) > 8000.0 or abs(global_position.y) > 8000.0:
		global_position = Vector2(0, -200)
		velocity = Vector2.ZERO
		die()

var is_dead = false
func die() -> void:
	if is_dead: return
	is_dead = true

	set_physics_process(false)
	velocity = Vector2.ZERO
	if shield_collision: shield_collision.set_deferred("disabled", true)
	if launch_trail: launch_trail.emitting = false

	sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
	await get_tree().create_timer(0.08).timeout
	var death_tween = create_tween()
	death_tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0.0), 0.35)
	await death_tween.finished
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

# =====================================================================
# ⚔️ ANIMATION — extend queue_animations for your character's states
# =====================================================================
func _on_sprite_frame_changed():
	pass # hook into attack frame logic here

func queue_animations(direction: float):
	if is_in_knockback:
		sprite.play("default")
		return
	if is_shielding:
		sprite.play("idle")
		return
	if is_attacking:
		if holding_last_frame:
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
	pass # hook into attack end logic here

# =====================================================================
# 💥 DAMAGE SYSTEM — do not modify, works for all characters
# =====================================================================
func universal_take_damage(damage: float, hit_dir: float, base_kb_x: float, base_kb_y: float, kb_scaling: float, hitstun_mult: float = 1.0, is_special: bool = false):
	if GlobalGameData.online and not is_multiplayer_authority():
		rpc_id(get_multiplayer_authority(), "_rpc_apply_damage", damage, hit_dir, base_kb_x, base_kb_y, kb_scaling, hitstun_mult, is_special)
		return
	_execute_damage_calculations(damage, hit_dir, base_kb_x, base_kb_y, kb_scaling, hitstun_mult, is_special)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_apply_damage(damage: float, hit_dir: float, base_kb_x: float, base_kb_y: float, kb_scaling: float, hitstun_mult: float, is_special: bool):
	_execute_damage_calculations(damage, hit_dir, base_kb_x, base_kb_y, kb_scaling, hitstun_mult, is_special)

func _execute_damage_calculations(damage: float, hit_dir: float, base_kb_x: float, base_kb_y: float, kb_scaling: float, hitstun_mult: float = 1.0, is_special: bool = false):
	var global_dmg_mult: float = GlobalGameData.damage_multiplier if "damage_multiplier" in GlobalGameData else 1.0
	damage *= global_dmg_mult

	if is_shielding and not is_special:
		current_shield_health -= damage * 1.5
		return

	if is_in_overdrive:
		damage *= DAMAGE_BUFF_MULTIPLIER
	damage_percent += damage
	charge_super_meter(2.0)

	var heavy_strike_check: bool = (abs(base_kb_y) > 250.0 or damage > 10.0)
	SignalBus.global_player_damaged.emit(player_id, damage_percent, heavy_strike_check)

	var main_camera = get_viewport().get_camera_2d()
	if main_camera and main_camera.has_method("start_shake"):
		main_camera.start_shake(clamp(damage * 0.8, 0.0, 8.0), 12)

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
		hitstun_frames = clamp(int((6 + int(damage_percent * 0.12)) * hitstun_mult), 6, 30)
	else:
		final_x = base_kb_x * hit_dir * 0.6
		final_y = base_kb_y * 1.2
		hitstun_frames = clamp(int((6 + int(damage_percent * 0.12)) * hitstun_mult), 6, 30)

	velocity = Vector2(clamp(final_x, -2800.0, 2800.0), clamp(final_y, -2800.0, 2800.0))

	if base_kb_x != 0.0 or base_kb_y != 0.0:
		is_in_knockback = true
		is_attacking = false
		holding_last_frame = false
		if launch_trail and velocity.length() > 500.0:
			launch_trail.emitting = true

func charge_super_meter(base_amount: float) -> void:
	if is_shipping: return
	var comeback_multiplier: float = 1.0 + (damage_percent / 90.0)
	current_super_meter = clamp(current_super_meter + base_amount * comeback_multiplier, 0.0, max_super_meter)
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

func _deactivate_overdrive_buffs() -> void:
	is_in_overdrive = false
	if sprite and sprite.material:
		sprite.material.set_shader_parameter("is_active", false)
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)

var is_shipping: bool = false

func set_charge_glow(enable: bool) -> void:
	if block_shader_updates and enable == true: return
	if sprite and sprite.material:
		sprite.material.set_shader_parameter("is_active", enable)

func _flip_hitbox_directions(is_flipped: bool):
	var flip_scale = -1.0 if is_flipped else 1.0
	if hitbox: hitbox.scale.x = flip_scale
	if hurtbox: hurtbox.scale.x = flip_scale

func _setup_collision_layers():
	for i in [1, 2]:
		set_collision_layer_value(i, true)
		set_collision_mask_value(i, true)
		if hurtbox: hurtbox.set_collision_layer_value(i, true); hurtbox.set_collision_mask_value(i, true)

func reset_combat_state() -> void:
	Engine.time_scale = 1.0
	set_physics_process(true)
	is_dead = false

	damage_percent = 0.0
	hitstun_frames = 0
	current_super_meter = current_super_meter * 0.25
	current_shield_health = max_shield_health
	is_attacking = false
	is_shipping = false
	is_hovering = false
	is_in_knockback = false
	holding_last_frame = false
	block_shader_updates = false
	is_shielding = false
	velocity = Vector2.ZERO

	input_left_strength = 0.0
	input_right_strength = 0.0
	input_jump_pressed = false
	input_attack_pressed = false
	input_special_pressed = false
	input_shield_held = false

	if launch_trail: launch_trail.emitting = false
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

	SignalBus.global_player_damaged.emit(player_id, 0.0, false)

	var hud_node = get_tree().get_root().find_child("HUD", true, false)
	if hud_node:
		var container_name = "P1" if player_id == 1 else "P2"
		var target_container = hud_node.find_child(container_name, true, false)
		if target_container:
			var progress_bar = target_container.get_node_or_null("ProgressBar")
			if progress_bar:
				progress_bar.value = current_super_meter

func buffer_input(action_name: String):
	input_buffer.append({"action": action_name, "timestamp": Time.get_ticks_msec()})

func _clean_and_get_buffered_input() -> String:
	var current_time = Time.get_ticks_msec()
	while not input_buffer.is_empty() and (current_time - input_buffer[0]["timestamp"]) > BUFFER_WINDOW_MS:
		input_buffer.pop_front()
	if input_buffer.is_empty(): return ""
	var action = input_buffer[0]["action"]
	input_buffer.clear()
	return action
