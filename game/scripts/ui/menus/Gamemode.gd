extends Control

@onready var mode_display: TextureRect = $ModeDisplay
@onready var start_button: TextureButton = $StartButton

const MODE_TEXTURES := [
	preload("res://assets/menu/normal/gamemode-select/button_survival.png"),
	preload("res://assets/menu/normal/gamemode-select/button_koth.png"),
	preload("res://assets/menu/normal/gamemode-select/button_ctf.png"),
]

# Button textures for Next (Survival needs map selection) and Start (CTF/KOTH start directly)
const NEXT_NORMAL := preload("res://assets/menu/normal/gamemode-select/button_next.png")
const NEXT_HOVER := preload("res://assets/menu/hover/gamemode-select/button_next.png")
const START_NORMAL := preload("res://assets/menu/normal/map-select/button_start.png")
const START_HOVER := preload("res://assets/menu/hover/map-select/button_start.png")

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
	
	# Update button texture: Next for Survival (needs map select), Start for CTF/KOTH
	if current_mode_index == Enums.GameMode.SURVIVAL:
		start_button.texture_normal = NEXT_NORMAL
		start_button.texture_hover = NEXT_HOVER
	else:
		start_button.texture_normal = START_NORMAL
		start_button.texture_hover = START_HOVER
