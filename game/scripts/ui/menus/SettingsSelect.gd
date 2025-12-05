extends Control

@onready var section_display: TextureRect = $SectionDisplay
@onready var menu_manager : Node
@onready var SECTION_TEXTURES = [
	preload("res://assets/menu/normal/settings/sections-selector/button_rounds.png"),
	preload("res://assets/menu/normal/settings/sections-selector/button_agents.png"),
]
@onready var sections = [
	"round_settings",
	"agent_settings",
]

var current_section_index: int = 0


func _ready() -> void:
	menu_manager = get_tree().current_scene
	_update_sections()
	



func _on_right_arrow_pressed() -> void:
	current_section_index = (current_section_index + 1) % SECTION_TEXTURES.size()
	_update_sections()

func _on_left_arrow_pressed() -> void:
	current_section_index = (current_section_index - 1 + SECTION_TEXTURES.size()) % SECTION_TEXTURES.size()
	_update_sections()

func _update_sections() -> void:
	section_display.texture = SECTION_TEXTURES[current_section_index]


func _on_select_button_pressed() -> void:
	menu_manager.show_menu(sections[current_section_index])
