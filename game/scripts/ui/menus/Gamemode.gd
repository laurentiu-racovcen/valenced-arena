extends Control

@onready var modes  = [$SurvivalMode, $KothMode, $CtfMode]
var current_mode_index: int = 0

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Match.tscn")


func _on_right_arrow_pressed() -> void:
	current_mode_index = (current_mode_index + 1) % modes.size()
	_update_modes()

func _on_left_arrow_pressed() -> void:
	current_mode_index = (current_mode_index - 1 + modes.size()) % modes.size()
	_update_modes()

func _update_modes() -> void:
	for i in modes.size():
		modes[i].visible = (i == current_mode_index)
