extends Control


@onready var fov_display: TextureButton = $Fov
@onready var los_display: TextureButton = $Los
@onready var speed_display: TextureButton = $Speed

const FOV_TEXTURES_NORMAL = [
	preload("res://assets/menu/normal/settings/section-agents/button_fov/45_deg.png"),
	preload("res://assets/menu/normal/settings/section-agents/button_fov/60_deg.png"),
	preload("res://assets/menu/normal/settings/section-agents/button_fov/90_deg.png"),
	preload("res://assets/menu/normal/settings/section-agents/button_fov/120_deg.png"),
]

const FOV_TEXTURES_HOVER = [
	preload("res://assets/menu/hover/settings/section-agents/button_fov/45_deg.png"),
	preload("res://assets/menu/hover/settings/section-agents/button_fov/60_deg.png"),
	preload("res://assets/menu/hover/settings/section-agents/button_fov/90_deg.png"),
	preload("res://assets/menu/hover/settings/section-agents/button_fov/120_deg.png"),
]


const LOS_TEXTURES_NORMAL = [
	preload("res://assets/menu/normal/settings/section-agents/button_los/los_s.png"),
	preload("res://assets/menu/normal/settings/section-agents/button_los/los_m.png"),
	preload("res://assets/menu/normal/settings/section-agents/button_los/los_l.png"),
]

const LOS_TEXTURES_HOVER = [
	preload("res://assets/menu/hover/settings/section-agents/button_los/los_s.png"),
	preload("res://assets/menu/hover/settings/section-agents/button_los/los_m.png"),
	preload("res://assets/menu/hover/settings/section-agents/button_los/los_l.png"),
]

const SPEED_TEXTURES_NORMAL = [
	preload("res://assets/menu/normal/settings/section-agents/button_speed/slow.png"),
	preload("res://assets/menu/normal/settings/section-agents/button_speed/mid.png"),
	preload("res://assets/menu/normal/settings/section-agents/button_speed/fast.png"),
]

const SPEED_TEXTURES_HOVER = [
	preload("res://assets/menu/hover/settings/section-agents/button_speed/slow.png"),
	preload("res://assets/menu/hover/settings/section-agents/button_speed/mid.png"),
	preload("res://assets/menu/hover/settings/section-agents/button_speed/fast.png"),
]

var current_fov_index = 0
var current_los_index = 1
var current_speed_index = 1

func _ready() -> void:
	# Load from SettingsManager
	current_fov_index = SettingsManager.get_agent_fov_index()
	current_los_index = SettingsManager.get_agent_los_index()
	current_speed_index = SettingsManager.get_agent_speed_index()
	_update_fov()
	_update_los()
	_update_speed()



func _update_fov() -> void:
	fov_display.texture_normal = FOV_TEXTURES_NORMAL[current_fov_index]
	fov_display.texture_hover = FOV_TEXTURES_HOVER[current_fov_index]

func _update_los() -> void:
	los_display.texture_normal = LOS_TEXTURES_NORMAL[current_los_index]
	los_display.texture_hover = LOS_TEXTURES_HOVER[current_los_index]

func _update_speed() -> void:
	speed_display.texture_normal = SPEED_TEXTURES_NORMAL[current_speed_index]
	speed_display.texture_hover = SPEED_TEXTURES_HOVER[current_speed_index]




func _on_fov_pressed() -> void:
	current_fov_index = (current_fov_index + 1) % FOV_TEXTURES_NORMAL.size()
	SettingsManager.set_agent_fov_index(current_fov_index)
	_update_fov()


func _on_los_pressed() -> void:
	current_los_index = (current_los_index + 1) % LOS_TEXTURES_NORMAL.size()
	SettingsManager.set_agent_los_index(current_los_index)
	_update_los()


func _on_speed_pressed() -> void:
	current_speed_index = (current_speed_index + 1) % SPEED_TEXTURES_NORMAL.size()
	SettingsManager.set_agent_speed_index(current_speed_index)
	_update_speed()
