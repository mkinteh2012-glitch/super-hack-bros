extends Node2D

@export var low_platform_y: float = 280.0

# --- 🎯 1. PRELOAD CHARACTER SCENES ---
var characters_scenes: Dictionary = {
	"Orpheus": preload("res://scenes/characters/orpheus.tscn"),
}

# --- 📍 2. NODE REFERENCES ---
@onready var p1_spawn: Marker2D = $p1spawn
@onready var p2_spawn: Marker2D = $p2spawn

# --- 🚀 3. LIFE CYCLE METHODS ---
func _ready() -> void:
	print("--- ARENA LOADED SUCCESSFULLY ---")
	_spawn_match_players()

# --- 🕹️ 4. SPAWNING ENGINE (ONLINE COMPATIBLE) ---
func _spawn_match_players() -> void:
	# Default local IDs (1 is always the authority for local/offline setups)
	var p1_peer_id: int = 1 
	var p2_peer_id: int = 1
	
	# --- 👥 EXTRACT IDENTITY MAPPING FROM GLOBAL GAME DATA ---
	if GlobalGameData.online and GlobalGameData.P1 != "" and GlobalGameData.P2 != "":
		p1_peer_id = GlobalGameData.P1.to_int()
		p2_peer_id = GlobalGameData.P2.to_int()
		print("[SPAWN-NET] Parsing global configurations. Target P1 ID: %d | Target P2 ID: %d" % [p1_peer_id, p2_peer_id])

	# ==========================================
	# 🔴 STEP A: INITIALIZE AND SPAWN PLAYER 1
	# ==========================================
	var p1_name: String = GlobalGameData.p1_character
	
	if characters_scenes.has(p1_name):
		var p1_instance = characters_scenes[p1_name].instantiate()
		p1_instance.position = p1_spawn.position
		p1_instance.name = "Player1"
		
		# 🔥 CRITICAL FIX: Set multiplayer network authority BEFORE adding to the SceneTree
		if GlobalGameData.online and p1_instance.has_method("set_multiplayer_authority"):
			p1_instance.set_multiplayer_authority(p1_peer_id)
			
		add_child(p1_instance)
		p1_instance.setup_fighter(1, "P1: " + p1_name, false)
		print("Spawned P1. Network Authority ID Assigned: ", p1_peer_id)
	else:
		print("⚠️ CRITICAL ERROR: Character scene file missing for P1: ", p1_name)

	# ==========================================
	# 🔵 STEP B: INITIALIZE AND SPAWN PLAYER 2 / CPU
	# ==========================================
	var p2_name: String = GlobalGameData.p2_character
	var p2_should_be_ai: bool = GlobalGameData.p2_is_bot if not GlobalGameData.online else false
	
	if characters_scenes.has(p2_name):
		var p2_instance = characters_scenes[p2_name].instantiate()
		p2_instance.position = p2_spawn.position
		p2_instance.name = "Player2"
		
		# 🔥 CRITICAL FIX: Set multiplayer network authority BEFORE adding to the SceneTree
		if GlobalGameData.online and p2_instance.has_method("set_multiplayer_authority"):
			p2_instance.set_multiplayer_authority(p2_peer_id)
			
		add_child(p2_instance)
		
		var display_label = "CPU: " if p2_should_be_ai else "P2: "
		var final_display_name = display_label + p2_name
		
		p2_instance.setup_fighter(2, final_display_name, p2_should_be_ai)
		print("Spawned P2. Network Authority ID Assigned: ", p2_peer_id)
	else:
		print("⚠️ CRITICAL ERROR: Character scene file missing for P2: ", p2_name)
