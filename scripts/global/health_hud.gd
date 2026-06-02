extends Control

@onready var p1_label = $P1/PercentLabel
@onready var p2_label = $P2/PercentLabel

@onready var p1_bar = $P1/ProgressBar
@onready var p2_bar = $P2/ProgressBar

# 🖼️ STOCK SYSTEM VISUAL CONFIGURATION
const ORPHEUS_ICON_TEXTURE = preload("res://assets/sprites/Orph board.png")

# 🎨 COLOR PALETTE CONFIGURATION
const COLOR_WHITE = Color(1.0, 1.0, 1.0)
const COLOR_ORANGE = Color(1.0, 0.5, 0.0)
const COLOR_RED = Color(1.0, 0.0, 0.0)
const COLOR_BLUE = Color(0.1, 0.6, 1.0) # Electric Blue for full charge!

var frame_counter: int = 0
const UPDATE_EVERY_X_FRAMES: int = 5

func _ready() -> void:
	SignalBus.global_player_damaged.connect(update_player_ui)
	
	# 📡 CONNECT TO THE STOCK MANAGER SIGNAL
	SignalBus.stocks_updated.connect(_on_stocks_updated)
	
	print("HUD Loaded with Stock Icons Framework")
	
	p1_label.text = "0%"
	p2_label.text = "0%"
	if p1_bar: p1_bar.value = 0.0
	if p2_bar: p2_bar.value = 0.0
	
	# 🎨 Populate initial 3 stocks visually for both players on start
	_refresh_stock_display(1, 3)
	_refresh_stock_display(2, 3)

func _process(_delta: float) -> void:
	frame_counter += 1
	if frame_counter >= UPDATE_EVERY_X_FRAMES:
		frame_counter = 0
		_pull_player_meter_values()

func _pull_player_meter_values() -> void:
	var p1_node = get_tree().get_root().find_child("Player1", true, false)
	var p2_node = get_tree().get_root().find_child("Player2", true, false)
	
	# Create two clean, completely separated tracking flags
	var stage_tint_needed_p1: bool = false
	var stage_tint_needed_p2: bool = false
	
	# 🟦 UNLINKED PLAYER 1 EVALUATION
	if p1_node and p1_bar:
		p1_bar.max_value = p1_node.max_super_meter
		p1_bar.value = p1_node.current_super_meter
		
		# Strictly isolate P1's condition
		if p1_bar.value >= p1_bar.max_value and p1_bar.max_value > 0:
			p1_bar.modulate = COLOR_BLUE
			stage_tint_needed_p1 = true
			if p1_node.has_method("set_charge_glow"):
				p1_node.set_charge_glow(true) # Light up ONLY P1
		else:
			p1_bar.modulate = COLOR_WHITE
			if p1_node.has_method("set_charge_glow"):
				p1_node.set_charge_glow(false) # Turn off ONLY P1
		
	# 🟥 UNLINKED PLAYER 2 EVALUATION
	if p2_node and p2_bar:
		p2_bar.max_value = p2_node.max_super_meter
		p2_bar.value = p2_node.current_super_meter
		
		# Strictly isolate P2's condition
		if p2_bar.value >= p2_bar.max_value and p2_bar.max_value > 0:
			p2_bar.modulate = COLOR_BLUE
			stage_tint_needed_p2 = true
			if p2_node.has_method("set_charge_glow"):
				p2_node.set_charge_glow(true) # Light up ONLY P2
		else:
			p2_bar.modulate = COLOR_WHITE
			if p2_node.has_method("set_charge_glow"):
				p2_node.set_charge_glow(false) # Turn off ONLY P2
		

	var level_root = get_tree().get_root().get_child(0)
	if level_root and level_root.has_method("set_modulate"):
		# Stage dims if Player 1 OR Player 2 are fully charged
		var target_color = Color(0.5, 0.5, 0.65) if (stage_tint_needed_p1 or stage_tint_needed_p2) else Color(1, 1, 1)
		
		# 🎛️ Smoothly transition the stage color without resetting the player states
		if level_root.modulate != target_color:
			var stage_tween = create_tween()
			stage_tween.tween_property(level_root, "modulate", target_color, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
# Delete your old '_handle_bar_color_logic' function completely, as it is no longer used!

		
func update_player_ui(player_id: int, new_percent: float, is_heavy_hit: bool):
	var target_label: Label = p1_label if player_id == 1 else p2_label
	var target_node: Control = $P1 if player_id == 1 else $P2
	
	if not target_label: return
	
	target_label.text = str(floor(new_percent)) + "%"
	
	var target_color: Color = COLOR_WHITE
	if new_percent < 50.0:
		var weight = new_percent / 50.0
		target_color = COLOR_WHITE.lerp(COLOR_ORANGE, weight)
	else:
		var weight = clamp((new_percent - 50.0) / 50.0, 0.0, 1.0)
		target_color = COLOR_ORANGE.lerp(COLOR_RED, weight)
		
	target_label.modulate = target_color

	var tween = create_tween().set_parallel(true)
	target_node.scale = Vector2(1.3, 1.3)
	tween.tween_property(target_node, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# 📡 SIGNAL RECEIVER FOR LIVES LOSING EFFECT
func _on_stocks_updated(player_id: int, current_stocks: int) -> void:
	_refresh_stock_display(player_id, current_stocks)

# 🎨 DYNAMIC STOCK RE-DRAWING MECHANIC
func _refresh_stock_display(player_id: int, stock_count: int) -> void:
	var container_path = "P1/StockIcons" if player_id == 1 else "P2/StockIcons"
	var stock_hbox = get_node_or_null(container_path)
	
	if not stock_hbox:
		print("[HUD WARNING] StockIcons layout container node not found at path: ", container_path)
		return
		
	# Apply tight visual separation safety check passed
	stock_hbox.add_theme_constant_override("separation", -8)
		
	# 🧼 Clear out existing items to build clean new indicators
	for child in stock_hbox.get_children():
		child.queue_free()
		
	# 🗺️ Spawn fresh icons matching the structural lifetime loop count
	for i in range(max(0, stock_count)):
		var new_icon = TextureRect.new()
		new_icon.texture = ORPHEUS_ICON_TEXTURE
		
		# Lock configurations down to prevent canvas stretching
		new_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		new_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# 🔍 MAKE THEM BIGGER (Bump to 36x36)
		new_icon.custom_minimum_size = Vector2(36, 36) 
		
		stock_hbox.add_child(new_icon)
