extends Node
class_name AgentPerception

var agent: Agent

func _ready() -> void:
	agent = get_parent() as Agent

func get_visible_enemies() -> Array:
	if not agent or not agent.map:
		return []

	var agents_root = agent.get_parent()
	while agents_root and agents_root.name != "AgentsRoot":
		agents_root = agents_root.get_parent()

	if agents_root == null:
		return []

	var res: Array = []
	for other in agents_root.get_children():
		if other == agent:
			continue
		if other.team.id == agent.team.id:
			continue

		var dist = agent.global_position.distance_to(other.global_position)
		if dist <= agent.los_range:
			# aici poți folosi GameMap.has_line_of_sight dacă vrei
			if agent.map.has_line_of_sight(agent.global_position, other.global_position, [agent, other]):
				res.append(other)

	return res
