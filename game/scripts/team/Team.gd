extends Node
class_name Team

@export var teamName: String = "Team"
var id
var forward_dir: Vector2 = Vector2.RIGHT
var members: Array[Agent] = []
@onready var comms: CommsManager = $Comms

func _ready():
	forward_dir = Vector2.RIGHT if id == 0 else Vector2.LEFT

const ROLE_ORDER = [
	Agent.Role.LEADER,
	Agent.Role.TANK,
	Agent.Role.SUPPORT,
	Agent.Role.ADVANCE
]

func add_member(agent: Agent) -> void:
	members.append(agent)
	agent.team = self
	id = get_team_id()

	if agent.id == "":
		agent.id = agent.name

	_assign_roles()
	
func _assign_roles():
	# First 3 agents get: Leader, Tank, Support
	for i in range(members.size()):
		if i < ROLE_ORDER.size():
			members[i].set_role(ROLE_ORDER[i])
		else:
			members[i].set_role(Agent.Role.ADVANCE)   # SCUT


func get_team_id() -> int:
	if name.ends_with("A"):
		return 0
	elif name.ends_with("B"):
		return 1
	return 0

func get_leader() -> Agent:
	for member in members:
		if member.role == Agent.Role.LEADER:
			return member
	return null
	
func remove_member(agent: Agent):
	if members.has(agent):
		members.erase(agent)
	call_deferred("_on_team_members_changed")

#func _on_team_members_changed():
	#_check_win_condition()
	#
