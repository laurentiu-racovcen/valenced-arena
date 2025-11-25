extends Node
class_name Tank
var agent: Agent


func _physics_process(delta: float) -> void:
	# Utility AI logic aici
	if not agent or not agent.is_alive():
		return

	var leader = agent.team.get_leader()
	if not leader:
		return

	# Position behind leader by 150 px
	var follow_pos = leader.global_position + Vector2(-150, 0)

	# Move aggressively toward follow position
	var dir = (follow_pos - agent.global_position).normalized()
	agent.move_dir = dir
	agent.velocity = dir * agent.move_speed * 1.1   # slightly faster
	agent.move_and_slide()

	# Shooting
	#agent.fire_cooldown -= delta
	#if agent.fire_cooldown <= 0:
		#agent._try_shoot()
