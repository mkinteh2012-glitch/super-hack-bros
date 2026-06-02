extends Control

@onready var background_rect: ColorRect = $ColorRect
@onready var description_label: Label = $DescriptionLabel

# --- 📁 VISIBILITY CONTAINERS ---
@onready var menu_buttons_container: Control = $MenuButtons
@onready var gamemode_labels_container: Control = $GamemodeLabels
@onready var fight_sub_menu: Control = $FightSubMenu

# --- 🏠 MAIN MENU LAYER ---
@onready var fight_btn: TextureButton = $MenuButtons/FightButton
@onready var online_btn: TextureButton = $MenuButtons/OnlineButton
@onready var options_btn: TextureButton = $MenuButtons/OptionsButton
@onready var games_btn: TextureButton = $MenuButtons/GamesMoreButton
@onready var vault_btn: TextureButton = $MenuButtons/VaultButton

@onready var main_menu_sequence: Array[TextureButton] = [
	fight_btn,       # Top Left (Red)
	online_btn,      # Bottom Left (Orange)
	games_btn,       # Middle Column (Green)
	vault_btn,       # Top Right (Pink)
	options_btn      # Bottom Right (Gray)
]

# --- ⚔️ FIGHT SUB-MENU LAYER ---
@onready var sub_fight_btn: TextureButton = $FightSubMenu/FightButton
@onready var sub_custom_btn: TextureButton = $FightSubMenu/FightButton2

@onready var fight_menu_sequence: Array[TextureButton] = [
	sub_fight_btn,
	sub_custom_btn
]

const DEFAULT_PROMPT: String = "Select an option using WASD or Arrow Keys"

# --- 🎨 BACKGROUND COLORS ---
@onready var mode_colors: Dictionary = {
	fight_btn: Color.from_string("#b89999", Color.LIGHT_GRAY),
	online_btn: Color.from_string("#d4beaa", Color.ORANGE),
	games_btn: Color.from_string("#a6c2a8", Color.LIGHT_GREEN),
	vault_btn: Color.from_string("#cfa6c4", Color.PINK),
	options_btn: Color.from_string("#aab8bd", Color.DARK_GRAY),
	sub_fight_btn: Color.from_string("#b89999", Color.LIGHT_GRAY),
	sub_custom_btn: Color.from_string("#bda6c2", Color.PURPLE)
}

var default_bg_color: Color = Color.from_string("#d8ecec", Color.LIGHT_BLUE)
var target_bg_color: Color = default_bg_color

# State Management
var active_sequence: Array[TextureButton] = []
var current_index: int = 0

func _ready() -> void:
	if description_label:
		description_label.text = DEFAULT_PROMPT
		
	if background_rect:
		default_bg_color = background_rect.color
		target_bg_color = default_bg_color
		
	_disable_default_navigation()
	_connect_description_signals()
	_connect_click_signals()
	
	# Default Initial Screen States
	active_sequence = main_menu_sequence
	fight_sub_menu.visible = false
	menu_buttons_container.visible = true
	if gamemode_labels_container:
		gamemode_labels_container.visible = true
	
	await get_tree().process_frame
	_initialize_focus()

func _process(delta: float) -> void:
	if background_rect and background_rect.color != target_bg_color:
		background_rect.color = background_rect.color.lerp(target_bg_color, 10.0 * delta)

func _initialize_focus() -> void:
	current_index = 0
	if active_sequence.size() > 0 and active_sequence[current_index]:
		active_sequence[current_index].grab_focus()
		_update_background_target(active_sequence[current_index])

func _disable_default_navigation() -> void:
	var all_buttons = main_menu_sequence + fight_menu_sequence
	for button in all_buttons:
		if button:
			button.focus_mode = Control.FOCUS_ALL
			button.focus_neighbor_bottom = NodePath(".")
			button.focus_neighbor_top = NodePath(".")
			button.focus_neighbor_left = NodePath(".")
			button.focus_neighbor_right = NodePath(".")

func _connect_description_signals() -> void:
	var all_buttons = main_menu_sequence + fight_menu_sequence
	for button in all_buttons:
		if button and button.has_signal("hovered_with_description"):
			button.hovered_with_description.connect(_on_button_description_updated)
			button.focus_entered.connect(_on_button_focused.bind(button))
			button.mouse_entered.connect(_on_button_focused.bind(button))

func _on_button_focused(button: TextureButton) -> void:
	if active_sequence.has(button):
		current_index = active_sequence.find(button)
	_update_background_target(button)

func _update_background_target(active_button: TextureButton) -> void:
	if active_sequence == fight_menu_sequence:
		target_bg_color == Color.from_string("#b89999", Color.LIGHT_GRAY)
		return
		
	if mode_colors.has(active_button):
		target_bg_color = mode_colors[active_button]

func _on_button_description_updated(new_text: String) -> void:
	if description_label:
		if new_text.strip_edges() == "":
			description_label.text = DEFAULT_PROMPT
		else:
			description_label.text = new_text

# --- 🔌 MENU CLICK WIRE ROUTING ---
func _connect_click_signals() -> void:
	fight_btn.pressed.connect(_on_main_fight_pressed)
	sub_fight_btn.pressed.connect(_on_sub_fight_pressed)
	sub_custom_btn.pressed.connect(func(): print("Open Custom Settings Panel!"))

func _on_main_fight_pressed() -> void:
	# Hide buttons AND the text labels folder completely
	menu_buttons_container.visible = false
	if gamemode_labels_container:
		gamemode_labels_container.visible = false
		
	# Reveal sub menu layout
	fight_sub_menu.visible = true
	active_sequence = fight_menu_sequence
	_initialize_focus()

# --- 🔄 ROTATION AND SELECTION HANDLING ---
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_W or event.keycode == KEY_D or event.keycode == KEY_UP or event.keycode == KEY_RIGHT:
			_rotate_selection(1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_S or event.keycode == KEY_A or event.keycode == KEY_DOWN or event.keycode == KEY_LEFT:
			_rotate_selection(-1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			var active_button = active_sequence[current_index]
			if active_button and not active_button.disabled:
				active_button.button_down.emit()
				active_button.pressed.emit()
				if get_viewport():
					get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if active_sequence == fight_menu_sequence:
				back_to_main_menu()
				get_viewport().set_input_as_handled()

func _rotate_selection(direction: int) -> void:
	if active_sequence.size() == 0: return
	
	current_index = (current_index + direction) % active_sequence.size()
	if current_index < 0:
		current_index += active_sequence.size()
		
	var target_button = active_sequence[current_index]
	if target_button:
		target_button.grab_focus()

func back_to_main_menu():
	fight_sub_menu.visible = false
	menu_buttons_container.visible = true
	gamemode_labels_container.visible = true
	active_sequence = main_menu_sequence
	current_index = active_sequence.find(fight_btn)
	active_sequence[current_index].grab_focus()
	_update_background_target(active_sequence[current_index])	

func _on_sub_fight_pressed() -> void:
	print("[MENU] Loading Stage Select Screen...")
	var error = get_tree().change_scene_to_file("res://scenes/UI/SelectMenu.tscn")
	if error != OK:
		print("[ERROR] Could not load StageSelect.tscn! Check your file path string.")
