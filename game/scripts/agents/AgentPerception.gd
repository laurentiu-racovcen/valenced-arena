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
		
		# Check Line of Sight RANGE (max vision distance)
		if dist > agent.los_range:
			# Debug: occasionally print rejected enemies
			if agent.debug_perception and randf() < 0.01:
				print("[PERCEPTION] %s: Enemy %s OUT OF RANGE (dist: %.1f > los_range: %.1f)" % [
					agent.name, other.name, dist, agent.los_range
				])
			continue
		
		# Check Field of View (FOV) - can only see enemies in front
		if not agent.is_in_fov(other.global_position):
			# Debug: occasionally print why enemy is not visible
			if agent.debug_perception and randf() < 0.005:  # 0.5% of the time
				print("[PERCEPTION] %s: Enemy %s out of FOV (dist: %.1f)" % [
					agent.name, other.name, dist
				])
			continue
		
		# Check Line of Sight (LOS) - no walls blocking
		if not agent.map.has_line_of_sight(agent.global_position, other.global_position, [agent, other]):
			# Debug: occasionally print why enemy is blocked
			if agent.debug_perception and randf() < 0.005:  # 0.5% of the time
				print("[PERCEPTION] %s: Enemy %s blocked by wall (dist: %.1f)" % [
					agent.name, other.name, dist
				])
			continue
		
		# Debug: occasionally print when enemy IS visible
		if agent.debug_perception and randf() < 0.01:
			print("[PERCEPTION] %s: Enemy %s VISIBLE (dist: %.1f, los_range: %.1f)" % [
				agent.name, other.name, dist, agent.los_range
			])
		
		res.append(other)

	return res
