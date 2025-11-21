extends Node
class_name Leader
var agent: Agent
var target_point: Vector2 = Vector2.ZERO

func _physics_process(delta):
	if not agent or not agent.is_alive():
		return

	# 1. Look for enemies
	var enemies = agent.perception.get_visible_enemies()

	if enemies.size() > 0:
		# Attack nearest enemy
		enemies.sort_custom(func(a, b): return a.global_position.distance_to(agent.global_position) < b.global_position.distance_to(agent.global_position))
		target_point = enemies[0].global_position

	else:
		# Default attack point (center of map)
		target_point = Vector2(2000, 1000)

	# 2. Move toward target
	var dir = (target_point - agent.global_position).normalized()
	agent.velocity = dir * agent.move_speed
	agent.move_and_slide()

	# 3. Shooting
	agent.fire_cooldown -= delta
	if agent.fire_cooldown <= 0:
		agent._try_shoot()
