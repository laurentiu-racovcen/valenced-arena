extends Control

var menu_manager = Node
@onready var replay_button: TextureButton = $ReplayButton

var _replay_available: bool = false
var _message_label: Label = null

func _ready() -> void:
	menu_manager = get_tree().current_scene
	_update_replay_button()
	_create_message_label()

func _create_message_label() -> void:
	# Create a floating message label for feedback
	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 24)
	_message_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_message_label.add_theme_constant_override("outline_size", 4)
	_message_label.visible = false
	_message_label.text = "No replay available - play a match first!"
	
	# Position below replay button
	if replay_button:
		_message_label.position = replay_button.position + Vector2(-100, replay_button.size.y + 10)
	add_child(_message_label)

func _update_replay_button() -> void:
	# Disable replay button if no replay file exists
	if replay_button == null:
		return
	
	_replay_available = false
	if get_tree().root.has_node("Replay"):
		var replay := get_tree().root.get_node("Replay")
		if replay != null and replay.has_method("has_last_replay"):
			_replay_available = bool(replay.call("has_last_replay"))
	
	replay_button.disabled = not _replay_available
	
	# Visual effect: dim the button when disabled
	if not _replay_available:
		replay_button.modulate = Color(1.0, 1.0, 1.0, 0.706)  # Dimmed and semi-transparent
		replay_button.tooltip_text = "No replay available - play a match first"
	else:
		replay_button.modulate = Color.WHITE
		replay_button.tooltip_text = "Watch the last recorded match"

func _on_play_button_pressed() -> void:
	menu_manager.show_menu("gamemode")


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_settings_button_pressed() -> void:
	menu_manager.show_menu("selector_settings")

func _on_replay_button_pressed() -> void:
	# Check if replay exists
	if not _replay_available:
		_show_no_replay_message()
		return
	
	if get_tree().root.has_node("Replay"):
		var replay := get_tree().root.get_node("Replay")
		if replay != null and replay.has_method("request_replay_last"):
			replay.call("request_replay_last")
			return
	# Fallback: start match
	get_tree().change_scene_to_file("res://scenes/Match.tscn")

func _show_no_replay_message() -> void:
	if _message_label == null:
		return
	_message_label.visible = true
	_message_label.modulate.a = 1.0
	
	# Create fade out tween
	var tween := create_tween()
	tween.tween_interval(1.5)  # Show for 1.5 seconds
	tween.tween_property(_message_label, "modulate:a", 0.0, 0.5)  # Fade out
	tween.tween_callback(func(): _message_label.visible = false)
