extends Node

var server_peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
const PORT = 8080
var connected_players: Array[int] = []

func start_standalone_server() -> void:
	# Opens up a real WebSocket server on port 8080
	var error = server_peer.create_server(PORT)
	if error != OK:
		print("[SERVER ERROR] Failed to spin up central WebSocket server gateway.")
		return
		
	multiplayer.multiplayer_peer = server_peer
	print("[SERVER ACTIVE] Central WebSocket Game Relay running on port ", PORT)
	
	# Listen for real inbound player connections
	multiplayer.peer_connected.connect(_on_player_joined)
	multiplayer.peer_disconnected.connect(_on_player_left)

func _on_player_joined(id: int) -> void:
	print("[SERVER] Player connected with Net ID: ", id)
	connected_players.append(id)
	
	# 🤝 MATCHMAKER PAIRING LOGIC
	# As soon as 2 players enter the lobby pool, pair them up!
	if connected_players.size() >= 2:
		var p1 = connected_players[0]
		var p2 = connected_players[1]
		print("[SERVER] Pairing successful! Matching Peer ", p1, " with Peer ", p2)
		
		# Clear them from the matchmaking array pool
		connected_players.remove_at(1)
		connected_players.remove_at(0)

func _on_player_left(id: int) -> void:
	print("[SERVER] Player ID ", id, " left the network matrix.")
	connected_players.erase(id)
