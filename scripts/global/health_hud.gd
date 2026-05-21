extends Control

@onready var p1_label = $P1/PercentLabel
@onready var p2_label = $P2/PercentLabel

const COLOR_WHITE = Color(1.0, 1.0, 1.0)
const COLOR_ORANGE = Color(1.0, 0.5, 0.0)
const COLOR_RED = Color(1.0, 0.0, 0.0)

func _ready() -> void:

	SignalBus.global_player_damaged.connect(update_player_ui)
	print("[HUD] Successfully listening to the Global Signal Bus.")
	p1_label.text = "0%"
	p2_label.text = "0%"

# This function matches your exact gradient logic from before!
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
