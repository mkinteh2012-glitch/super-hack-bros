extends Camera2D

# 🎯 Targets to track
var player1: CharacterBody2D = null
var player2: CharacterBody2D = null

# 🔒 Original structural configurations (Captured on startup)
var og_position: Vector2 = Vector2.ZERO
var og_zoom: Vector2 = Vector2.ONE

@export_category("Allowed Offsets from OG")
@export var max_position_offset: float = 200.0 
@export var max_zoom_in_offset: float = 0.5   
@export var max_zoom_out_offset: float = 0.4   

@export_category("Speeds and Padding")
@export var position_smooth_speed: float = 5.0
@export var zoom_smooth_speed: float = 4.0
@export var zoom_padding: float = 350.0        

# 🎛️ Screenshake tracking data
var shake_intensity: float = 0.0
var shake_decay: float = 5.0

func _ready() -> void:
	SignalBus.global_player_damaged.connect(_on_global_player_damaged)
	
	og_position = global_position
	og_zoom = zoom
	
	player1 = get_tree().root.find_child("Player1", true, false)
	player2 = get_tree().root.find_child("Player2", true, false)
	
	print("[CAMERA] Original Benchmarks Secured. Pos: ", og_position, " | Zoom: ", og_zoom)

func _process(delta: float) -> void:
	# -------------------------------------------------------------
	# 1. TRACKING & ZOOM BLOCK (FROZEN DURING SPECIALS)
	# -------------------------------------------------------------
	# If a cinematic lock is active, we skip position/zoom updates 
	# completely so the camera stays exactly where it was told to go!
	if not SignalBus.camera_cinematic_lock:
		var p1_valid = is_instance_valid(player1) and player1.visible
		var p2_valid = is_instance_valid(player2) and player2.visible
		
		var target_position: Vector2 = og_position
		var target_zoom: Vector2 = og_zoom
		
		if p1_valid and p2_valid:
			target_position = (player1.global_position + player2.global_position) / 2.0
			
			var distance = player1.global_position.distance_to(player2.global_position)
			var dynamic_zoom_val = 1.0 / ((distance + zoom_padding) / 1000.0)
			target_zoom = Vector2(dynamic_zoom_val, dynamic_zoom_val)
			
		elif p1_valid:
			target_position = player1.global_position
			target_zoom = og_zoom + Vector2(max_zoom_in_offset, max_zoom_in_offset)
		elif p2_valid:
			target_position = player2.global_position
			target_zoom = og_zoom + Vector2(max_zoom_in_offset, max_zoom_in_offset)

		# Enforce boundaries
		var offset_from_og_pos = target_position - og_position
		if offset_from_og_pos.length() > max_position_offset:
			target_position = og_position + offset_from_og_pos.limit_length(max_position_offset)
			
		var absolute_min_zoom = og_zoom.x - max_zoom_out_offset
		var absolute_max_zoom = og_zoom.x + max_zoom_in_offset
		target_zoom.x = clamp(target_zoom.x, absolute_min_zoom, absolute_max_zoom)
		target_zoom.y = clamp(target_zoom.y, absolute_min_zoom, absolute_max_zoom)

		# Apply Interpolation
		global_position = global_position.lerp(target_position, position_smooth_speed * delta)
		zoom = zoom.lerp(target_zoom, zoom_smooth_speed * delta)

	# -------------------------------------------------------------
	# 2. SCREENSHAKE MATRIX (ALWAYS RUNS - EVEN DURING LOCK)
	# -------------------------------------------------------------
	if shake_intensity > 0.0:
		offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		shake_intensity = move_toward(shake_intensity, 0.0, shake_decay * delta)
	else:
		offset = Vector2.ZERO

func _on_global_player_damaged(_player_id: int, _total_percent: float, is_heavy_hit: bool) -> void:
	if is_heavy_hit:
		start_shake(12.0, 30.0)
	else:
		start_shake(3.0, 15.0)

func start_shake(intensity: float, decay: float = 20.0) -> void:
	if intensity > shake_intensity:
		shake_intensity = intensity
	shake_decay = decay
