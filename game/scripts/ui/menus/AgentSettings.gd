extends Control


@onready var fov_display: TextureButton = $Fov
@onready var los_display: TextureButton = $Los
@onready var speed_display: TextureButton = $Speed
@onready var FOV_TEXTURES = [
	preload("res://assets/menu/normal/settings/section-agents/button_fov/45_deg.png"),
	preload("res://assets/menu/normal/settings/section-agents/button_fov/60_deg.png"),
	preload("res://assets/menu/normal/settings/section-agents/button_fov/90_deg.png"),
	preload("res://assets/menu/normal/settings/section-agents/button_fov/120_deg.png"),
]
@onready var current_fov_index = 0

@onready var LOS_TEXTURES = [
	preload("res://assets/menu/normal/settings/section-agents/button_los/los_s.png"),
	preload("res://assets/menu/normal/settings/section-agents/button_los/los_m.png"),
	preload("res://assets/menu/normal/settings/section-agents/button_los/los_l.png"),
]

@onready var current_los_index = 1

@onready var SPEED_TEXTURES = [
	preload("res://assets/menu/normal/settings/section-agents/button_speed/slow.png"),
	preload("res://assets/menu/normal/settings/section-agents/button_speed/mid.png"),
	preload("res://assets/menu/normal/settings/section-agents/button_speed/fast.png"),
]

@onready var current_speed_index = 1

func _ready() -> void:
	_update_fov()
	_update_los()
	_update_speed()



func _update_fov() -> void:
	fov_display.texture_normal = FOV_TEXTURES[current_fov_index]

func _update_los() -> void:
	los_display.texture_normal = LOS_TEXTURES[current_los_index]

func _update_speed() -> void:
	speed_display.texture_normal = SPEED_TEXTURES[current_speed_index]




func _on_fov_pressed() -> void:
	current_fov_index = (current_fov_index + 1) % FOV_TEXTURES.size()
	_update_fov()


func _on_los_pressed() -> void:
	current_los_index = (current_los_index + 1) % LOS_TEXTURES.size()
	_update_los()


func _on_speed_pressed() -> void:
	current_speed_index = (current_speed_index + 1) % SPEED_TEXTURES.size()
	_update_speed()
