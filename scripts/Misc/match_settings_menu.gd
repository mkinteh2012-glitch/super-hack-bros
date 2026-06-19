extends Control

# --- 🎯 NODE REFERENCES (Mapped to your exact Scene Tree) ---
@onready var size_button: Button = $VBoxContainer/Size/Button
@onready var stocks_button: Button = $VBoxContainer/Stocks/Button
@onready var itemspawn_button: Button = $VBoxContainer/Itemspawn/Button
@onready var hazards_button: Button = $VBoxContainer/Hazards/Button
@onready var damage_button: Button = $VBoxContainer/DMGmult/Button
@onready var save_start_button: Button = $Button # That standalone button at the bottom

# --- 🅰️ FONT SIZE SETTINGS ---
@export var label_font_size: int = 40
@export var button_font_size: int = 28

# --- ⚙️ CONFIGURATION ARRAYS ---
var stock_options: Array[int] = [1, 2, 3, 4, 5, 6, 7]
var stock_index: int = 2 # Defaults to 3 stocks

# Size Configuration
var size_names: Array[String] = ["Tiny", "Small", "Normal", "Large", "Giant"]
var size_multipliers: Array[float] = [0.5, 0.75, 1.0, 1.5, 2.0]
var size_index: int = 2 # Defaults to 1.0x ("Normal")

var damage_options: Array[float] = [0.5, 0.8, 1.0, 1.2, 1.5, 2.0]
var damage_index: int = 2 # Defaults to 1.0x

var hazards_enabled: bool = true
var itemspawn_enabled: bool = true

# --- 🚀 LIFE CYCLE METHODS ---
func _ready() -> void:
	# 🧼 Automatically restore all configurations to default values immediately
	_reset_to_defaults()
	
	_apply_global_font_sizes()
	_setup_button_focus()
	_update_all_ui_text()
	
	# Connect validation/pressed events
	stocks_button.pressed.connect(_on_stocks_changed)
	size_button.pressed.connect(_on_size_changed)
	itemspawn_button.pressed.connect(_on_itemspawn_changed)
	hazards_button.pressed.connect(_on_hazards_changed)
	damage_button.pressed.connect(_on_damage_changed)
	save_start_button.pressed.connect(_on_save_and_continue)


# --- 🧼 DEFAULT RESET LOGIC ---
func _reset_to_defaults() -> void:
	# Reset local script indexes back to their stock/factory configurations
	stock_index = 2       # 3 Stocks
	size_index = 2        # Normal (1.0x)
	damage_index = 2      # 1.0x Damage
	hazards_enabled = true
	itemspawn_enabled = true
	
	# Instantly write these defaults to GlobalGameData to guarantee data safety
	GlobalGameData.match_stocks = stock_options[stock_index]
	GlobalGameData.stage_hazards_enabled = hazards_enabled
	GlobalGameData.damage_multiplier = damage_options[damage_index]
	GlobalGameData.character_size_multiplier = size_multipliers[size_index]
	
	if "items_enabled" in GlobalGameData:
		GlobalGameData.items_enabled = itemspawn_enabled
		
	print("[RULES] All match settings have been set back to default profiles.")


func _apply_global_font_sizes() -> void:
	# 1. Loop through all the row folders inside your VBoxContainer
	for row in $VBoxContainer.get_children():
		if row is HBoxContainer or row is Control:
			# Find the Label inside this row
			var label = row.get_node_or_null("Label")
			if label is Label:
				label.add_theme_font_size_override("font_size", label_font_size)
				
				# --- 🛠️ FIX ALIGNMENT & SIZING HERE ---
				label.autowrap_mode = TextServer.AUTOWRAP_OFF # Stop it from wrapping down
				label.clip_text = false                       # Prevent it from chopping text off
				
				# Force every label to share a minimum width so buttons align perfectly.
				# 450 pixels is usually perfect for a font size of 40.
				label.custom_minimum_size.x = 450 
			
			# Find the Button inside this row, change font size, and strip background
			var button = row.get_node_or_null("Button")
			if button is Button:
				button.add_theme_font_size_override("font_size", button_font_size)
				button.flat = true # Removes the background textures entirely!
				
	# 2. Strip background and upscale the standalone "Confirm & Continue" button
	if save_start_button:
		save_start_button.add_theme_font_size_override("font_size", button_font_size + 4)
		save_start_button.flat = true # Removes the background textures entirely!

func _setup_button_focus() -> void:
	var menu_buttons = [size_button, stocks_button, itemspawn_button, hazards_button, damage_button, save_start_button]
	
	for btn in menu_buttons:
		if btn:
			btn.focus_mode = Control.FOCUS_ALL
			btn.focus_entered.connect(func(): btn.modulate = Color(1.2, 1.2, 1.2))
			btn.focus_exited.connect(func(): btn.modulate = Color(1.0, 1.0, 1.0))
		
	if size_button:
		size_button.grab_focus()

# --- 🔄 UI TEXT REFRESHES ---
func _update_all_ui_text() -> void:
	if stocks_button: stocks_button.text = "<  " + str(stock_options[stock_index]) + " Stocks  >"
	if size_button: size_button.text = "<  " + size_names[size_index] + " (" + str(size_multipliers[size_index]) + "x)  >"
	if itemspawn_button: itemspawn_button.text = "<  Items: Enabled  >" if itemspawn_enabled else "<  Items: Disabled  >"
	if hazards_button: hazards_button.text = "<  Hazards: Enabled  >" if hazards_enabled else "<  Hazards: Disabled  >"
	if damage_button: damage_button.text = "<  " + str(damage_options[damage_index]) + "x  >"

# --- 🕹️ SETTING TOGGLE LOGIC ---
func _on_stocks_changed() -> void:
	stock_index = (stock_index + 1) % stock_options.size()
	_update_all_ui_text()

func _on_size_changed() -> void:
	size_index = (size_index + 1) % size_multipliers.size()
	_update_all_ui_text()

func _on_itemspawn_changed() -> void:
	itemspawn_enabled = not itemspawn_enabled
	_update_all_ui_text()

func _on_hazards_changed() -> void:
	hazards_enabled = not hazards_enabled
	_update_all_ui_text()

func _on_damage_changed() -> void:
	damage_index = (damage_index + 1) % damage_options.size()
	_update_all_ui_text()

# --- 🏁 SAVE AND TRANSITION ---
func _on_save_and_continue() -> void:
	GlobalGameData.match_stocks = stock_options[stock_index]
	GlobalGameData.stage_hazards_enabled = hazards_enabled
	GlobalGameData.damage_multiplier = damage_options[damage_index]
	GlobalGameData.character_size_multiplier = size_multipliers[size_index]
	
	if "items_enabled" in GlobalGameData:
		GlobalGameData.items_enabled = itemspawn_enabled
	
	print("--- Custom Rules Saved ---")
	get_tree().change_scene_to_file("res://scenes/UI/SelectMenu.tscn")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			accept_event()
			get_tree().change_scene_to_file("res://scenes/UI/MainMenu.tscn")
