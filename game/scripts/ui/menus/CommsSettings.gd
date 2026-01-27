extends Control
class_name CommsSettings

## Communication settings panel - controls how agents communicate

signal setting_changed(value: int)

enum CommsLevel { FULL = 0, PARTIAL = 1, NONE = 2 }

var current_level: CommsLevel = CommsLevel.FULL

@onready var full_button: TextureButton = $FullButton if has_node("FullButton") else null
@onready var partial_button: TextureButton = $PartialButton if has_node("PartialButton") else null
@onready var no_button: TextureButton = $NoButton if has_node("NoButton") else null

func _ready() -> void:
	if full_button:
		full_button.pressed.connect(_on_full_pressed)
	if partial_button:
		partial_button.pressed.connect(_on_partial_pressed)
	if no_button:
		no_button.pressed.connect(_on_no_pressed)

func _on_full_pressed() -> void:
	current_level = CommsLevel.FULL
	setting_changed.emit(current_level)

func _on_partial_pressed() -> void:
	current_level = CommsLevel.PARTIAL
	setting_changed.emit(current_level)

func _on_no_pressed() -> void:
	current_level = CommsLevel.NONE
	setting_changed.emit(current_level)
