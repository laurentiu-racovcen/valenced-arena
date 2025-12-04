extends Control


@onready var sections = [$RoundSettings, $AgentSettings]
var current_section_index: int = 0


func _ready() -> void:
	_apply_section_visibility()


func _apply_section_visibility() -> void:
	for i in sections.size():
		sections[i].visible = (i == current_section_index)

func _on_right_arrow_pressed() -> void:
	current_section_index = (current_section_index + 1) % sections.size()
	_update_sections()

func _on_left_arrow_pressed() -> void:
	current_section_index = (current_section_index - 1 + sections.size()) % sections.size()
	_update_sections()

func _update_sections() -> void:
	for i in sections.size():
		sections[i].visible = (i == current_section_index)


func _on_select_button_pressed() -> void:
	pass # Replace with function body.
