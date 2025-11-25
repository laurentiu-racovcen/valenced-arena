extends Node
class_name Support
var agent: Agent


func _physics_process(delta: float) -> void:
	if not agent or not agent.is_alive():
		return

	var comms = agent.team.comms
	var help_req = comms.get_help_request()  # Implement it when needed

	var target_pos: Vector2

	if help_req:
		# Go help teammate
		target_pos = help_req.global_position
	else:
		# Follow the tank by default
		var tank = _get_tank()
		if tank:
			target_pos = tank.global_position + Vector2(-200, 50)
		else:
			return

	var dir = (target_pos - agent.global_position).normalized()
	agent.move_dir = dir
	agent.velocity = dir * agent.move_speed
	agent.move_and_slide()

	#agent.fire_cooldown -= delta
	#if agent.fire_cooldown <= 0:
		#agent._try_shoot()

func _get_tank():
	for m in agent.team.members:
		if m.role == Agent.Role.TANK:
			return m
	return null
