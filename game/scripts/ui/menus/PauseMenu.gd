extends Control
class_name PauseMenu

signal resume_pressed
signal main_menu_pressed

@onready var resume_button: TextureButton = $VBox/Buttons/ResumeButton
@onready var main_menu_button: TextureButton = $VBox/Buttons/MainMenuButton
@onready var music_button: TextureButton = $VBox/Buttons/MusicButton
@onready var sound_button: TextureButton = $VBox/Buttons/SoundButton

var music_on_texture: Texture2D = preload("res://assets/menu/normal/common/buttons/music_on.png")
var music_off_texture: Texture2D = preload("res://assets/menu/normal/common/buttons/music_off.png")
var music_on_hover: Texture2D = preload("res://assets/menu/hover/common/buttons/music_on.png")
var music_off_hover: Texture2D = preload("res://assets/menu/hover/common/buttons/music_off.png")
var sound_on_texture: Texture2D = preload("res://assets/menu/normal/common/buttons/sound_on.png")
var sound_off_texture: Texture2D = preload("res://assets/menu/normal/common/buttons/sound_off.png")
var sound_on_hover: Texture2D = preload("res://assets/menu/hover/common/buttons/sound_on.png")
var sound_off_hover: Texture2D = preload("res://assets/menu/hover/common/buttons/sound_off.png")
var music_enabled: bool = true
var sound_enabled: bool = true

func _ready() -> void:
	visible = false
	resume_button.pressed.connect(_on_resume_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	music_button.pressed.connect(_on_music_pressed)
	sound_button.pressed.connect(_on_sound_pressed)
	
	# Check current music state
	var music_bus_idx = AudioServer.get_bus_index("Music")
	if music_bus_idx >= 0:
		music_enabled = not AudioServer.is_bus_mute(music_bus_idx)
		_update_music_button()
	
	# Check current sound state (SFX bus or Master if no SFX)
	var sfx_bus_idx = AudioServer.get_bus_index("SFX")
	if sfx_bus_idx < 0:
		sfx_bus_idx = AudioServer.get_bus_index("Master")
	if sfx_bus_idx >= 0:
		sound_enabled = not AudioServer.is_bus_mute(sfx_bus_idx)
		_update_sound_button()

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

func _on_music_pressed() -> void:
	music_enabled = !music_enabled
	var music_bus_idx = AudioServer.get_bus_index("Music")
	if music_bus_idx >= 0:
		AudioServer.set_bus_mute(music_bus_idx, not music_enabled)
	_update_music_button()

func _update_music_button() -> void:
	if music_enabled:
		music_button.texture_normal = music_on_texture
		music_button.texture_hover = music_on_hover
	else:
		music_button.texture_normal = music_off_texture
		music_button.texture_hover = music_off_hover

func _on_sound_pressed() -> void:
	sound_enabled = !sound_enabled
	# Try SFX bus first, fallback to Master
	var sfx_bus_idx = AudioServer.get_bus_index("SFX")
	if sfx_bus_idx < 0:
		sfx_bus_idx = AudioServer.get_bus_index("Master")
	if sfx_bus_idx >= 0:
		AudioServer.set_bus_mute(sfx_bus_idx, not sound_enabled)
	_update_sound_button()

func _update_sound_button() -> void:
	if sound_enabled:
		sound_button.texture_normal = sound_on_texture
		sound_button.texture_hover = sound_on_hover
	else:
		sound_button.texture_normal = sound_off_texture
		sound_button.texture_hover = sound_off_hover

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	
	# Cleanup ScoreHUD (added to root by GameManager)
	var score_hud = get_tree().root.get_node_or_null("ScoreHud")
	if score_hud:
		score_hud.queue_free()
	
	# Cleanup RoundCountdown if present
	var countdown = get_tree().root.get_node_or_null("RoundCountdown")
	if countdown:
		countdown.queue_free()
	
	# Cleanup CTF HUD if present
	for c in get_tree().root.get_children():
		if c is CanvasLayer and c.name.begins_with("CtfHUD"):
			c.queue_free()
	
	# Stop replay playback if active and clean up bullets
	if has_node("/root/Replay"):
		var replay_manager = get_node("/root/Replay")
		if replay_manager.has_method("end_recording"):
			replay_manager.end_recording(false)  # Stop without saving
		# Reset replay state
		if "_state" in replay_manager:
			replay_manager._state = 0  # ReplayState.IDLE
	
	# Clean up bullets and flags from current scene
	var current_scene = get_tree().current_scene
	if current_scene:
		for child in current_scene.get_children():
			if child is Bullet:
				child.queue_free()
			if child.is_in_group("flags"):
				child.queue_free()
	
	main_menu_pressed.emit()
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")
