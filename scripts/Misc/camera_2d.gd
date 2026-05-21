extends Camera2D

var shake_intensity: float = 0.0
var shake_decay: float = 5.0

func _ready() -> void:
	# 🎯 CONNECT TO GLOBAL BUS: Listen for the damage broadcast
	SignalBus.global_player_damaged.connect(_on_global_player_damaged)

func _process(delta: float) -> void:
	if shake_intensity > 0.0:
		# Randomly offset the camera inside a range dictated by the intensity
		offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		# Smoothly decay the shake intensity value down over time
		shake_intensity = move_toward(shake_intensity, 0.0, shake_decay * delta)
	else:
		offset = Vector2.ZERO # Reset to absolute center when shake finishes

# Trigger a shake automatically when a player gets hit
func _on_global_player_damaged(_player_id: int, _total_percent: float, is_heavy_hit: bool) -> void:
	if is_heavy_hit:
		# Big hits get an intense screen rattle
		start_shake(12.0, 30.0)
	else:
		# Small hits get a minor jolt
		start_shake(3.0, 15.0)

# Public function so other traps/hazards can manually invoke a screen shake
func start_shake(intensity: float, decay: float = 20.0) -> void:
	# If a bigger shake is already running, preserve it
	if intensity > shake_intensity:
		shake_intensity = intensity
	shake_decay = decay
