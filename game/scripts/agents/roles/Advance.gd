extends Node
class_name Advance
var agent: Agent


func _physics_process(delta: float) -> void:
	if not agent or not agent.is_alive():
		return

	var leader = agent.team.get_leader()
	if not leader:
		return

	# Index determines formation position
	var index = agent.team.members.find(agent)

	# Spread them horizontally in front of the leader
	var x_offset = (index - 3) * 120
	var formation_pos = leader.global_position + Vector2(150, 0) + Vector2(x_offset, 0)

	# Move toward formation position
	var dir = (formation_pos - agent.global_position).normalized()
	agent.velocity = dir * agent.move_speed
	agent.move_and_slide()

	# Shooting (leader triggers direction)
	agent.fire_cooldown -= delta
	if agent.fire_cooldown <= 0:
		agent._try_shoot()
