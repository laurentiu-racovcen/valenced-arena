extends Node
class_name Advance

var agent: Agent
@export var debug_advance: bool = false
@export var combat_memory_time: float = 1.0
@export var combat_retarget_interval: float = 0.25
@export var combat_retarget_distance: float = 80.0
@export var combat_min_move_dist: float = 40.0
@export var combat_strafe_offset: float = 95.0        # smaller than before to reduce orbiting
@export var combat_strafe_duration: float = 0.55
@export var combat_strafe_cooldown: float = 1.35
@export var combat_bad_clamp_threshold: float = 80.0
var _combat_target: Agent = null
var _combat_timer: float = 0.0
var _combat_move_target: Vector2 = Vector2.ZERO
var _combat_move_timer: float = 0.0
var _dbg_timer: float = 0.0
var _strafe_time: float = 0.0
var _strafe_cd: float = 0.0

# Focus target from comms (Leader broadcast)
@export var focus_hold_time: float = 1.6
var _focus_target_id: String = ""
var _focus_timer: float = 0.0

func _physics_process(delta: float) -> void:
	if not agent or not agent.is_alive():
		return

	var target_pos: Vector2
	_combat_timer = max(_combat_timer - delta, 0.0)
	_combat_move_timer = max(_combat_move_timer - delta, 0.0)
	_dbg_timer = max(_dbg_timer - delta, 0.0)
	_focus_timer = max(_focus_timer - delta, 0.0)
	_strafe_time = max(_strafe_time - delta, 0.0)
	_strafe_cd = max(_strafe_cd - delta, 0.0)

	# 1. Încercăm mai întâi să luptăm: vedem vreun inamic?
	var enemies := agent.perception.get_visible_enemies()

	var enemy: Agent = null
	if enemies.size() > 0:
		# If we have a focus target, prefer it when visible.
		if _focus_timer > 0.0 and _focus_target_id != "":
			for e in enemies:
				var a := e as Agent
				if a == null:
					continue
				var aid: String = a.id if a.id != "" else a.name
				if aid == _focus_target_id:
					enemy = a
					break

		# cel mai apropiat inamic
		if enemy == null:
			enemies.sort_custom(
				func(a, b):
					return a.global_position.distance_to(agent.global_position) < b.global_position.distance_to(agent.global_position)
			)
			enemy = enemies[0] as Agent
		_combat_target = enemy
		_combat_timer = combat_memory_time
	elif _combat_timer > 0.0 and _combat_target != null and is_instance_valid(_combat_target) and _combat_target.is_alive():
		enemy = _combat_target

	var in_combat: bool = enemy != null
	if in_combat:
		var to_enemy: Vector2 = enemy.global_position - agent.global_position
		var dist: float = to_enemy.length()
		var desired_dist: float = 190.0
		var dir_norm: Vector2 = to_enemy / max(dist, 0.001)
		var has_los: bool = agent.has_line_of_sight_to(enemy)
		var right: Vector2 = Vector2(-dir_norm.y, dir_norm.x)
		var sign: float = 1.0 if int(agent.get_instance_id()) % 2 == 0 else -1.0
		var anchor: Vector2 = enemy.global_position - dir_norm * desired_dist

		var desired_target: Vector2
		if not has_los or dist > desired_dist * 1.15:
			desired_target = anchor
		elif dist < desired_dist * 0.75:
			desired_target = enemy.global_position - dir_norm * (desired_dist + 110.0)
		else:
			# Mostly HOLD at the anchor; short strafe bursts only.
			if _strafe_time <= 0.0 and _strafe_cd <= 0.0:
				_strafe_time = combat_strafe_duration
				_strafe_cd = combat_strafe_cooldown
			if _strafe_time > 0.0:
				desired_target = anchor + right * sign * combat_strafe_offset
			else:
				desired_target = anchor

		# If strafe target would clamp far away, stop strafing (prevents "spin").
		var desired_clamped: Vector2 = agent.clamp_point_to_nav(desired_target)
		if desired_clamped.distance_to(desired_target) > combat_bad_clamp_threshold:
			_strafe_time = 0.0
			desired_target = anchor

		# Combat retarget smoothing to prevent nav jitter/stutter.
		var reason := ""
		if _combat_move_target == Vector2.ZERO \
			or _combat_move_timer <= 0.0 \
			or desired_target.distance_to(_combat_move_target) > combat_retarget_distance:
			if _combat_move_target == Vector2.ZERO:
				reason = "init"
			elif _combat_move_timer <= 0.0:
				reason = "timer"
			else:
				reason = "dist"
			_combat_move_target = desired_target
			_combat_move_timer = combat_retarget_interval
			if debug_advance and _dbg_timer <= 0.0:
				_dbg_timer = 0.35
				print("[ADV] %s retarget=%s | reason=%s | los=%s | dist=%.1f | desired=%s | chosen=%s" % [
					agent.name,
					"YES",
					reason,
					"YES" if has_los else "NO",
					dist,
					str(desired_target),
					str(_combat_move_target)
				])
		target_pos = _combat_move_target
		# Avoid "standing still" when we're at the move target.
		if agent.global_position.distance_to(target_pos) < combat_min_move_dist:
			target_pos = target_pos + right * sign * 70.0

	else:
		_combat_move_target = Vector2.ZERO
		_combat_move_timer = 0.0
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

	# Clamp targets to navmesh to avoid drifting into holes/borders
	target_pos = agent.clamp_point_to_nav(target_pos)

	# 3. Mișcare cu pathfinding (computed inside move_towards)
	var speed_mult := 1.2
	var sep_dist := 55.0
	var sep_weight := 0.6
	if in_combat:
		speed_mult = 1.15
		sep_dist = 50.0
		sep_weight = 0.15
	agent.move_towards(target_pos, delta, speed_mult, sep_dist, sep_weight)

func on_focus_target(message: Message) -> void:
	if message == null or message.content == null:
		return
	var tid: String = str(message.content.get("target_id", ""))
	if tid == "":
		return
	_focus_target_id = tid
	_focus_timer = focus_hold_time
