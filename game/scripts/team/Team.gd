extends Node
class_name Team

@export var teamName: String = "Team"
var id
var members: Array[Agent] = []
@onready var comms: CommsManager = $Comms

func add_member(agent: Agent) -> void:
	members.append(agent)
	agent.team = self
	id = get_team_id()
	if agent.id == "":
		agent.id = agent.name

func get_team_id() -> int:
	if name.ends_with("A"):
		return 0
	elif name.ends_with("B"):
		return 1
	return 0
