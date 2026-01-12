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

func _on_replay_button_pressed() -> void:
	# Recorded replay playback via Replay autoload.
	if get_tree().root.has_node("Replay"):
		var replay := get_tree().root.get_node("Replay")
		if replay != null and replay.has_method("request_replay_last"):
			replay.call("request_replay_last")
			return
	# Fallback: start match
	get_tree().change_scene_to_file("res://scenes/Match.tscn")
