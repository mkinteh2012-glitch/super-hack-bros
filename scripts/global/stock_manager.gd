extends Node
class_name StockManager

@export var max_stocks: int = 3
@export var respawn_delay_time: float = 3.0 # Adjustable timer duration

# Live stock tracking
var p1_stocks: int
var p2_stocks: int

# Use NodePaths or look for them dynamically relative to the parent level
@onready var p1_spawn_marker: Marker2D = get_parent().get_node_or_null("p1spawn")
@onready var p2_spawn_marker: Marker2D = get_parent().get_node_or_null("p2spawn")

func _ready() -> void:
	p1_stocks = max_stocks
	p2_stocks = max_stocks
	
	# Connect to the global death signal coming from your killzones
	SignalBus.player_died.connect(_on_player_died)
	
	print("[STOCK SYSTEM] Component Active. Tracking lives independently.")

func _on_player_died(player_id: int) -> void:
	# 🛸 1. Find the player node instantly to execute their visual explosion/fading death
	var level_root = get_parent()
	var player_node = level_root.find_child("Player" + str(player_id), true, false)
	
	if player_node and player_node.has_method("die"):
		player_node.die() # Tells player script to run death flash, hide, and disable hitboxes

	# 📊 2. Track down stock values
	if player_id == 1:
		p1_stocks -= 1
		SignalBus.stocks_updated.emit(1, p1_stocks)
		if p1_stocks <= 0:
			_end_match(2) # Player 2 Wins!
			return
	elif player_id == 2:
		p2_stocks -= 1
		SignalBus.stocks_updated.emit(2, p2_stocks)
		if p2_stocks <= 0:
			_end_match(1) # Player 1 Wins!
			return

	# ⏱️ 3. THE TIMER LATCH: Wait before initiating the respawn setup
	print("⏱️ Player ", player_id, " died. Starting ", respawn_delay_time, "s respawn timer...")
	await get_tree().create_timer(respawn_delay_time).timeout
	
	# 🛸 4. Run the actual rebirth sequence
	_respawn_player(player_id, player_node)

func _respawn_player(player_id: int, player_node: Node) -> void:
	if not player_node: 
		print("[ERROR] StockManager cannot respawn Player", player_id, " because node is null.")
		return
	
	# Determine spawn coordinates from the markers
	var spawn_position: Vector2 = Vector2.ZERO
	if player_id == 1 and p1_spawn_marker:
		spawn_position = p1_spawn_marker.global_position
	elif player_id == 2 and p2_spawn_marker:
		spawn_position = p2_spawn_marker.global_position
		
	# 🌀 Hand off control directly to the player's clean internal respawn flow
	if player_node.has_method("respawn"):
		player_node.respawn(spawn_position)
	else:
		# Fallback manual backup logic if player script lacks full internal respawn script
		player_node.global_position = spawn_position
		player_node.velocity = Vector2.ZERO
		player_node.visible = true
		player_node.set_physics_process(true)
		if player_node.has_method("reset_combat_state"):
			player_node.reset_combat_state()
			
	print("[RESPAWN] Player ", player_id, " safely returned to match via StockManager at: ", spawn_position)

func _end_match(winner_id: int) -> void:
	print("🏆 MATCH OVER! PLAYER ", winner_id, " WINS! 🏆")
	Engine.time_scale = 0.15 # Dramatic slow-mo finish
