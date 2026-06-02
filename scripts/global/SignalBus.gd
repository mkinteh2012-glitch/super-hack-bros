extends Node

signal global_player_damaged(player_id: int, total_percent: float, heavy_hit: bool)
signal player_died(player_id: int)
signal stocks_updated(player_id: int, current_stocks: int)

var camera_cinematic_lock: bool = false
