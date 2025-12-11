extends Node

# Settings file paths
const DEFAULT_SETTINGS_PATH = "res://data/configs/settings.json"
const USER_SETTINGS_PATH = "user://settings.json"

# Settings will be loaded from data/configs/ at startup
var settings: Dictionary = {}

func _ready() -> void:
	load_settings()

## Load settings: first from user file, then from data/configs/, finally use fallback
func load_settings() -> void:
	# Try to load user settings first
	if FileAccess.file_exists(USER_SETTINGS_PATH):
		var file = FileAccess.open(USER_SETTINGS_PATH, FileAccess.READ)
		if file and file.get_length() > 0:
			var json = JSON.new()
			var error = json.parse(file.get_as_text())
			if error == OK:
				settings = json.data
				print("[SettingsManager] Loaded user settings from %s" % USER_SETTINGS_PATH)
				return
	
	# If user file doesn't exist, load from default config in data/
	if ResourceLoader.exists(DEFAULT_SETTINGS_PATH):
		var file = FileAccess.open(DEFAULT_SETTINGS_PATH, FileAccess.READ)
		if file and file.get_length() > 0:
			var json = JSON.new()
			var error = json.parse(file.get_as_text())
			if error == OK:
				settings = json.data
				print("[SettingsManager] Loaded default settings from %s" % DEFAULT_SETTINGS_PATH)
				save_settings()  # Save to user directory for next time
				return
	
	# If no files exist, use hardcoded fallback
	print("[SettingsManager] WARNING: Using hardcoded fallback settings")
	settings = {
		"agent": {
			"fov_index": 0,
			"los_index": 1,
			"speed_index": 1
		},
		"rounds": {
			"duration_index": 0,
			"number_index": 0
		}
	}
	save_settings()

## Save settings to user JSON file
func save_settings() -> void:
	var file = FileAccess.open(USER_SETTINGS_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(settings, "\t")
		file.store_string(json_string)
		print("[SettingsManager] Saved settings to %s" % USER_SETTINGS_PATH)
	else:
		push_error("[SettingsManager] Failed to save settings to %s" % USER_SETTINGS_PATH)

## Get agent settings
func get_agent_fov_index() -> int:
	return settings["agent"]["fov_index"]

func get_agent_los_index() -> int:
	return settings["agent"]["los_index"]

func get_agent_speed_index() -> int:
	return settings["agent"]["speed_index"]

## Set agent settings
func set_agent_fov_index(index: int) -> void:
	settings["agent"]["fov_index"] = index
	save_settings()

func set_agent_los_index(index: int) -> void:
	settings["agent"]["los_index"] = index
	save_settings()

func set_agent_speed_index(index: int) -> void:
	settings["agent"]["speed_index"] = index
	save_settings()

## Get round settings
func get_rounds_duration_index() -> int:
	return settings["rounds"]["duration_index"]

func get_rounds_number_index() -> int:
	return settings["rounds"]["number_index"]

## Set round settings
func set_rounds_duration_index(index: int) -> void:
	settings["rounds"]["duration_index"] = index
	save_settings()

func set_rounds_number_index(index: int) -> void:
	settings["rounds"]["number_index"] = index
	save_settings()

## Get all settings as dictionary
func get_all_settings() -> Dictionary:
	return settings.duplicate(true)
