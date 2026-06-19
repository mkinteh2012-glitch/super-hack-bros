extends Node

# 💓 GLOBAL ENET RPC HEARTBEAT TRACKING
var global_heartbeat_timer: Timer
var missed_pings_count: int = 0
var is_match_active: bool = false
var is_loading_scene: bool = false # 🔥 Tracks if a heavy engine thread load is occurring

func _ready() -> void:
	# Forces this script to keep running even if the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS 
	
	# Create a persistent heartbeat timer that survives scene changes
	global_heartbeat_timer = Timer.new()
	global_heartbeat_timer.wait_time = 1.0
	global_heartbeat_timer.timeout.connect(_on_send_global_ping)
	add_child(global_heartbeat_timer)


func start_heartbeat_watchdog() -> void:
	# 🔌 Safety Check: If we are offline, do not spin up network watchdogs!
	if not GlobalGameData.online:
		print("[GLOBAL-NET] Local offline match. Skipping network watchdog setup.")
		is_match_active = false
		return

	missed_pings_count = 0
	is_loading_scene = false
	is_match_active = true
	global_heartbeat_timer.start()
	
	if not multiplayer.peer_disconnected.is_connected(_on_peer_dropped):
		multiplayer.peer_disconnected.connect(_on_peer_dropped)
	print("[GLOBAL-NET] Heartbeat Monitor Started.")


func stop_heartbeat_watchdog() -> void:
	is_match_active = false
	global_heartbeat_timer.stop()
	if multiplayer.peer_disconnected.is_connected(_on_peer_dropped):
		multiplayer.peer_disconnected.disconnect(_on_peer_dropped)
	print("[GLOBAL-NET] Heartbeat Monitor Stopped.")


func _on_send_global_ping() -> void:
	# Double check that we didn't flip to offline mid-match or lose our connection infrastructure
	if not GlobalGameData.online or not is_match_active or multiplayer.multiplayer_peer == null: 
		stop_heartbeat_watchdog()
		return
	
	# 🔥 Skip timeout evaluation during frame-rate hitches caused by scene loads
	if is_loading_scene:
		missed_pings_count = 0
		print("[GLOBAL-NET] Scene loading active. Heartbeat watchdog checks bypassed.")
		return

	missed_pings_count += 1
	print("[GLOBAL-NET] Sending heartbeat... (Missed tracker: %d)" % missed_pings_count)
	
	if missed_pings_count >= 3: # Increased grace threshold slightly to absorb small connection spikes
		print("[GLOBAL-NET] Timeout! Opponent completely dropped.")
		_trigger_global_disconnect_fallback()
		return
		
	# Only transmit packages explicitly across connected external sockets (removes self-pings)
	for peer_id in multiplayer.get_peers():
		rpc_id(peer_id, "_receive_global_ping")


@rpc("any_peer", "call_remote", "unreliable")
func _receive_global_ping() -> void:
	# Ignore incoming network packets entirely if our local configuration says we are offline
	if not GlobalGameData.online: return
	
	# Only clear trackers if the response came from our remote opponent peer node
	if multiplayer.get_remote_sender_id() != multiplayer.get_unique_id():
		print("[GLOBAL-NET] Heartbeat returned from opponent!")
		missed_pings_count = 0


func _on_peer_dropped(id: int) -> void:
	if not GlobalGameData.online: return
	
	# If we are currently changing scenes, bypass low-level disconnect drops for safety
	if is_loading_scene:
		print("[GLOBAL-NET] Ignored low-level socket disconnect call during loading state.")
		return
		
	print("[GLOBAL-NET] Low-level interface caught drop for Peer ID: %d" % id)
	_trigger_global_disconnect_fallback()


func _trigger_global_disconnect_fallback() -> void:
	stop_heartbeat_watchdog()
	is_loading_scene = false
	
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
		
	GlobalGameData.disconnection_alert = "Opponent disconnected. Returned to Main Menu."
	get_tree().change_scene_to_file("res://scenes/UI/MainMenu.tscn")
