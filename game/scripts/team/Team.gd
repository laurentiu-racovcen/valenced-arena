extends Node
class_name Team

@export var teamName: String = "Team"
var members: Array[Agent] = []
@onready var comms: CommsManager = $Comms
var map: GameMap

func add_member(agent: Agent) -> void:
	members.append(agent)
	agent.team = self
	agent.map = map
	if agent.id == "":
		agent.id = agent.name
	comms.register_agent(agent.id, agent)
