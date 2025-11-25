extends Control

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Root centering container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# VBox inside, for vertical layout
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	# Buttons
	for label in ["Replay last match", "Play", "Settings"]:
		var btn := Button.new()
		btn.text = label
		btn.custom_minimum_size = Vector2(220, 40)
		vbox.add_child(btn)

		match label:
			"Replay last match":
				btn.pressed.connect(_on_replay_last_match_pressed)
			"Play":
				btn.pressed.connect(_on_play_pressed)
			"Settings":
				btn.pressed.connect(_on_settings_pressed)

func _on_play_pressed() -> void:
	# Start normal game
	get_tree().change_scene_to_file("res://scenes/MatchMenu.tscn")

func _on_replay_last_match_pressed() -> void:
	# Open replay scene (you can load the last log inside that scene/script)
	get_tree().change_scene_to_file("res://Replay.tscn")

func _on_settings_pressed() -> void:
	# TODO: change to a Settings scene or open a popup
	# get_tree().change_scene_to_file("res://Settings.tscn")
	pass
