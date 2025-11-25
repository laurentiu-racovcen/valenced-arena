extends Node
class_name Support

var agent: Agent

## Tracking pentru comportament
var current_assist_target: Agent = null
var assist_urgency: int = 0
var last_assist_time: float = 0.0

const ASSIST_TIMEOUT: float = 10.0
const ASSIST_DISTANCE: float = 200.0

func _physics_process(delta: float) -> void:
	if not agent or not agent.is_alive():
		return

	var target_pos: Vector2
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# === PRIORITY 1: Răspunde la ASSIST === #
	if current_assist_target and current_assist_target.is_alive():
		if current_time - last_assist_time > ASSIST_TIMEOUT:
			print("[Support] %s timeout ASSIST pentru %s" % [agent.id, current_assist_target.id])
			current_assist_target = null
			assist_urgency = 0
		else:
			target_pos = current_assist_target.global_position
			var distance_to_target = agent.global_position.distance_to(target_pos)
			
			if distance_to_target < ASSIST_DISTANCE:
				print("[Support] %s ajunge la %s, atacă inamici!" % [agent.id, current_assist_target.id])
				var dir = (target_pos - agent.global_position).normalized()
				agent.velocity = dir * agent.move_speed * 0.3
			else:
				var dir = (target_pos - agent.global_position).normalized()
				agent.velocity = dir * agent.move_speed * 1.2
			
			agent.move_and_slide()
			agent.fire_cooldown -= delta
			if agent.fire_cooldown <= 0:
				agent._try_shoot()
			return
	
	# === PRIORITY 2: Follow Tank === #
	var tank = _get_tank()
	if tank:
		target_pos = tank.global_position + Vector2(-200, 50)
	else:
		var leader = agent.team.get_leader() if agent.team else null
		if leader:
			target_pos = leader.global_position + Vector2(-150, 0)
		else:
			return

	var dir = (target_pos - agent.global_position).normalized()
	agent.velocity = dir * agent.move_speed
	agent.move_and_slide()
	agent.fire_cooldown -= delta
	if agent.fire_cooldown <= 0:
		agent._try_shoot()

## === CALLBACK PENTRU ASSIST === ##
func on_assist_request(message: Message) -> void:
	
	if not agent or not agent.team:
		return
	
	var sender = agent.team.members.filter(func(m): return m.id == message.sender or m.name == message.sender)
	if sender.is_empty():
		return
	
	var requesting_agent = sender[0]
	var urgency = message.content.urgency
	
	print("[Support] %s primește ASSIST de la %s (urgency: %d, current: %d)" % [
		agent.id, requesting_agent.id, urgency, assist_urgency
	])
	
	if not current_assist_target or urgency > assist_urgency:
		current_assist_target = requesting_agent
		assist_urgency = urgency
		last_assist_time = Time.get_ticks_msec() / 1000.0
		
		print("[Support] %s RĂSPUNDE la ASSIST de la %s! Mergând în ajutor..." % [
			agent.id, requesting_agent.id
		])

func _get_tank() -> Agent:
	if not agent or not agent.team:
		return null
	
	for m in agent.team.members:
		if m.role == Agent.Role.TANK and m.is_alive():
			return m
	return null
