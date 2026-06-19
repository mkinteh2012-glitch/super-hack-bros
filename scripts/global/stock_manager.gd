extends Node
class_name StockManager

@export var max_stocks: int = 3
@export var respawn_delay_time: float = 3.0 

# 🗺️ STAGE PERIMETER BOUNDS
@export var BLAST_ZONE_LEFT: float = -3000.0
@export var BLAST_ZONE_RIGHT: float = 3000.0
@export var BLAST_ZONE_TOP: float = -2000.0
@export var BLAST_ZONE_BOTTOM: float = 2500.0

var p1_stocks: int
var p2_stocks: int

var p1_processing_death: bool = false
var p2_processing_death: bool = false

@onready var p1_spawn_marker: Marker2D = get_parent().get_node_or_null("p1spawn")
@onready var p2_spawn_marker: Marker2D = get_parent().get_node_or_null("p2spawn")

func _ready() -> void:
	if "match_stocks" in GlobalGameData:
		max_stocks = GlobalGameData.match_stocks
	p1_stocks = max_stocks
	p2_stocks = max_stocks
	
	SignalBus.player_died.connect(_on_player_died)

func _process(_delta: float) -> void:
	if GlobalGameData.online and (multiplayer.multiplayer_peer == null or not is_instance_valid(multiplayer.multiplayer_peer)):
		return

	var p1_node = get_parent().find_child("Player1", true, false)
	var p2_node = get_parent().find_child("Player2", true, false)
	
	if p1_node and is_instance_valid(p1_node) and not p1_processing_death:
		_check_coordinate_blast_zones(1, p1_node)
		
	if p2_node and is_instance_valid(p2_node) and not p2_processing_death:
		_check_coordinate_blast_zones(2, p2_node)

func _check_coordinate_blast_zones(player_id: int, player_node: Node2D) -> void:
	if "is_dead" in player_node and player_node.is_dead:
		if player_id == 1: p1_processing_death = true
		else: p2_processing_death = true
		return
		
	var pos = player_node.global_position
	
	if pos.x < BLAST_ZONE_LEFT or pos.x > BLAST_ZONE_RIGHT or pos.y < BLAST_ZONE_TOP or pos.y > BLAST_ZONE_BOTTOM:
		print("🚨 [BLASTZONE] Player ", player_id, " broke boundaries at: ", pos)
		
		if player_id == 1: p1_processing_death = true
		else: p2_processing_death = true
		
		_on_player_died(player_id)

func _on_player_died(player_id: int) -> void:
	var level_root = get_parent()
	var player_node = level_root.find_child("Player" + str(player_id), true, false)
	
	if player_node and player_node.has_method("die"):
		player_node.die() 

	if player_id == 1:
		p1_stocks -= 1
		SignalBus.stocks_updated.emit(1, p1_stocks)
		if p1_stocks <= 0:
			_process_match_conclusion(2)
			return
	elif player_id == 2:
		p2_stocks -= 1
		SignalBus.stocks_updated.emit(2, p2_stocks)
		if p2_stocks <= 0:
			_process_match_conclusion(1)
			return

	await get_tree().create_timer(respawn_delay_time).timeout
	_respawn_player(player_id, player_node)

func _respawn_player(player_id: int, player_node: Node) -> void:
	if not player_node: return
	var spawn_position: Vector2 = Vector2.ZERO
	if player_id == 1 and p1_spawn_marker:
		spawn_position = p1_spawn_marker.global_position
	elif player_id == 2 and p2_spawn_marker:
		spawn_position = p2_spawn_marker.global_position
		
	if player_node.has_method("respawn"):
		player_node.respawn(spawn_position)
	else:
		player_node.global_position = spawn_position
		player_node.velocity = Vector2.ZERO
		player_node.visible = true
		player_node.set_physics_process(true)
		if "is_dead" in player_node: player_node.is_dead = false
	
	if player_id == 1: p1_processing_death = false
	else: p2_processing_death = false

func _process_match_conclusion(winner_id: int) -> void:
	if GlobalGameData.online:
		if multiplayer.is_server():
			rpc("_rpc_sync_match_end", winner_id)
	else:
		_end_match(winner_id)

@rpc("any_peer", "call_local", "reliable")
func _rpc_sync_match_end(winner_id: int) -> void:
	_end_match(winner_id)

func _end_match(winner_id: int) -> void:
	print("🏆 MATCH OVER! PLAYER ", winner_id, " WINS! 🏆")
	Engine.time_scale = 0.15 
	
	var is_local_p1: bool = true
	if GlobalGameData.online and multiplayer.multiplayer_peer != null:
		is_local_p1 = multiplayer.is_server()
		
	if winner_id == 1:
		GlobalGameData.local_match_result = "YOU WIN 👍" if is_local_p1 else "YOU LOSE 👎"
		GlobalGameData.match_end_reason = "Player 2 ran out of stocks!"
	else:
		GlobalGameData.local_match_result = "YOU LOSE 👎" if is_local_p1 else "YOU WIN 👍"
		GlobalGameData.match_end_reason = "Player 1 ran out of stocks!"
		
	await get_tree().create_timer(0.4, true, false, true).timeout
	Engine.time_scale = 1.0

	# 🛑 STOP REPLICATION SYSTEM PACKETS IMMEDIATELY
	# This kills incoming/outgoing data packets right before freeing the level nodes
	var level_root = get_parent()
	if level_root:
		for sync_node in level_root.find_children("*", "MultiplayerSynchronizer", true, false):
			sync_node.public_visibility = false
			sync_node.set_process(false)
			sync_node.set_physics_process(false)

	# 🔒 Secure references before scene transition teardown
	var current_tree = get_tree()
	var current_multiplayer = multiplayer

	current_tree.change_scene_to_file("res://scenes/UI/MainMenu.tscn")
	
	# Let frames drop safely so entities completely un-register before network cut-off
	await current_tree.create_timer(0.05, true, false, true).timeout
	
	if GlobalGameData.online:
		current_multiplayer.multiplayer_peer = null
		GlobalGameData.online = false
		print("[NETWORK] Disconnected cleanly post-scene transition.")
