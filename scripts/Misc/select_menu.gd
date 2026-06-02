extends Control

@onready var stage_preview_display: TextureRect = $PreviewPanel/StagePreviewDisplay
@onready var stage_name_label: Label = $PreviewPanel/StageNameLabel
@onready var stage_grid: GridContainer = $StageGrid

#stage data dictionary
var stage_data: Dictionary = {
	"StageButton1": {
		"name": "Battlefield",
		"preview_path": "res://assets/Stage&CharacterRefrence/Battlefield.png"
	}		
}

func _ready() -> void:
	_connect_grid_signals()
	await get_tree().process_frame
	_build_grid_wrapping_path()
	_intilize_first_focus()

func _connect_grid_signals():
	pass
	
func _build_grid_wrapping_path():
	pass

func _intilize_first_focus():
	pass
