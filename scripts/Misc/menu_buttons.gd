extends TextureButton

signal hovered_with_description(description_text: String)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var menu_animation_name: String = "Fight"
@export_multiline var mode_description: String = "Enter this mode to play!"

func _ready() -> void:
	if not animated_sprite:
		print("[BTN ERROR] AnimatedSprite2D missing on node: ", name)
		return
		
	animated_sprite.animation = menu_animation_name
	animated_sprite.frame = 0
	_update_visual_state()
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	
	print("[BTN INIT] Button '", name, "' successfully initialized with text: '", mode_description, "'")

func _update_visual_state() -> void:
	if disabled:
		modulate = Color(0.3, 0.3, 0.3, 0.6)
	elif is_hovered() or has_focus():
		modulate = Color(1.4, 1.4, 1.4, 1.0)
	else:
		modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_mouse_entered() -> void:
	print("[BTN DEBUG] Mouse ENTERED button boundary: ", name)
	_update_visual_state()
	hovered_with_description.emit(mode_description)

func _on_focus_entered() -> void:
	print("[BTN DEBUG] Gamepad/Keyboard FOCUS ENTERED button: ", name)
	_update_visual_state()
	hovered_with_description.emit(mode_description)

func _on_mouse_exited() -> void:
	print("[BTN DEBUG] Mouse EXITED button boundary: ", name)
	_update_visual_state()
	hovered_with_description.emit("")

func _on_focus_exited() -> void:
	print("[BTN DEBUG] Focus EXITED button: ", name)
	_update_visual_state()

func _on_button_down() -> void:
	modulate = Color(0.7, 0.7, 0.7, 1.0)

func _on_button_up() -> void:
	_update_visual_state()
