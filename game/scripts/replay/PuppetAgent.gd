extends Node2D
class_name PuppetAgent
## Lightweight agent for replay visualization.
## No AI, no physics, no collisions - just visual representation.

@onready var skin: Sprite2D = $Skin
@onready var role_label: Label = $HealthUI/VBox/RoleBG/RoleLabel
@onready var health_bar_fill: ColorRect = $HealthUI/VBox/HealthBarBG/HealthBarFill

var id: String = ""
var team_id: int = 0  # 0 = blue, 1 = red
var role: int = 0  # Agent.Role enum value

var max_hp: int = 100
var hp: int = 100

const TEAM_ROLE_SKINS := {
	"blue": {
		0: preload("res://assets/agents/Blue Team/blue_leader_agent.png"),  # LEADER
		1: preload("res://assets/agents/Blue Team/blue_advance_agent.png"), # ADVANCE
		2: preload("res://assets/agents/Blue Team/blue_tank_agent.png"),    # TANK
		3: preload("res://assets/agents/Blue Team/blue_support_agent.png"), # SUPPORT
	},
	"red": {
		0: preload("res://assets/agents/Red Team/red_leader_agent.png"),  # LEADER
		1: preload("res://assets/agents/Red Team/red_advance_agent.png"), # ADVANCE
		2: preload("res://assets/agents/Red Team/red_tank_agent.png"),    # TANK
		3: preload("res://assets/agents/Red Team/red_support_agent.png"), # SUPPORT
	}
}

const ROLE_NAMES := ["LDR", "ADV", "TNK", "SUP"]

func _ready() -> void:
	# Disable all processing - we're puppeted externally
	set_process(false)
	set_physics_process(false)
	
	_update_health_ui()
	_update_role_label()

func setup(agent_id: String, team: int, agent_role: int) -> void:
	id = agent_id
	team_id = team
	role = agent_role
	
	# Apply skin - get node directly in case called before _ready
	var team_str := "blue" if team == 0 else "red"
	_apply_skin(team_str, role)
	_update_role_label()

func _apply_skin(team_str: String, role_value: int) -> void:
	# Get skin node directly (works even before _ready)
	var skin_node: Sprite2D = get_node_or_null("Skin")
	if skin_node == null:
		return
	var tex = TEAM_ROLE_SKINS.get(team_str, {}).get(role_value, null)
	if tex:
		skin_node.visible = true
		skin_node.texture = tex
		print("[PuppetAgent] Applied skin: team=%s, role=%d" % [team_str, role_value])

func apply_state(x: float, y: float, rot: float, agent_hp: int, _ammo: int, alive: bool) -> void:
	## Called by ReplayController each frame to update puppet state
	global_position = Vector2(x, y)
	
	# Apply rotation to the skin sprite
	if skin:
		skin.rotation = rot
	
	hp = agent_hp
	_update_health_ui()
	
	# Show/hide based on alive state
	visible = alive

func _update_health_ui() -> void:
	if health_bar_fill == null:
		return
	
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	health_bar_fill.scale.x = ratio
	
	# Color gradient: green -> yellow -> red
	if ratio > 0.5:
		health_bar_fill.color = Color(0.2, 0.8, 0.2)
	elif ratio > 0.25:
		health_bar_fill.color = Color(0.8, 0.8, 0.2)
	else:
		health_bar_fill.color = Color(0.8, 0.2, 0.2)

func _update_role_label() -> void:
	if role_label == null:
		return
	
	if role >= 0 and role < ROLE_NAMES.size():
		role_label.text = ROLE_NAMES[role]
	else:
		role_label.text = "???"
