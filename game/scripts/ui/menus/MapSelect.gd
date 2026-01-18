extends Control

@onready var map_display: TextureRect = $MapPreview
@onready var title_display: TextureRect = $Title

# Map thumbnails for survival mode (with frame already included)
const SURVIVAL_MAP_TEXTURES := [
	preload("res://assets/menu/normal/map-select/map1.png"),
	preload("res://assets/menu/normal/map-select/map2.png"),
	preload("res://assets/menu/normal/map-select/map3.png"),
	preload("res://assets/menu/normal/map-select/map4.png"),
]

# Map scene paths corresponding to textures
const SURVIVAL_MAP_SCENES := [
	"res://scenes/maps/SurvivalMap.tscn",
	"res://scenes/maps/KothMap.tscn",
	"res://scenes/maps/CtfMap.tscn",
	"res://scenes/maps/SecondMap.tscn",
]

var current_map_index: int = 0

func _ready() -> void:
	_update_map_display()

func _on_start_button_pressed() -> void:
	# Store selected map in MatchConfig
	MatchConfig.selected_map = SURVIVAL_MAP_SCENES[current_map_index]
	get_tree().change_scene_to_file("res://scenes/Match.tscn")

func _on_right_arrow_pressed() -> void:
	current_map_index = (current_map_index + 1) % SURVIVAL_MAP_TEXTURES.size()
	_update_map_display()

func _on_left_arrow_pressed() -> void:
	current_map_index = (current_map_index - 1 + SURVIVAL_MAP_TEXTURES.size()) % SURVIVAL_MAP_TEXTURES.size()
	_update_map_display()

func _update_map_display() -> void:
	map_display.texture = SURVIVAL_MAP_TEXTURES[current_map_index]
