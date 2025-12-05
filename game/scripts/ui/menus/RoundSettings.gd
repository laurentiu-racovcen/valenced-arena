extends Control


@onready var duration_display: TextureButton = $Duration
@onready var number_display: TextureButton = $Number
@onready var menu_manager : Node

const DURATION_TEXTURES_NORMAL = [
	preload("res://assets/menu/normal/settings/section-rounds/duration_30s.png"),
	preload("res://assets/menu/normal/settings/section-rounds/duration_60s.png"),
	preload("res://assets/menu/normal/settings/section-rounds/duration_90s.png"),
]

const DURATION_TEXTURES_HOVER = [
	preload("res://assets/menu/hover/settings/section-rounds/duration_30s.png"),
	preload("res://assets/menu/hover/settings/section-rounds/duration_60s.png"),
	preload("res://assets/menu/hover/settings/section-rounds/duration_90s.png"),
]

const  NUMBER_TEXTURES_NORMAL = [
	preload("res://assets/menu/normal/settings/section-rounds/nr_rounds_1.png"),
	preload("res://assets/menu/normal/settings/section-rounds/nr_rounds_2.png"),
	preload("res://assets/menu/normal/settings/section-rounds/nr_rounds_3.png"),
	preload("res://assets/menu/normal/settings/section-rounds/nr_rounds_4.png"),
	preload("res://assets/menu/normal/settings/section-rounds/nr_rounds_5.png"),	
]

const  NUMBER_TEXTURES_HOVER = [
	preload("res://assets/menu/hover/settings/section-rounds/nr_rounds_1.png"),
	preload("res://assets/menu/hover/settings/section-rounds/nr_rounds_2.png"),
	preload("res://assets/menu/hover/settings/section-rounds/nr_rounds_3.png"),
	preload("res://assets/menu/hover/settings/section-rounds/nr_rounds_4.png"),
	preload("res://assets/menu/hover/settings/section-rounds/nr_rounds_5.png"),	
]

@onready var current_duration_index = 0
@onready var current_number_index = 0



func _ready() -> void:
	menu_manager = get_tree().current_scene
	_update_duration()
	_update_number()
	



func _update_duration() -> void:
	duration_display.texture_normal = DURATION_TEXTURES_NORMAL[current_duration_index]
	duration_display.texture_hover = DURATION_TEXTURES_HOVER[current_duration_index]

func _update_number() -> void:
	number_display.texture_normal = NUMBER_TEXTURES_NORMAL[current_number_index]
	number_display.texture_hover = NUMBER_TEXTURES_HOVER[current_number_index]


func _on_duration_pressed() -> void:
	current_duration_index = (current_duration_index + 1) % DURATION_TEXTURES_NORMAL.size()
	_update_duration()


func _on_number_pressed() -> void:
	current_number_index = (current_number_index + 1) % NUMBER_TEXTURES_NORMAL.size()
	_update_number()
