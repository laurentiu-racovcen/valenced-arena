extends Node
class_name Support

var agent: Agent
var current_assist_target: Agent = null
var assist_urgency: int = 0
var last_assist_time: float = 0.0
@export var combat_memory_time: float = 3.0  # Increased to prevent "pass-by" behavior
var _combat_target: Agent = null
var _combat_timer: float = 0.0

# Focus target from comms (Leader broadcast)
@export var focus_hold_time: float = 1.6
var _focus_target_id: String = ""
var _focus_timer: float = 0.0

const ASSIST_TIMEOUT: float = 10.0
const ASSIST_DISTANCE: float = 200.0

func _physics_process(delta: float) -> void:
	if not agent or not agent.is_alive():
		return

	var target_pos: Vector2 = agent.global_position
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var speed_mult: float = 0.95
	var sep_dist: float = 95.0
	var sep_weight: float = 1.1
	_combat_timer = max(_combat_timer - delta, 0.0)
	_focus_timer = max(_focus_timer - delta, 0.0)

	# 0) Combat: keep distance and strafe (don't freeze while shooting)
	var enemies: Array = agent.perception.get_visible_enemies()
	var enemy: Agent = null
	if enemies.size() > 0:
		# Prefer focus target if visible
		if _focus_timer > 0.0 and _focus_target_id != "":
			for e in enemies:
				var a := e as Agent
				if a == null:
					continue
				var aid: String = a.id if a.id != "" else a.name
				if aid == _focus_target_id:
					enemy = a
					break

		enemies.sort_custom(
			func(a, b):
				return a.global_position.distance_to(agent.global_position) < b.global_position.distance_to(agent.global_position)
		)
		if enemy == null:
			enemy = enemies[0] as Agent
		_combat_target = enemy
		_combat_timer = combat_memory_time
	elif _combat_timer > 0.0 and _combat_target != null and is_instance_valid(_combat_target) and _combat_target.is_alive():
		enemy = _combat_target

	var in_combat: bool = enemy != null
	if in_combat:
			var to_enemy: Vector2 = enemy.global_position - agent.global_position
			var dist: float = to_enemy.length()
			var desired_dist: float = 220.0
			var dir_norm: Vector2 = to_enemy / max(dist, 0.001)
			var has_los: bool = agent.has_line_of_sight_to(enemy)
			var right: Vector2 = Vector2(-dir_norm.y, dir_norm.x)
			var sign: float = 1.0 if int(agent.get_instance_id()) % 2 == 0 else -1.0
			var anchor: Vector2 = enemy.global_position - dir_norm * desired_dist

			if not has_los or dist > desired_dist * 1.2:
				target_pos = anchor
			elif dist < desired_dist * 0.75:
				target_pos = enemy.global_position - dir_norm * (desired_dist + 100.0)
			else:
				target_pos = anchor + right * sign * 130.0
			speed_mult = 1.0
			sep_dist = 70.0
			sep_weight = 0.2

	elif current_assist_target != null and (current_time - last_assist_time) <= ASSIST_TIMEOUT and current_assist_target.is_alive():
		# Assist: move near the requesting agent
		var to_friend: Vector2 = current_assist_target.global_position - agent.global_position
		var d: float = to_friend.length()
		var dn: Vector2 = to_friend / max(d, 0.001)
		target_pos = current_assist_target.global_position - dn * ASSIST_DISTANCE
		speed_mult = 1.1
		sep_dist = 75.0
		sep_weight = 0.7
	else:
		# CTF MODE: Use CTF behavior target if available
		var ctf_active = false
		if agent.has_meta("ctf_behavior"):
			var ctf = agent.get_meta("ctf_behavior")
			if ctf != null and is_instance_valid(ctf) and ctf.has_method("get_ctf_target"):
				var ctf_target = ctf.get_ctf_target()
				if ctf_target != Vector2.ZERO and ctf_target != agent.global_position:
					target_pos = ctf_target
					ctf_active = true
					speed_mult = 1.0
					sep_dist = 80.0
					sep_weight = 0.8
		
		# Default: stay near the tank, otherwise the leader (only when CTF not active)
		if not ctf_active:
			var tank := _get_tank()
			if tank != null:
				var d_to_tank: float = agent.global_position.distance_to(tank.global_position)
				target_pos = tank.global_position
				# Catch up if lagging behind
				if d_to_tank > 320.0:
					speed_mult = 1.2
					sep_dist = 45.0
					sep_weight = 0.35
				elif d_to_tank > 180.0:
					speed_mult = 1.05
					sep_dist = 65.0
					sep_weight = 0.55
				else:
					sep_dist = 90.0
					sep_weight = 0.95
			else:
				var leader: Agent = null
				if agent.team != null:
					leader = agent.team.get_leader()
				if leader != null:
					var d_to_leader: float = agent.global_position.distance_to(leader.global_position)
					target_pos = leader.global_position
					if d_to_leader > 320.0:
						speed_mult = 1.2
						sep_dist = 45.0
						sep_weight = 0.35
					elif d_to_leader > 180.0:
						speed_mult = 1.05
						sep_dist = 65.0
						sep_weight = 0.55
					else:
						sep_dist = 90.0
						sep_weight = 0.95
				else:
					# FALLBACK: No tank or leader, move toward enemy base
					var enemy_team_id: int = 1 - int(agent.team.id) if agent.team else 1
					var base_map = agent.map.current_map if agent.map else null
					if base_map and base_map.has_method("get_team_spawn_center"):
						target_pos = base_map.get_team_spawn_center(enemy_team_id)
					else:
						# Just move forward
						var fwd: Vector2 = agent.team.forward_dir if agent.team else Vector2.RIGHT
						target_pos = agent.global_position + fwd * 400.0

	# Always move each frame
	target_pos = agent.clamp_point_to_nav(target_pos)
	agent.move_towards(target_pos, delta, speed_mult, sep_dist, sep_weight)

func on_focus_target(message: Message) -> void:
	if message == null or message.content == null:
		return
	var tid: String = str(message.content.get("target_id", ""))
	if tid == "":
		return
	_focus_target_id = tid
	_focus_timer = focus_hold_time

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
