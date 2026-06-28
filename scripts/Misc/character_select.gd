extends Control

# --- 🎯 1. NODE REFERENCES ---
@onready var character_grid: GridContainer = $GridContainer
@onready var p1_sprite: AnimatedSprite2D = $PlayerPanelsContainer/PlayerPanel1/AnimatedSprite2D
@onready var p2_sprite: AnimatedSprite2D = $PlayerPanelsContainer/PlayerPanel2/AnimatedSprite2D

@onready var p1_label: Label = $Labels/NameLabel
@onready var p2_label: Label = $Labels/NameLabel2

# --- ⚙️ 2. STATE VARIABLES ---
var p2_is_cpu: bool = false

# Individual Character Strings
var p1_selected_char: String = "Orpheus"
var p2_selected_char: String = "Orpheus"

# Locked-in states
var p1_locked: bool = false
var p2_locked: bool = false

# 🎨 Color Configuration
var COLOR_NOT_READY: Color = Color.WHITE
var COLOR_READY: Color = Color.GREEN

# ✨ WAY LOWER HIGHLIGHT MODULATION COLORS
const COLOR_P1_ONLY: Color = Color(1.15, 0.75, 0.75, 1.0)   # Light Soft Red
const COLOR_P2_ONLY: Color = Color(0.75, 0.75, 1.15, 1.0)   # Light Soft Blue
const COLOR_BOTH: Color = Color(1.1, 0.7, 1.1, 1.0)        # Soft Purple Overlap

# 🕹️ 2D Grid Coordinate Layout Tracking
var grid_columns: int = 2
var buttons_array: Array = []

var p1_grid_index: int = 0
var p2_grid_index: int = 0

# --- 📳 UI SCREEN SHAKE VARIABLES ---
var shake_intensity: float = 0.0
var shake_decay: float = 5.0
var original_position: Vector2

# --- 🗃️ 3. CHARACTER DATABASE ---
var character_data: Dictionary = {
	0: { "name": "Orpheus" },
	1: { "name": "Smolhaj" }
}

# --- 🚀 4. LIFE CYCLE METHODS ---
func _ready() -> void:
	original_position = position
	grid_columns = character_grid.columns
	
	for child in character_grid.get_children():
		if child is TextureButton:
			buttons_array.append(child)
			child.focus_mode = Control.FOCUS_NONE 
			child.pivot_offset = child.size / 2.0

	_setup_panel_types()
	_update_grid_highlights()
	
	if GlobalGameData.online:
		p2_is_cpu = false

func _process(delta: float) -> void:
	if shake_intensity > 0.0:
		shake_intensity = move_toward(shake_intensity, 0.0, shake_decay * delta * 10.0)
		var offset_x = randf_range(-shake_intensity, shake_intensity)
		var offset_y = randf_range(-shake_intensity, shake_intensity)
		position = original_position + Vector2(offset_x, offset_y)
	else:
		if position != original_position:
			position = original_position

# --- 🎨 5. INITIAL INITIALIZATION ---
func _setup_panel_types() -> void:
	p1_sprite.play("P1")
	
	if GlobalGameData.online:
		p2_sprite.play("P2") 
	else:
		p2_sprite.play("P2" if not p2_is_cpu else "CPU")
		if p2_is_cpu:
			p2_locked = false
		
	p1_label.modulate = COLOR_NOT_READY
	p2_label.modulate = COLOR_NOT_READY
	_update_p1_visuals()
	_update_p2_panel_visuals()

# --- ⌨️ 7. DUAL INDEPENDENT INPUT PROCESSING ---
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		
		# --- 🌐 ONLINE INPUT DISPATCHER ---
		if GlobalGameData.online:
			var current_machine_id = str(multiplayer.get_unique_id())
			var local_player_num = 1 if current_machine_id == GlobalGameData.P1 else 2
			var is_local_locked = p1_locked if local_player_num == 1 else p2_locked
			
			if not is_local_locked:
				if event.keycode == KEY_W or event.keycode == KEY_UP: _move_cursor(local_player_num, Vector2.UP)
				elif event.keycode == KEY_S or event.keycode == KEY_DOWN: _move_cursor(local_player_num, Vector2.DOWN)
				elif event.keycode == KEY_A or event.keycode == KEY_LEFT: _move_cursor(local_player_num, Vector2.LEFT)
				elif event.keycode == KEY_D or event.keycode == KEY_RIGHT: _move_cursor(local_player_num, Vector2.RIGHT)
			
			if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
				if local_player_num == 1:
					p1_locked = not p1_locked
					_update_p1_visuals()
					_rpc_send_selection_to_opponent(p1_grid_index, p1_locked)
				else:
					p2_locked = not p2_locked
					_update_p2_panel_visuals()
					_rpc_send_selection_to_opponent(p2_grid_index, p2_locked)
				_check_match_start()
			return

		# --- 🛋️ LOCAL OFFLINE MODE ---
		if event.keycode == KEY_C and not p1_locked and not p2_locked:
			p2_is_cpu = not p2_is_cpu
			_setup_panel_types() # Refresh textures cleanly
			return

		# P1 Hardcoded Local Couch Play Inputs
		if not p1_locked:
			if event.keycode == KEY_W: _move_cursor(1, Vector2.UP)
			elif event.keycode == KEY_S: _move_cursor(1, Vector2.DOWN)
			elif event.keycode == KEY_A: _move_cursor(1, Vector2.LEFT)
			elif event.keycode == KEY_D: _move_cursor(1, Vector2.RIGHT)
		
		if event.keycode == KEY_SPACE:
			p1_locked = not p1_locked
			_update_p1_visuals()
			
			# If playing against a CPU, locking P1 instantly pairs the CPU's selection state
			if p2_is_cpu:
				p2_locked = p1_locked
				_update_p2_panel_visuals()
				
			_check_match_start()

		# P2 Hardcoded Local Couch Play Inputs (Only runs if P2 is a human)
		if not p2_locked and not p2_is_cpu:
			if event.keycode == KEY_UP: _move_cursor(2, Vector2.UP)
			elif event.keycode == KEY_DOWN: _move_cursor(2, Vector2.DOWN)
			elif event.keycode == KEY_LEFT: _move_cursor(2, Vector2.LEFT)
			elif event.keycode == KEY_RIGHT: _move_cursor(2, Vector2.RIGHT)
				
		# FIXED: Removed 'and not p2_is_cpu' constraint so Enter works for locks/overrides
		if event.keycode == KEY_ENTER:
			p2_locked = not p2_locked
			_update_p2_panel_visuals()
			_check_match_start()

func _move_cursor(player_num: int, direction: Vector2) -> void:
	var total_buttons = buttons_array.size()
	if total_buttons == 0: return
	
	var current_idx = p1_grid_index if player_num == 1 else p2_grid_index
	var r = current_idx / grid_columns
	var c = current_idx % grid_columns
	
	var total_rows = int(ceil(float(total_buttons) / float(grid_columns)))
	
	if direction == Vector2.LEFT:
		c = (c - 1 + grid_columns) % grid_columns
	elif direction == Vector2.RIGHT:
		c = (c + 1) % grid_columns
	elif direction == Vector2.UP:
		r = (r - 1 + total_rows) % total_rows 
	elif direction == Vector2.DOWN:
		r = (r + 1) % total_rows 

	var new_idx = (r * grid_columns) + c
	if new_idx >= total_buttons:
		new_idx = total_buttons - 1

	if player_num == 1:
		p1_grid_index = new_idx
		if character_data.has(p1_grid_index):
			p1_selected_char = character_data[p1_grid_index]["name"]
			# Match the CPU cursor location directly with Player 1 for seamless scrolling
			if p2_is_cpu and not p1_locked:
				p2_grid_index = new_idx
				p2_selected_char = character_data[p2_grid_index]["name"]
	else:
		p2_grid_index = new_idx
		if character_data.has(p2_grid_index):
			p2_selected_char = character_data[p2_grid_index]["name"]

	_update_grid_highlights()

# --- 🌐 NETWORK DATA SYNCHRONIZATION BACKEND ---
func _rpc_send_selection_to_opponent(grid_idx: int, is_locked: bool) -> void:
	if multiplayer.multiplayer_peer and multiplayer.get_peers().size() > 0:
		rpc("receive_opponent_selection_data", grid_idx, is_locked)

@rpc("any_peer", "call_remote", "reliable")
func receive_opponent_selection_data(remote_grid_idx: int, remote_locked_state: bool) -> void:
	var current_machine_id = str(multiplayer.get_unique_id())
	
	if current_machine_id == GlobalGameData.P2:
		p1_grid_index = remote_grid_idx
		p1_locked = remote_locked_state
		if character_data.has(p1_grid_index):
			p1_selected_char = character_data[p1_grid_index]["name"]
	elif current_machine_id == GlobalGameData.P1:
		p2_grid_index = remote_grid_idx
		p2_locked = remote_locked_state
		if character_data.has(p2_grid_index):
			p2_selected_char = character_data[p2_grid_index]["name"]
		
	_update_grid_highlights()
	_check_match_start()

# --- 🎨 DYNAMIC HIGHLIGHT COMPOSITOR ---
func _update_grid_highlights() -> void:
	for i in range(buttons_array.size()):
		var button = buttons_array[i]
		var is_p1_here = (i == p1_grid_index)
		var is_p2_here = (i == p2_grid_index)
		
		var tween = create_tween().set_parallel(true)
		
		if is_p1_here and is_p2_here:
			tween.tween_property(button, "scale", Vector2(1.06, 1.06), 0.08)
			tween.tween_property(button, "modulate", COLOR_BOTH, 0.08)
		elif is_p1_here:
			tween.tween_property(button, "scale", Vector2(1.04, 1.04), 0.08)
			tween.tween_property(button, "modulate", COLOR_P1_ONLY, 0.08)
		elif is_p2_here:
			tween.tween_property(button, "scale", Vector2(1.04, 1.04), 0.08)
			tween.tween_property(button, "modulate", COLOR_P2_ONLY, 0.08)
		else:
			tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.08)
			tween.tween_property(button, "modulate", Color.WHITE, 0.08)

	_update_p1_visuals()
	_update_p2_panel_visuals()

# --- 🕹️ 8. VISUAL REFRESH METHODS ---
func _update_p1_visuals() -> void:
	p1_label.text = "P1: " + p1_selected_char
	p1_label.modulate = COLOR_READY if p1_locked else COLOR_NOT_READY

func _update_p2_panel_visuals() -> void:
	var prefix = "P2: "
	if not GlobalGameData.online and p2_is_cpu:
		prefix = "CPU: "
		
	p2_label.text = prefix + p2_selected_char
	p2_label.modulate = COLOR_READY if p2_locked else COLOR_NOT_READY

func trigger_ui_shake(intensity: float, decay: float) -> Tween:
	shake_intensity = intensity
	shake_decay = decay
	var shake_tween = create_tween()
	var duration = intensity / (decay * 10.0)
	shake_tween.tween_property(self, "shake_intensity", 0.0, duration).set_trans(Tween.TRANS_LINEAR)
	return shake_tween

# --- 🏁 10. MATCH PROGRESSION ---
func _check_match_start() -> void:
	if p1_locked and p2_locked:
		print("--- READY TO FIGHT! ---")
		
		GlobalGameData.p1_character = p1_selected_char
		GlobalGameData.p2_character = p2_selected_char
		GlobalGameData.p2_is_bot = p2_is_cpu if not GlobalGameData.online else false
		
		var target_stage: String = GlobalGameData.selected_stage_path
		if target_stage == "":
			target_stage = "res://scenes/stages/Battlefield.tscn"
			
		var shake_tween = trigger_ui_shake(20.0, 5.0)
		if shake_tween:
			await shake_tween.finished 
			
		get_tree().change_scene_to_file(target_stage)
