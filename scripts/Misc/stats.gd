extends Control

#Font var
@export var menu_font_size: int = 24  

# Lots o variable
@onready var val_username_edit: LineEdit = $VBoxContainer/Name/Button

@onready var row_p1w_lbl: Label = $VBoxContainer/P1W/Label
@onready var val_p1w_lbl: Label = $VBoxContainer/P1W/Button

@onready var row_p1l_lbl: Label = $VBoxContainer/P1L/Label
@onready var val_p1l_lbl: Label = $VBoxContainer/P1L/Button

@onready var row_p2w_lbl: Label = $VBoxContainer/P2W/Label
@onready var val_p2w_lbl: Label = $VBoxContainer/P2W/Button

@onready var row_p2l_lbl: Label = $VBoxContainer/P2L/Label
@onready var val_p2l_lbl: Label = $VBoxContainer/P2L/Button

@onready var row_cpuw_lbl: Label = $VBoxContainer/CPUW/Label
@onready var val_cpuw_lbl: Label = $VBoxContainer/CPUW/Button

@onready var row_cpul_lbl: Label = $VBoxContainer/CPUL/Label
@onready var val_cpul_lbl: Label = $VBoxContainer/CPUL/Button

@onready var row_ol_lbl: Label = $VBoxContainer/OL/Label
@onready var val_ol_lbl: Label = $VBoxContainer/OL/Button

@onready var row_ow_lbl: Label = $VBoxContainer/OW/Label
@onready var val_ow_lbl: Label = $VBoxContainer/OW/Button

# ___
@onready var back_button: Button = $Button 
@onready var reset_button: Button = $Button2 

# Signals
func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	back_button.text = "Confirm & Continue"
	
	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)
		reset_button.text = "RESET STATS"
	
	if val_username_edit:
		val_username_edit.text_submitted.connect(_on_username_submitted)
		val_username_edit.max_length = 14
		
	_set_static_labels()
	_populate_json_stats()
	_apply_text_sizes() 
	
	back_button.grab_focus()

# Sets the text up for labels
func _set_static_labels() -> void:
	row_p1w_lbl.text = "P1 WINS"
	row_p1l_lbl.text = "P1 LOSSES"
	row_p2w_lbl.text = "P2 WINS"
	row_p2l_lbl.text = "P2 LOSSES"
	row_cpuw_lbl.text = "CPU WINS"
	row_cpul_lbl.text = "CPU LOSSES"
	row_ow_lbl.text = "ONLINE WINS"
	row_ol_lbl.text = "ONLINE LOSSES"

#Grabs the data
func _populate_json_stats() -> void:
	if GlobalGameData.has_method("load_stats_from_json"):
		GlobalGameData.load_stats_from_json()
		
	val_username_edit.text = str(GlobalGameData.player_username).to_upper()
	val_p1w_lbl.text = str(GlobalGameData.p1_wins)
	val_p1l_lbl.text = str(GlobalGameData.p1_losses)
	val_p2w_lbl.text = str(GlobalGameData.p2_wins)
	val_p2l_lbl.text = str(GlobalGameData.p2_losses)
	val_cpuw_lbl.text = str(GlobalGameData.cpu_wins)
	val_cpul_lbl.text = str(GlobalGameData.cpu_losses)
	val_ow_lbl.text = str(GlobalGameData.online_wins)
	val_ol_lbl.text = str(GlobalGameData.online_losses)

# apply the size for the varable from the top
func _apply_text_sizes() -> void:
	var all_text_nodes = [
		val_username_edit, back_button, reset_button,
		row_p1w_lbl, val_p1w_lbl, row_p1l_lbl, val_p1l_lbl,
		row_p2w_lbl, val_p2w_lbl, row_p2l_lbl, val_p2l_lbl,
		row_cpuw_lbl, val_cpuw_lbl, row_cpul_lbl, val_cpul_lbl,
		row_ol_lbl, val_ol_lbl, row_ow_lbl, val_ow_lbl
	]
	
	for node in all_text_nodes:
		if node:
			node.add_theme_font_size_override("font_size", menu_font_size)

#When u change ur user
func _on_username_submitted(new_text: String) -> void:
	var clean_name = new_text.strip_edges()
	if clean_name != "":
		GlobalGameData.player_username = clean_name
		if GlobalGameData.has_method("save_stats_to_json"):
			GlobalGameData.save_stats_to_json()
			
	val_username_edit.release_focus()
	_populate_json_stats()

# STat reset
func _on_reset_pressed() -> void:
	GlobalGameData.p1_wins = 0
	GlobalGameData.p1_losses = 0
	GlobalGameData.p2_wins = 0
	GlobalGameData.p2_losses = 0
	GlobalGameData.cpu_wins = 0
	GlobalGameData.cpu_losses = 0
	GlobalGameData.online_wins = 0
	GlobalGameData.online_losses = 0
	GlobalGameData.player_username = "PLAYER 1"
	
	if GlobalGameData.has_method("save_stats_to_json"):
		GlobalGameData.save_stats_to_json()
		
	_populate_json_stats()
	print("[SYSTEM] Local user profile data wiped clean and re-archived!")

# Where the signal connects to
func _on_back_pressed() -> void:
	if val_username_edit.has_focus(): return
	var error = get_tree().change_scene_to_file("res://scenes/UI/MainMenu.tscn")
	if error != OK:
		print("[ERROR] Could not load MainMenu.tscn!")

#escape button work
func _input(event: InputEvent) -> void:
	if val_username_edit.has_focus(): return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed):
		_on_back_pressed()
