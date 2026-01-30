extends Node
class_name Tank

var agent: Agent
@export var combat_memory_time: float = 3.0  # Increased to prevent "pass-by" behavior
var _combat_target: Agent = null
var _combat_timer: float = 0.0

# Focus target from comms (Leader broadcast)
@export var focus_hold_time: float = 1.6
var _focus_target_id: String = ""
var _focus_timer: float = 0.0

func _physics_process(delta: float) -> void:
	if not agent or not agent.is_alive():
		return
	
	# KOTH MODE: Let KothBehavior handle all movement
	if agent.has_meta("koth_behavior"):
		var koth = agent.get_meta("koth_behavior")
		if koth != null and is_instance_valid(koth):
			return  # KothBehavior handles everything

	var target_pos: Vector2
	var speed_mult: float = 0.8
	var sep_dist: float = 120.0
	var sep_weight: float = 1.3
	_combat_timer = max(_combat_timer - delta, 0.0)
	_focus_timer = max(_focus_timer - delta, 0.0)

	# 1. Inamic în zonă?
	var enemies := agent.perception.get_visible_enemies()
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
		var dist := to_enemy.length()
		var desired_dist := 140.0
		var dir_norm: Vector2 = to_enemy / max(dist, 0.001)
		var has_los: bool = agent.has_line_of_sight_to(enemy)
		var right: Vector2 = Vector2(-dir_norm.y, dir_norm.x)
		var sign: float = 1.0 if int(agent.get_instance_id()) % 2 == 0 else -1.0
		var anchor: Vector2 = enemy.global_position - dir_norm * desired_dist

		if not has_los or dist > desired_dist * 1.2:
			target_pos = anchor
		elif dist < desired_dist * 0.7:
			target_pos = enemy.global_position - dir_norm * (desired_dist + 80.0)
		else:
			# Strafe a bit at optimal distance instead of freezing
			target_pos = anchor + right * sign * 110.0
		speed_mult = 0.9
		sep_dist = 80.0
		sep_weight = 0.2
	else:
		# KOTH MODE: Use KOTH behavior target if available (Tank holds hill with 0.9 weight)
		var koth_active = false
		if agent.has_meta("koth_behavior"):
			var koth = agent.get_meta("koth_behavior")
			if koth != null and is_instance_valid(koth) and koth.has_method("get_koth_target"):
				var koth_target = koth.get_koth_target()
				if koth_target != Vector2.ZERO:
					target_pos = koth_target
					koth_active = true
					# Tank with high hold weight should move slower when on hill
					if koth.should_hold_point():
						speed_mult = 0.7
						sep_dist = 100.0
						sep_weight = 0.9
					else:
						speed_mult = 1.0
						sep_dist = 80.0
						sep_weight = 0.8
		
		# CTF MODE: Use CTF behavior target if available (and KOTH not active)
		var ctf_active = false
		if not koth_active and agent.has_meta("ctf_behavior"):
			var ctf = agent.get_meta("ctf_behavior")
			if ctf != null and is_instance_valid(ctf) and ctf.has_method("get_ctf_target"):
				var ctf_target = ctf.get_ctf_target()
				if ctf_target != Vector2.ZERO and ctf_target != agent.global_position:
					target_pos = ctf_target
					ctf_active = true
					speed_mult = 1.0
					sep_dist = 80.0
					sep_weight = 0.8
		
		# Regular mode or fallback
		if not koth_active and not ctf_active:
			# 2. Fără inamici → stă și el aproape de leader (rol de “bodyguard”)
			var leader: Agent = agent.team.get_leader() if agent.team != null else null
			if leader == null:
				return
	
			var fwd: Vector2 = agent.team.forward_dir
			var right: Vector2 = Vector2(fwd.y, -fwd.x)
			var d_to_leader: float = agent.global_position.distance_to(leader.global_position)
	
			# Catch-up logic so Tank doesn't "camp spawn" while leader moves out.
			if d_to_leader > 360.0:
				target_pos = leader.global_position + fwd * 40.0
				speed_mult = 1.25
				# In dense spawn clusters, separation can push us backward.
				# So reduce separation while catching up.
				sep_dist = 50.0
				sep_weight = 0.35
			elif d_to_leader > 200.0:
				target_pos = leader.global_position - fwd * 40.0 + right * 40.0
				speed_mult = 1.05
				sep_dist = 70.0
				sep_weight = 0.55
			else:
				target_pos = leader.global_position - fwd * 80.0 + right * 60.0
				speed_mult = 0.9
				sep_dist = 110.0
				sep_weight = 1.1

	# Clamp targets to navmesh to avoid drifting into holes/borders
	target_pos = agent.clamp_point_to_nav(target_pos)

	# 3. Mișcare pe path (computed inside move_towards)
	agent.move_towards(target_pos, delta, speed_mult, sep_dist, sep_weight)

func on_focus_target(message: Message) -> void:
	if message == null or message.content == null:
		return
	var tid: String = str(message.content.get("target_id", ""))
	if tid == "":
		return
	_focus_target_id = tid
	_focus_timer = focus_hold_time
