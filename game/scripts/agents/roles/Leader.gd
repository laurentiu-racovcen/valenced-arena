extends Node
class_name Leader

var agent: Agent
var target_point: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if not agent or not agent.is_alive():
		return

	# 1. Look for enemies
	var enemies := agent.perception.get_visible_enemies()

	if enemies.size() > 0:
		# Attack nearest enemy
		enemies.sort_custom(
			func(a, b):
				return a.global_position.distance_to(agent.global_position) < b.global_position.distance_to(agent.global_position)
		)

		var enemy = enemies[0]

		# 2. If LOS is blocked → move to a better shooting position
		if not agent.has_line_of_sight_to(enemy):
			var dir_to_enemy = (enemy.global_position - agent.global_position)
			var dist = dir_to_enemy.length()
			var desired_dist := 50.0  # distanța optimă

			if dist > desired_dist:
				var dir_norm = dir_to_enemy / dist
				# apropiere dar fără să intrăm în inamic
				target_point = enemy.global_position - dir_norm * desired_dist
			else:
				# dacă suntem prea aproape și tot nu avem LOS, ne repoziționăm puțin
				var dir_away = -dir_to_enemy.normalized()
				target_point = agent.global_position + dir_away * 60.0
		else:
			# Avem LOS → putem rămâne pe loc
			target_point = agent.global_position

	else:
		# 3. No enemies: move forward toward enemy base
		var fwd: Vector2 = agent.team.forward_dir
		target_point = agent.global_position + fwd * 1000.0
		# alternativ: target_point = Vector2(960, 540)

	# 4. Move toward target using pathfinding
	var dir: Vector2 = agent.get_path_dir(target_point)
	var sep: Vector2 = agent.get_separation_dir(60.0)  # 60 = distanța minimă dorită

	if sep != Vector2.ZERO:
		# combinăm direcția principală cu separarea
		dir = (dir + sep * 0.8).normalized()

	agent.move_dir = dir
	agent.velocity = dir * agent.move_speed
	agent.move_and_slide()
