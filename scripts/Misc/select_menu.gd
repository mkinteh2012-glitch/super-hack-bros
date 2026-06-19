extends Control

@onready var stage_preview_display: TextureRect = $PreviewPanel/StagePreviewDisplay
@onready var stage_name_label: Label = $PreviewPanel/StageNameLabel
@onready var stage_grid: GridContainer = $StageGrid

# --- 🏷️ NEW TURN NOTIFICATION LABEL ---
@onready var stage_choose_label: Label = $StageChoose

# --- 🛰️ HYBRID NETWORKING VARIABLES ---
var local_peer_id: int = 0
var stage_picker_id: int = 0

# --- 📳 UI SCREEN SHAKE VARIABLES ---
var shake_intensity: float = 0.0
var shake_decay: float = 5.0
var original_position: Vector2

# Stage data dictionary
var stage_data: Dictionary = {
	"StageButton1": {
		"name": "Battlefield",
		"preview_path": "res://assets/Stage&CharacterRefrence/Battlefield.png"
	},
	"StageButton2": { # 🔍 FIXED: Extra tab indentation space removed from the key string
		"name": "Big Battlefield",
		"preview_path": "res://assets/Stage&CharacterRefrence/BIg Battlefield.png"
	}		
}

func _ready() -> void:
	original_position = position
	
	_connect_grid_signals()
	await get_tree().process_frame
	_build_grid_wrapping_path()
	_initialize_first_focus()
	
	# Clear the turn state label by default until network rules are evaluated
	if stage_choose_label:
		stage_choose_label.text = ""
	
	# Evaluate network environment using GlobalGameData.online
	_evaluate_network_environment()


func _evaluate_network_environment() -> void:
	if GlobalGameData.online:
		local_peer_id = multiplayer.get_unique_id()
		print("[STAGE SELECT] Online mode active. Local Peer ID: %d" % local_peer_id)
		
		if multiplayer.is_server():
			print("[STAGE SELECT] Host deciding stage picker turn...")
			_determine_stage_picker()
		else:
			# Temporarily disable buttons until server choices sync over network
			_set_grid_interaction(false)
			if stage_choose_label:
				stage_choose_label.text = "Waiting for match setup..."
				stage_choose_label.modulate = Color.LIGHT_GRAY
	else:
		print("[STAGE SELECT] Offline mode active. Immediate selection enabled.")
		_set_grid_interaction(true)
		# Keep it completely empty for offline play
		if stage_choose_label:
			stage_choose_label.text = ""


# --- 🤝 ONLINE TURN SYNCHRONIZATION ---

func _determine_stage_picker() -> void:
	var players = [1]
	for peer_id in multiplayer.get_peers():
		players.append(peer_id)
		
	var chosen_picker = players[randi() % players.size()]
	rpc("_sync_stage_picker", chosen_picker)


@rpc("any_peer", "call_local", "reliable")
func _sync_stage_picker(chosen_id: int) -> void:
	stage_picker_id = chosen_id
	
	if stage_choose_label:
		if local_peer_id == stage_picker_id:
			stage_choose_label.text = "Your turn to choose a stage!"
			stage_choose_label.modulate = Color.FOREST_GREEN
			_set_grid_interaction(true)
		else:
			stage_choose_label.text = "Opponent is picking the stage..."
			stage_choose_label.modulate = Color.ORANGE
			_set_grid_interaction(false)


func _set_grid_interaction(enabled: bool) -> void:
	for button in stage_grid.get_children():
		if button is TextureButton:
			button.disabled = !enabled
			button.modulate.a = 1.0 if enabled else 0.4


# --- 🎯 STAGE SELECTION CONFIRMATION ---

func _on_stage_confirmed(button: TextureButton) -> void:
	print("Stage Clicked: ", button.name)
	var target_stage = ""
	
	if button.name == "StageButton2":
		target_stage = "res://scenes/stages/Big_Battlefield.tscn"
	
	elif button.name == "StageButton1":
		target_stage = "res://scenes/stages/Battlefield.tscn"
		
	if target_stage != "":
		if GlobalGameData.online:
			rpc("_broadcast_stage_load", target_stage)
		else:
			_execute_stage_transition(target_stage)


@rpc("any_peer", "call_local", "reliable")
func _broadcast_stage_load(stage_path: String) -> void:
	_execute_stage_transition(stage_path)


func _execute_stage_transition(stage_path: String) -> void:
	GlobalGameData.selected_stage_path = stage_path
	_set_grid_interaction(false)
	
	var shake_tween = trigger_ui_shake(18.0, 5.5)
	if shake_tween:
		await shake_tween.finished
		
	get_tree().change_scene_to_file("res://scenes/UI/character_select.tscn")


# --- 🌟 NATIVE BASE GRID ENGINE HOOKS ---

func _process(delta: float) -> void:
	if shake_intensity > 0.0:
		shake_intensity = move_toward(shake_intensity, 0.0, shake_decay * delta * 10.0)
		
		var offset_x = randf_range(-shake_intensity, shake_intensity)
		var offset_y = randf_range(-shake_intensity, shake_intensity)
		position = original_position + Vector2(offset_x, offset_y)
	else:
		if position != original_position:
			position = original_position

func _connect_grid_signals():
	for button in stage_grid.get_children():
		if button is TextureButton:
			button.focus_mode = Control.FOCUS_ALL
			button.pivot_offset = button.size / 2.0
			
			button.focus_entered.connect(_on_stage_focused.bind(button))
			button.mouse_entered.connect(func(): if not button.disabled: button.grab_focus())
			
			button.focus_exited.connect(_on_stage_unfocused.bind(button))
			button.mouse_exited.connect(_on_stage_unfocused.bind(button))
			
			button.pressed.connect(_on_stage_confirmed.bind(button))
	
func _build_grid_wrapping_path():
	var buttons = stage_grid.get_children().filter(func(node): return node is TextureButton)
	var total_buttons = buttons.size()
	if total_buttons == 0: return
	
	var cols = stage_grid.columns
	var rows = ceil(float(total_buttons) / float(cols))
	
	for i in range(total_buttons):
		var btn = buttons[i]
		var r = i / cols
		var c = i % cols
		
		var left_idx = (i - 1 + total_buttons) % total_buttons
		var right_idx = (i + 1) % total_buttons
		
		var up_idx = i - cols
		if up_idx < 0:
			up_idx = (rows - 1) * cols + c
			if up_idx >= total_buttons:
				up_idx = total_buttons - 1
				
		var down_idx = i + cols
		if down_idx >= total_buttons:
			down_idx = c
			
		btn.focus_neighbor_left = btn.get_path_to(buttons[left_idx])
		btn.focus_neighbor_right = btn.get_path_to(buttons[right_idx])
		btn.focus_neighbor_top = btn.get_path_to(buttons[up_idx])
		btn.focus_neighbor_bottom = btn.get_path_to(buttons[down_idx])

func _initialize_first_focus():
	if stage_grid.get_child_count() > 0:
		var first_btn = stage_grid.get_child(0) as TextureButton
		if first_btn:
			first_btn.grab_focus()

func _on_stage_focused(button: TextureButton) -> void:
	if button.disabled: return
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(button, "scale", Vector2(1.1, 1.1), 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.1)

	if stage_data.has(button.name):
		var data = stage_data[button.name]
		stage_name_label.text = data["name"]
		if ResourceLoader.exists(data["preview_path"]):
			stage_preview_display.texture = load(data["preview_path"])
	else:
		stage_name_label.text = button.name.capitalize()
		stage_preview_display.texture = null

func _on_stage_unfocused(button: TextureButton) -> void:
	if button.disabled: return
	var tween = create_tween().set_parallel(true)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)

func trigger_ui_shake(intensity: float, decay: float) -> Tween:
	shake_intensity = intensity
	shake_decay = decay
	var shake_tween = create_tween()
	var duration = intensity / (decay * 10.0) 
	shake_tween.tween_property(self, "shake_intensity", 0.0, duration).set_trans(Tween.TRANS_LINEAR)
	return shake_tween

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			accept_event()
			
			if GlobalGameData.online:
				if multiplayer.multiplayer_peer:
					multiplayer.multiplayer_peer.close()
					multiplayer.multiplayer_peer = null
					
			get_tree().change_scene_to_file("res://scenes/UI/MainMenu.tscn")
