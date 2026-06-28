extends Node

const SAVE_FILE_PATH = "user://player_stats.json"

# --- 📊 DETAILED STATISTICS STORAGE ---
var player_username: String = "Player 1"
var p1_wins: int = 0
var p1_losses: int = 0
var p2_wins: int = 0
var p2_losses: int = 0
var cpu_wins: int = 0
var cpu_losses: int = 0
var online_wins: int = 0
var online_losses: int = 0

# --- 🎮 EXISTING GAME & MATCH RULES ---
var selected_stage_path: String = ""
var p1_character: String = ""
var p2_character: String = ""
var p2_is_bot: bool = false

var match_stocks: int = 3
var stage_hazards_enabled: bool = true
var damage_multiplier: float = 1.0
var character_size_multiplier: float = 1.0

# --- 🌐 NETWORK & MATCHMAKING HOOKS ---
var target_room_is_public: bool = true
var room_pass = ""
var online_test = true
var disconnection_alert: String = ""
var online = false
var P1 = ""
var P2 = ""

var local_match_result: String = ""
var match_end_reason: String = ""   

func _ready() -> void:
	load_stats_from_json()

func register_match_results(p1_won: bool) -> void:
	# 1. Handle Online Mode Match Tracking
	if online:
		# Determine if THIS specific machine is Player 1
		var is_this_machine_p1: bool = (str(multiplayer.get_unique_id()) == P1)
		# You win if you are P1 and P1 won, OR if you are P2 and P1 lost (meaning P2 won)
		var did_local_client_win: bool = p1_won if is_this_machine_p1 else not p1_won
		
		if did_local_client_win:
			online_wins += 1
			print("[STATS] Online Victory recorded for this client!")
		else:
			online_losses += 1
			print("[STATS] Online Defeat recorded for this client!")
			
	# 2. Handle Local Vs. Bot (CPU) Match Tracking
	elif p2_is_bot:
		if p1_won:
			p1_wins += 1
			cpu_losses += 1
			print("[STATS] Local P1 beat the CPU!")
		else:
			p1_losses += 1
			cpu_wins += 1
			print("[STATS] CPU beat Local P1!")
			
	# 3. Handle Local Player 1 vs Player 2 (Couch Play)
	else:
		if p1_won:
			p1_wins += 1
			p2_losses += 1
			print("[STATS] Local P1 beat Local P2!")
		else:
			p1_losses += 1
			p2_wins += 1
			print("[STATS] Local P2 beat Local P1!")

	# Save the corrected data immediately to your JSON file
	save_stats_to_json()
	 
# --- 💾 LOCAL JSON ENGINE ---
func save_stats_to_json() -> void:
	var save_data: Dictionary = {
		"username": player_username,
		"p1_wins": p1_wins,
		"p1_losses": p1_losses,
		"p2_wins": p2_wins,
		"p2_losses": p2_losses,
		"cpu_wins": cpu_wins,
		"cpu_losses": cpu_losses,
		"online_wins": online_wins,
		"online_losses": online_losses
	}
	
	var json_string = JSON.stringify(save_data, "\t")
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("[SAVE SYSTEM] Detailed stats saved successfully!")

func load_stats_from_json() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		save_stats_to_json()
		return
		
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(json_string)
		
		if error == OK:
			var data = json.data
			if typeof(data) == TYPE_DICTIONARY:
				player_username = data.get("username", "Player 1")
				p1_wins = int(data.get("p1_wins", 0))
				p1_losses = int(data.get("p1_losses", 0))
				p2_wins = int(data.get("p2_wins", 0))
				p2_losses = int(data.get("p2_losses", 0))
				cpu_wins = int(data.get("cpu_wins", 0))
				cpu_losses = int(data.get("cpu_losses", 0))
				online_wins = int(data.get("online_wins", 0))
				online_losses = int(data.get("online_losses", 0))
				print("[SAVE SYSTEM] Detailed profile loaded successfully!")
