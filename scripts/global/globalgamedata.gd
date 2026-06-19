extends Node

var selected_stage_path: String = ""
var p1_character: String = ""
var p2_character: String = ""
var p2_is_bot: bool = false

var match_stocks: int = 3
var stage_hazards_enabled: bool = true
var damage_multiplier: float = 1.0
var character_size_multiplier: float = 1.0

var target_room_is_public: bool = true
var room_pass = ""
var online_test = true
var disconnection_alert: String = ""
var online = false
var P1 = ""
var P2 = ""

var local_match_result: String = ""
var match_end_reason: String = ""   
