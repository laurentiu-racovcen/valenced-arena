extends Node
class_name Advance

var agent: Agent

func _physics_process(delta: float) -> void:
	if not agent or not agent.is_alive():
		return

	var target_pos: Vector2

	# 1. Încercăm mai întâi să luptăm: vedem vreun inamic?
	var enemies := agent.perception.get_visible_enemies()

	if enemies.size() > 0:
		# cel mai apropiat inamic
		enemies.sort_custom(
			func(a, b):
				return a.global_position.distance_to(agent.global_position) < b.global_position.distance_to(agent.global_position)
		)
		var enemy: Agent = enemies[0] as Agent

		var to_enemy: Vector2 = enemy.global_position - agent.global_position
		var dist := to_enemy.length()
		var desired_dist := 50.0  # cât de aproape vrem să stăm

		var dir_norm: Vector2 = to_enemy / max(dist, 0.001)

		# ne oprim pe un cerc în jurul inamicului, nu intrăm în el
		target_pos = enemy.global_position - dir_norm * desired_dist

	else:
		# 2. Nu vedem inamici → urmăm Leader-ul în formație
		var leader = agent.team.get_leader()
		if leader == null:
			return

		var index = agent.team.members.find(agent)

		var fwd: Vector2 = agent.team.forward_dir
		var right: Vector2 = Vector2(fwd.y, -fwd.x)  # perpendicular pe forward

		# formație 4 oameni în fața leader-ului
		var offset_index := float(index) - 1.5
		target_pos = leader.global_position + fwd * 150.0 + right * offset_index * 120.0

	# 3. Mișcare cu pathfinding
	var dir: Vector2 = agent.get_path_dir(target_pos)
	var sep: Vector2 = agent.get_separation_dir(60.0)  # 60 = distanța minimă dorită

	if sep != Vector2.ZERO:
		# combinăm direcția principală cu separarea
		dir = (dir + sep * 0.8).normalized()

	agent.move_dir = dir
	agent.move_towards(target_pos, delta, 1.2, 55.0, 0.6)
