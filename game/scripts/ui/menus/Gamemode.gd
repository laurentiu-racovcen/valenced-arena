extends Control

@onready var mode_display: TextureRect = $ModeDisplay

const MODE_TEXTURES := [
	preload("res://assets/menu/normal/gamemode-select/button_survival.png"),
	preload("res://assets/menu/normal/gamemode-select/button_koth.png"),
	preload("res://assets/menu/normal/gamemode-select/button_ctf.png"),
]

var current_mode_index: int = 0

func _ready() -> void:
	_update_modes()

func _on_start_button_pressed() -> void:
	MatchConfig.game_mode = current_mode_index as Enums.GameMode
	# For Survival mode, show map selection first
	if current_mode_index == Enums.GameMode.SURVIVAL:
		var menu_manager = get_parent() as Control
		if menu_manager and menu_manager.has_method("show_menu"):
			menu_manager.show_menu("mapselect")
		return
	# For other modes, start directly
	MatchConfig.selected_map = ""  # Use default map for mode
	get_tree().change_scene_to_file("res://scenes/Match.tscn")

func _on_right_arrow_pressed() -> void:
	current_mode_index = (current_mode_index + 1) % MODE_TEXTURES.size()
	_update_modes()

func _on_left_arrow_pressed() -> void:
	current_mode_index = (current_mode_index - 1 + MODE_TEXTURES.size()) % MODE_TEXTURES.size()
	_update_modes()

func _update_modes() -> void:
	mode_display.texture = MODE_TEXTURES[current_mode_index]
