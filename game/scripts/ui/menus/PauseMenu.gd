extends Control
class_name PauseMenu

signal resume_pressed
signal main_menu_pressed

@onready var resume_button: TextureButton = $VBox/Buttons/ResumeButton
@onready var main_menu_button: TextureButton = $VBox/Buttons/MainMenuButton

func _ready() -> void:
	visible = false
	resume_button.pressed.connect(_on_resume_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # ESC key
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	visible = !visible
	get_tree().paused = visible

func _on_resume_pressed() -> void:
	toggle_pause()
	resume_pressed.emit()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	
	# Cleanup ScoreHUD (added to root by GameManager)
	var score_hud = get_tree().root.get_node_or_null("ScoreHud")
	if score_hud:
		score_hud.queue_free()
	
	main_menu_pressed.emit()
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")
