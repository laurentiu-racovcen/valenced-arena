extends Control
class_name CommsSettings

## Communication settings panel - controls how agents communicate

signal setting_changed(value: int)

enum CommsLevel { FULL = 0, PARTIAL = 1, NONE = 2 }

var current_level: CommsLevel = CommsLevel.FULL

# Textures for each communication level
const COMMS_TEXTURES = [
	preload("res://assets/menu/normal/settings/section-comms/full.png"),
	preload("res://assets/menu/normal/settings/section-comms/partial.png"),
	preload("res://assets/menu/normal/settings/section-comms/no.png"),
]

@onready var comms_display: TextureButton = $CommsEnabled if has_node("CommsEnabled") else null

func _ready() -> void:
	# Load saved setting from SettingsManager if available
	if Engine.has_singleton("SettingsManager") or has_node("/root/SettingsManager"):
		var settings_manager = get_node_or_null("/root/SettingsManager")
		if settings_manager:
			current_level = settings_manager.get_comms_enabled_index() as CommsLevel
	_update_display()

func _on_left_arrow_enabled_pressed() -> void:
	current_level = ((current_level - 1) + COMMS_TEXTURES.size()) % COMMS_TEXTURES.size() as CommsLevel
	_update_display()
	_save_setting()
	setting_changed.emit(current_level)

func _on_right_arrow_enabled_pressed() -> void:
	current_level = (current_level + 1) % COMMS_TEXTURES.size() as CommsLevel
	_update_display()
	_save_setting()
	setting_changed.emit(current_level)

func _on_comms_enabled_pressed() -> void:
	# Clicking the display cycles to the next option
	_on_right_arrow_enabled_pressed()

func _update_display() -> void:
	if comms_display:
		comms_display.texture_normal = COMMS_TEXTURES[current_level]

func _save_setting() -> void:
	var settings_manager = get_node_or_null("/root/SettingsManager")
	if settings_manager:
		settings_manager.set_comms_enabled_index(current_level)
