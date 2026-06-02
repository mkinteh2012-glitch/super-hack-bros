extends Node

enum Difficulty { EASY, MEDIUM, HARD }

@export var difficulty_level: Difficulty = Difficulty.HARD
@export var stage_left_edge: float = -600.0
@export var stage_right_edge: float = 600.0
@export var stage_floor_y: float = 0.0
@export var safety_buffer: float = 80.0
@export var raycast_forward_offset: float = 30.0

@onready var character = get_parent()
@onready var edge_raycast: RayCast2D = $RayCast2D 

var target_player: CharacterBody2D = null
var brain_timer: float = 0.0
var match_start_cooldown: float = 1.5
var consecutive_spikes: int = 0
var last_opponent_hitstun: int = 0
var was_dead_last_frame: bool = false

var defense_reaction_chance: float = 0.95
var dodge_vs_shield_ratio: float = 0.75  
var special_aggression_weight: float = 0.85

var ai_recovery_phase: int = 0
var midair_bash_count: int = 0

func _ready():
	await get_tree().process_frame
	_find_target()
	_configure_difficulty_coefficients()
	
	if edge_raycast:
		edge_raycast.enabled = true
		edge_raycast.collide_with_areas = false 
		edge_raycast.collide_with_bodies = true

func _find_target():
	var level = character.get_parent()
	for child in level.get_children():
		if child is CharacterBody2D and child != character:
			target_player = child
			break

func _configure_difficulty_coefficients():
	match difficulty_level:
		Difficulty.EASY:
			defense_reaction_chance = 0.35
			dodge_vs_shield_ratio = 0.25
			special_aggression_weight = 0.30
		Difficulty.MEDIUM:
			defense_reaction_chance = 0.65
			dodge_vs_shield_ratio = 0.50
			special_aggression_weight = 0.55
		Difficulty.HARD:
			defense_reaction_chance = 0.95
			dodge_vs_shield_ratio = 0.75 
			special_aggression_weight = 0.85

func _physics_process(delta):
	if not character.is_ai_controlled:
		return
	if not is_instance_valid(target_player):
		_find_target()
		return

	var is_dead = character.has_method("is_dead") and character.is_dead() 
	if is_dead:
		was_dead_last_frame = true
		return
	elif was_dead_last_frame and not is_dead:
		match_start_cooldown = 1.5
		was_dead_last_frame = false

	if match_start_cooldown > 0.0:
		match_start_cooldown -= delta

	if target_player.hitstun_frames > last_opponent_hitstun:
		consecutive_spikes = 0
	last_opponent_hitstun = target_player.hitstun_frames

	if character.hitstun_frames > 0:
		var survival_dir = 1.0 if character.global_position.x < 0 else -1.0
		_press_virtual_movement(survival_dir)
		
		if randf() <= defense_reaction_chance and Engine.get_physics_frames() % 4 == 0:
			character.input_shield_held = true
			if not character.is_on_floor():
				character.input_jump_pressed = true
		return

	if _is_off_stage():
		_execute_recovery_routine()
		brain_timer = 0.0 
		return
	else:
		ai_recovery_phase = 0
		midair_bash_count = 0

	if _is_target_attacking_me() and randf() <= defense_reaction_chance:
		_execute_reactive_dodge_or_parry()
		return

	if _can_execute_super_snipe():
		_execute_super_snipe()
		return

	brain_timer -= delta
	if brain_timer <= 0.0:
		_evaluate_battlefield_state()
		_reset_reaction_timer()

func _is_target_attacking_me() -> bool:
	if not is_instance_valid(target_player): return false
	var distance = character.global_position.distance_to(target_player.global_position)
	
	if target_player.is_attacking and distance < 220.0:
		var target_facing = -1.0 if target_player.sprite.flip_h else 1.0
		var relative_dir = sign(character.global_position.x - target_player.global_position.x)
		if relative_dir == target_facing or target_facing == 0:
			return true
	return false

func _execute_reactive_dodge_or_parry():
	_clear_virtual_inputs()
	var x_dir = sign(target_player.global_position.x - character.global_position.x)
	var roll = randf()

	if roll <= dodge_vs_shield_ratio:
		if character.is_on_floor():
			if roll < (dodge_vs_shield_ratio * 0.5):
				if "input_down_strength" in character: character.input_down_strength = 1.0
				character.input_shield_held = true
			else:
				_press_virtual_movement(-x_dir)
				character.input_shield_held = true
		else:
			_press_virtual_movement(-x_dir)
			if "input_up_strength" in character: character.input_up_strength = 0.5
			character.input_shield_held = true
	else:
		character.input_shield_held = true

func _evaluate_battlefield_state():
	_clear_virtual_inputs()

	var distance = character.global_position.distance_to(target_player.global_position)
	var x_dir = sign(target_player.global_position.x - character.global_position.x)
	var random_roll = randf()
	
	var self_x = character.global_position.x
	var self_y = character.global_position.y
	var target_y = target_player.global_position.y
	var y_diff = self_y - target_y
	var x_diff_abs = abs(self_x - target_player.global_position.x)
	
	var space_state = character.get_world_2d().direct_space_state
	
	var stage_root = character.get_parent().get_parent()
	var dynamic_platform_y: float = 280.0 
	if stage_root and "low_platform_y" in stage_root:
		dynamic_platform_y = stage_root.low_platform_y

	var opp_floor_check = space_state.intersect_ray(PhysicsRayQueryParameters2D.create(target_player.global_position, target_player.global_position + Vector2(0.0, 500.0), 2147483647, [character.get_rid(), target_player.get_rid()]))
	var opponent_is_off_stage = opp_floor_check.is_empty()
	
	var opening_rushdown_active: bool = match_start_cooldown > 0.0 or (distance > 450.0 and character.is_on_floor())
	
	if character.is_shielding and distance <= 110.0:
		character.input_shield_held = false 
		if random_roll < special_aggression_weight:
			character.input_special_pressed = true 
		else:
			character.input_attack_pressed = true 
		return

	if opponent_is_off_stage and character.is_on_floor() and not opening_rushdown_active:
		_execute_dynamic_edge_camp(target_player)
		return
		
	if opening_rushdown_active:
		_press_virtual_movement(x_dir)
		if distance <= 250.0 and distance > 90.0 and random_roll < special_aggression_weight:
			character.input_special_pressed = true
		elif distance <= 90.0:
			character.input_attack_pressed = true
		return

	if x_dir != 0:
		edge_raycast.position.x = x_dir * raycast_forward_offset
	if character.is_on_floor() and not edge_raycast.is_colliding() and y_diff <= 48.0:
		x_dir = -x_dir 

	if target_player.velocity.y < -50.0 and x_diff_abs <= 120.0 and character.is_on_floor() and random_roll < special_aggression_weight:
		character.input_jump_pressed = true
		character.input_special_pressed = true
		return

	if y_diff >= 50.0 and x_diff_abs <= 90.0 and not character.is_attacking:
		character.input_jump_pressed = true
		character.input_special_pressed = true
		return

	if distance > 100.0 and distance < 320.0 and character.is_on_floor() and random_roll < special_aggression_weight:
		_press_virtual_movement(x_dir)
		character.input_special_pressed = true
		return

	if y_diff > 80.0 and character.is_on_floor():
		character.input_jump_pressed = true
		return
	elif y_diff < -60.0 and character.is_on_floor():
		var on_low_platform = abs(character.global_position.y - dynamic_platform_y) < 15.0
		if on_low_platform and not target_player.is_attacking:
			character.position.y += 2.0 
			return

	if distance <= 85.0 or target_player.hitstun_frames > 0:
		_press_virtual_movement(x_dir)
		if random_roll < 0.30 and not target_player.is_on_floor():
			character.input_special_pressed = true 
		else:
			character.input_attack_pressed = true
		return

	if x_dir != 0:
		_press_virtual_movement(x_dir)

func _execute_dynamic_edge_camp(opponent: CharacterBody2D) -> void:
	_clear_virtual_inputs()
	var ai_global_pos = character.global_position
	var opp_x = opponent.global_position.x
	var ledge_dir = -1.0 if opp_x < ai_global_pos.x else 1.0
	
	var space_state = character.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(ai_global_pos + Vector2(40.0 * ledge_dir, 0.0), ai_global_pos + Vector2(40.0 * ledge_dir, 50.0), 2147483647, [character.get_rid()])
	
	if not space_state.intersect_ray(query).is_empty():
		_press_virtual_movement(ledge_dir)
	else:
		character.input_left_strength = 0.0
		character.input_right_strength = 0.0
		character.sprite.flip_h = (ledge_dir < 0)
		
		var distance_to_opp = abs(ai_global_pos.x - opp_x)
		if distance_to_opp < 250.0:
			character.input_special_pressed = true
			character.input_left_strength = 1.0 if ledge_dir < 0 else 0.0
			character.input_right_strength = 1.0 if ledge_dir > 0 else 0.0

func _is_off_stage() -> bool:
	if character.is_on_floor(): return false
	var space_state = character.get_world_2d().direct_space_state
	var pos = character.global_position

	if not space_state.intersect_ray(PhysicsRayQueryParameters2D.create(pos, pos + Vector2(0, 1000), 2147483647, [character.get_rid()])).is_empty():
		return false
		
	var left_radar = space_state.intersect_ray(PhysicsRayQueryParameters2D.create(pos, pos + Vector2(-800, 400), 2147483647, [character.get_rid()]))
	var right_radar = space_state.intersect_ray(PhysicsRayQueryParameters2D.create(pos, pos + Vector2(800, 400), 2147483647, [character.get_rid()]))
	
	if left_radar.is_empty() and right_radar.is_empty(): return true
	if pos.y > stage_floor_y + 10.0: return true
	return false

func _execute_recovery_routine():
	_clear_virtual_inputs()
	var x = character.global_position.x
	var y = character.global_position.y
	var mid = (stage_left_edge + stage_right_edge) / 2.0
	var recovery_dir = 1.0 if x < mid else -1.0

	if ai_recovery_phase == 0:
		if midair_bash_count < 3:
			character.input_left_strength = 0.0
			character.input_right_strength = 0.0
			if "input_up_strength" in character: character.input_up_strength = 1.0
			character.input_jump_pressed = true    
			character.input_special_pressed = true 
			midair_bash_count += 1
			ai_recovery_phase = 1
		else:
			_press_virtual_movement(recovery_dir)
			if "sprite" in character and character.sprite:
				character.sprite.flip_h = (recovery_dir < 0)
			character.input_attack_pressed = true
			ai_recovery_phase = 2

	elif ai_recovery_phase == 1:
		if character.velocity.y > -100.0 or y <= stage_floor_y - 20.0:
			_press_virtual_movement(recovery_dir)
			if "sprite" in character and character.sprite:
				character.sprite.flip_h = (recovery_dir < 0)
			character.input_special_pressed = false
			character.input_attack_pressed = true
			ai_recovery_phase = 2
		else:
			character.input_left_strength = 0.0
			character.input_right_strength = 0.0
			if "input_up_strength" in character: character.input_up_strength = 1.0

	elif ai_recovery_phase == 2:
		_press_virtual_movement(recovery_dir)
		if "sprite" in character and character.sprite:
			character.sprite.flip_h = (recovery_dir < 0)
		if y > stage_floor_y + 50.0 and midair_bash_count < 3 and not character.is_attacking:
			ai_recovery_phase = 0

func _can_execute_super_snipe() -> bool:
	if match_start_cooldown > 0.0:
		return false

	if is_instance_valid(target_player):
		var current_opp_damage = 0.0
		if "damage_percent" in target_player: current_opp_damage = target_player.damage_percent
		elif "percent" in target_player: current_opp_damage = target_player.percent
		
		if current_opp_damage < 5.0: return false
	else:
		return false
	
	if "current_super_meter" in character and "max_super_meter" in character:
		if character.current_super_meter < character.max_super_meter: return false
	elif "super_meter" in character and character.super_meter < 100.0:
		return false
	if "is_shipping" in character and character.is_shipping: return false
	
	var distance = character.global_position.distance_to(target_player.global_position)
	var to_enemy_x = sign(target_player.global_position.x - character.global_position.x)
	var is_facing_enemy = (to_enemy_x < 0 and character.sprite.flip_h) or (to_enemy_x > 0 and not character.sprite.flip_h)
	
	return distance <= 550.0 and is_facing_enemy

func _execute_super_snipe():
	_clear_virtual_inputs()
	if not is_instance_valid(target_player): return

	character.set("super_target_position", target_player.global_position)

	if "is_attacking" in character: character.is_attacking = false 
	if "is_charging_bash" in character: character.is_charging_bash = false
	if "is_skull_bashing" in character: character.is_skull_bashing = false

	if character.has_method("trigger_super_ship_move"):
		character.trigger_super_ship_move()
	else:
		character.input_attack_pressed = true
		character.input_special_pressed = true

func _press_virtual_movement(dir: float):
	if dir < 0:
		character.input_left_strength = 1.0
		character.input_right_strength = 0.0
	elif dir > 0:
		character.input_right_strength = 1.0
		character.input_left_strength = 0.0

func _clear_virtual_inputs():
	character.input_left_strength = 0.0
	character.input_right_strength = 0.0
	character.input_jump_pressed = false
	character.input_attack_pressed = false
	character.input_special_pressed = false
	character.input_shield_held = false
	if "input_up_strength" in character: character.input_up_strength = 0.0
	if "input_down_strength" in character: character.input_down_strength = 0.0

func _reset_reaction_timer():
	match difficulty_level:
		Difficulty.EASY:   brain_timer = randf_range(0.65, 1.15)
		Difficulty.MEDIUM: brain_timer = randf_range(0.22, 0.42)
		Difficulty.HARD:   brain_timer = randf_range(0.02, 0.08)
