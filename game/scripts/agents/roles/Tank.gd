extends Node
class_name Tank

var agent: Agent

func _physics_process(delta: float) -> void:
	if not agent or not agent.is_alive():
		return

	var target_pos: Vector2

	# 1. Inamic în zonă?
	var enemies := agent.perception.get_visible_enemies()
	if enemies.size() > 0:
		enemies.sort_custom(
			func(a, b):
				return a.global_position.distance_to(agent.global_position) < b.global_position.distance_to(agent.global_position)
		)
		var enemy: Agent = enemies[0] as Agent

		var to_enemy: Vector2 = enemy.global_position - agent.global_position
		var dist := to_enemy.length()
		var desired_dist := 50.0

		if (not agent.has_line_of_sight_to(enemy)) or dist > desired_dist:
			var dir_norm = to_enemy / max(dist, 0.001)
			target_pos = enemy.global_position - dir_norm * desired_dist
		else:
			target_pos = agent.global_position
	else:
		# 2. Fără inamici → stă și el aproape de leader (rol de “bodyguard”)
		var leader = agent.team.get_leader()
		if leader == null:
			return

		var fwd: Vector2 = agent.team.forward_dir
		var right: Vector2 = Vector2(fwd.y, -fwd.x)
		target_pos = leader.global_position - fwd * 80.0 + right * 60.0

	# 3. Mișcare pe path
	var dir: Vector2 = agent.get_path_dir(target_pos)
	var sep: Vector2 = agent.get_separation_dir(60.0)  # 60 = distanța minimă dorită

	if sep != Vector2.ZERO:
		# combinăm direcția principală cu separarea
		dir = (dir + sep * 0.8).normalized()

	agent.move_dir = dir
	agent.velocity = dir * agent.move_speed
	agent.move_and_slide()
