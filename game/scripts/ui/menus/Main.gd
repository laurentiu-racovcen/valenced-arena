extends Control

var menu_manager = Node

func _ready() -> void:
	menu_manager = get_tree().current_scene

func _on_play_button_pressed() -> void:
	menu_manager.show_menu("gamemode")


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_settings_button_pressed() -> void:
	menu_manager.show_menu("selector_settings")
