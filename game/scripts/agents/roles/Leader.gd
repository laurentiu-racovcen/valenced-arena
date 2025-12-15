extends Node
class_name Leader

var agent: Agent
var target_point: Vector2 = Vector2.ZERO
var idle_roam_target: Vector2 = Vector2.ZERO
var idle_roam_timer: float = 0.0
@export var idle_roam_interval: float = 2.0
@export var idle_roam_reached_dist: float = 140.0
@export var debug_leader: bool = false
var _dbg_timer: float = 0.0
var _no_contact_timer: float = 0.0
@export var leave_enemy_base_after: float = 6.0
@export var enemy_base_radius: float = 220.0
@export var enemy_base_exit_radius: float = 320.0 # hysteresis to avoid flip-flopping on the boundary
@export var idle_roam_radius: float = 260.0       # roam locally around the enemy base
@export var avoid_enemy_base_after_leave: float = 8.0 # time to stay away after "no-contact" leave
@export var search_reached_dist: float = 140.0
@export var combat_memory_time: float = 1.2
@export var combat_retarget_interval: float = 0.25
@export var combat_retarget_distance: float = 90.0
@export var combat_min_move_dist: float = 45.0
@export var combat_strafe_offset: float = 110.0       # smaller than before to reduce "spinning"
@export var combat_strafe_duration: float = 0.6       # seconds per strafe burst
@export var combat_strafe_cooldown: float = 1.4       # seconds between bursts
@export var combat_bad_clamp_threshold: float = 80.0  # if desired->clamped jumps this far, stop strafing
var _enemy_base_center: Vector2 = Vector2.ZERO
var _in_enemy_base: bool = false
var _forced_leave_base: bool = false
var _dbg_clamp_timer: float = 0.0
var _avoid_enemy_base_timer: float = 0.0
var _search_target: Vector2 = Vector2.ZERO
var _search_stage: int = 0 # 0=TOP, 1=BOTTOM, 2=OWN_BASE
var _combat_target: Agent = null
var _combat_timer: float = 0.0
var _combat_move_target: Vector2 = Vector2.ZERO
var _combat_move_timer: float = 0.0
var _dbg_combat_timer: float = 0.0
var _strafe_time: float = 0.0
var _strafe_cd: float = 0.0

# Team coordination: broadcast a focus target so the squad concentrates fire.
@export var focus_broadcast_interval: float = 0.8
@export var focus_hold_time: float = 1.8
@export var focus_priority: int = 4
var _focus_broadcast_timer: float = 0.0
var _focus_target_id: String = ""
var _focus_timer: float = 0.0

func _physics_process(delta: float) -> void:
	if not agent or not agent.is_alive():
		return

	idle_roam_timer = max(idle_roam_timer - delta, 0.0)
	_dbg_timer = max(_dbg_timer - delta, 0.0)
	_dbg_clamp_timer = max(_dbg_clamp_timer - delta, 0.0)
	_avoid_enemy_base_timer = max(_avoid_enemy_base_timer - delta, 0.0)
	_combat_timer = max(_combat_timer - delta, 0.0)
	_combat_move_timer = max(_combat_move_timer - delta, 0.0)
	_dbg_combat_timer = max(_dbg_combat_timer - delta, 0.0)
	_strafe_time = max(_strafe_time - delta, 0.0)
	_strafe_cd = max(_strafe_cd - delta, 0.0)
	_focus_broadcast_timer = max(_focus_broadcast_timer - delta, 0.0)
	_focus_timer = max(_focus_timer - delta, 0.0)

	# 1. Look for enemies
	var enemies := agent.perception.get_visible_enemies()
	var enemy: Agent = null
	if enemies.size() > 0:
		# Attack nearest enemy
		enemies.sort_custom(
			func(a, b):
				return a.global_position.distance_to(agent.global_position) < b.global_position.distance_to(agent.global_position)
		)
		enemy = enemies[0] as Agent
		_combat_target = enemy
		_combat_timer = combat_memory_time
	elif _combat_timer > 0.0 and _combat_target != null and is_instance_valid(_combat_target) and _combat_target.is_alive():
		# Brief combat persistence so we don't "run past" enemies on LOS/FOV flicker.
		enemy = _combat_target

	var in_combat: bool = enemy != null
	if in_combat:
		_no_contact_timer = 0.0
		_avoid_enemy_base_timer = 0.0
	else:
		_no_contact_timer += delta

	_in_enemy_base = false

	if in_combat:
		if enemy == null:
			return

		# Broadcast focus target occasionally so teammates coordinate on the same enemy.
		var enemy_id: String = enemy.id if enemy.id != "" else enemy.name
		if enemy_id != "" and (_focus_broadcast_timer <= 0.0 or enemy_id != _focus_target_id):
			_focus_broadcast_timer = focus_broadcast_interval
			_focus_target_id = enemy_id
			_focus_timer = focus_hold_time
			if agent.has_node("AgentComms"):
				var comms := agent.get_node("AgentComms") as AgentComms
				if comms != null:
					comms.broadcast_focus_target(enemy_id, enemy.global_position, focus_priority)
					if debug_leader:
						print("[LEADER] %s broadcast FOCUS -> %s" % [agent.name, enemy_id])

		# 2. Combat movement: keep distance and strafe when we have LOS.
		var desired_dist := 240.0
		var to_enemy: Vector2 = enemy.global_position - agent.global_position
		var dist: float = to_enemy.length()
		var dir_norm: Vector2 = to_enemy / max(dist, 0.001)
		var has_los: bool = agent.has_line_of_sight_to(enemy)
		var right: Vector2 = Vector2(-dir_norm.y, dir_norm.x)
		var sign: float = 1.0 if int(agent.get_instance_id()) % 2 == 0 else -1.0
		# Anchor point on a ring around the enemy (stable target; avoids oscillation)
		var anchor: Vector2 = enemy.global_position - dir_norm * desired_dist

		var desired_target: Vector2
		if not has_los or dist > desired_dist * 1.15:
			# Close in to a good firing distance / regain LOS
			desired_target = anchor
		elif dist < desired_dist * 0.75:
			# Too close: back off a bit
			desired_target = enemy.global_position - dir_norm * (desired_dist + 120.0)
		else:
			# Good range + LOS: mostly HOLD the anchor, strafe only in short bursts.
			if _strafe_time <= 0.0 and _strafe_cd <= 0.0:
				_strafe_time = combat_strafe_duration
				_strafe_cd = combat_strafe_cooldown
			if _strafe_time > 0.0:
				desired_target = anchor + right * sign * combat_strafe_offset
			else:
				desired_target = anchor

		# If the desired target would clamp far away, do NOT strafe/orbit (it causes "spin").
		# Fall back to the anchor in that case.
		var desired_clamped: Vector2 = agent.clamp_point_to_nav(desired_target)
		if desired_clamped.distance_to(desired_target) > combat_bad_clamp_threshold:
			_strafe_time = 0.0
			desired_target = anchor

		# Combat retarget smoothing: don't change the move target every frame (prevents stutter).
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
			if debug_leader and _dbg_combat_timer <= 0.0:
				_dbg_combat_timer = 0.35
				print("[LEADER] %s combat retarget | reason=%s | los=%s | dist=%.1f | desired=%s | chosen=%s" % [
					agent.name,
					reason,
					"YES" if has_los else "NO",
					dist,
					str(desired_target),
					str(_combat_move_target)
				])

		target_point = _combat_move_target
		# If we end up very close to the move target (nav considers it "finished"),
		# push a bit sideways so we keep moving during the fight.
		if agent.global_position.distance_to(target_point) < combat_min_move_dist:
			# Only a small nudge; big nudges look like orbiting.
			target_point = target_point + right * sign * 80.0

	else:
		_combat_move_target = Vector2.ZERO
		_combat_move_timer = 0.0
		# 3. No enemies: advance toward the enemy base (spawn center).
		# Using "forward * N" can push targets outside the navmesh and make teams stick to corners.
		var enemy_team_id: int = 1 - int(agent.team.id)
		var base_map := agent.map.current_map as BaseMap if agent.map else null
		_enemy_base_center = Vector2.ZERO
		if base_map:
			_enemy_base_center = base_map.get_team_spawn_center(enemy_team_id)
			target_point = _enemy_base_center
		else:
			# Fallback if map isn't ready for some reason
			var fwd: Vector2 = agent.team.forward_dir
			target_point = agent.global_position + fwd * 600.0

		# If we're already at the enemy base area, roam a bit to avoid "stopping forever".
		# IMPORTANT: do NOT pick a new random roam point every frame (causes jitter).
		if agent.map == null or _enemy_base_center == Vector2.ZERO:
			_in_enemy_base = false
		else:
			var d_to_enemy_base := agent.global_position.distance_to(_enemy_base_center)
			# Sticky state: enter at `enemy_base_radius`, exit at `enemy_base_exit_radius`
			if _in_enemy_base:
				_in_enemy_base = d_to_enemy_base < enemy_base_exit_radius
			else:
				_in_enemy_base = d_to_enemy_base < enemy_base_radius

		# If we recently left the enemy base due to no-contact, avoid immediately going back.
		if not _in_enemy_base and _avoid_enemy_base_timer > 0.0:
			# Keep moving toward our current search target (top/bottom/own base).
			if _search_target == Vector2.ZERO:
				_search_target = agent.global_position
			target_point = _search_target

			# If we reached it early, advance to the next patrol point while timer is active.
			if agent.global_position.distance_to(_search_target) < search_reached_dist and base_map != null:
				_search_stage = (_search_stage + 1) % 3
				var center := base_map.get_map_center()
				var half := base_map.get_map_half_extents()
				var y_off := half.y * 0.65
				match _search_stage:
					0:
						_search_target = center + Vector2(0.0, -y_off) # top-mid
					1:
						_search_target = center + Vector2(0.0,  y_off) # bottom-mid
					2:
						_search_target = base_map.get_team_spawn_center(int(agent.team.id)) # own base
				target_point = _search_target

		# If we previously decided to leave the enemy base, keep that decision until we actually exit.
		if _forced_leave_base and _in_enemy_base:
			if base_map:
				target_point = base_map.get_map_center()
			else:
				target_point = agent.global_position  # safe fallback
		elif _forced_leave_base and not _in_enemy_base:
			_forced_leave_base = false

		# If we've been in the enemy base area with no contacts for a while,
		# force a search point away from the base (prevents "camping" forever).
		if _in_enemy_base and not _forced_leave_base and _no_contact_timer > leave_enemy_base_after:
			var elapsed := _no_contact_timer
			var map_center: Vector2 = agent.global_position
			if base_map:
				map_center = base_map.get_map_center()
				var half := base_map.get_map_half_extents()
				var y_off := half.y * 0.65
				# Start a simple patrol: TOP -> BOTTOM -> OWN_BASE, then allow going back to enemy base.
				match _search_stage:
					0:
						_search_target = map_center + Vector2(0.0, -y_off)
					1:
						_search_target = map_center + Vector2(0.0,  y_off)
					2:
						_search_target = base_map.get_team_spawn_center(int(agent.team.id))
				_search_stage = (_search_stage + 1) % 3
				target_point = _search_target
			else:
				target_point = map_center
			idle_roam_target = Vector2.ZERO
			idle_roam_timer = 0.0
			_forced_leave_base = true
			_avoid_enemy_base_timer = avoid_enemy_base_after_leave
			_no_contact_timer = 0.0 # prevent retrigger spam while we are still inside base radius
			if debug_leader:
				print("[LEADER] %s: Leaving enemy base after %.1fs no-contact -> search center %s" % [
					agent.name, elapsed, str(target_point)
				])
		elif _in_enemy_base and not _forced_leave_base:
			var need_new_roam: bool = idle_roam_target == Vector2.ZERO \
				or agent.global_position.distance_to(idle_roam_target) < idle_roam_reached_dist \
				or idle_roam_timer <= 0.0
			if need_new_roam:
				var old_roam := idle_roam_target
				# Roam locally around the enemy base instead of picking a point anywhere on the map.
				# This avoids huge “go back and forth across the map” swings.
				idle_roam_target = _enemy_base_center + Vector2(
					randf_range(-idle_roam_radius, idle_roam_radius),
					randf_range(-idle_roam_radius, idle_roam_radius)
				)
				# Clamp immediately so we don't keep clamping the same off-nav point every frame.
				idle_roam_target = agent.clamp_point_to_nav(idle_roam_target)
				idle_roam_timer = idle_roam_interval
				if debug_leader:
					print("[LEADER] %s: New roam target %s -> %s (timer=%.1fs)" % [
						agent.name, str(old_roam), str(idle_roam_target), idle_roam_timer
					])
			target_point = idle_roam_target

	# Clamp targets to navmesh to avoid drifting into holes/borders
	var unclamped := target_point
	target_point = agent.clamp_point_to_nav(target_point)
	# Re-apply the "keep moving in combat" nudge AFTER clamping (clamp can undo the offset).
	if in_combat and agent.global_position.distance_to(target_point) < combat_min_move_dist and enemy != null:
		var to_enemy2: Vector2 = enemy.global_position - agent.global_position
		var dist2: float = to_enemy2.length()
		var dir2: Vector2 = to_enemy2 / max(dist2, 0.001)
		var right2: Vector2 = Vector2(-dir2.y, dir2.x)
		var sign2: float = 1.0 if int(agent.get_instance_id()) % 2 == 0 else -1.0
		target_point = agent.clamp_point_to_nav(target_point + right2 * sign2 * 140.0)
	if debug_leader and unclamped.distance_to(target_point) > 10.0 and _dbg_clamp_timer <= 0.0:
		_dbg_clamp_timer = 1.0
		print("[LEADER] %s: Target clamped %s -> %s (delta=%.1f)" % [
			agent.name, str(unclamped), str(target_point), unclamped.distance_to(target_point)
		])

	# Periodic status (low spam)
	if debug_leader and _dbg_timer <= 0.0:
		_dbg_timer = 1.0
		var mode: String = "COMBAT" if in_combat else ("ROAM" if _in_enemy_base else "ADVANCE")
		print("[LEADER] %s: mode=%s | pos=%s | target=%s | dist=%.1f | visible_enemies=%d | in_enemy_base=%s | no_contact=%.1f/%.1f | enemy_base=%s" % [
			agent.name, mode, str(agent.global_position), str(target_point),
			agent.global_position.distance_to(target_point), enemies.size()
			, "YES" if _in_enemy_base else "NO"
			, _no_contact_timer, leave_enemy_base_after
			, str(_enemy_base_center)
		])

	# 4. Move toward target using pathfinding (computed inside move_towards)
	var speed_mult := 1.0
	var sep_dist := 85.0
	var sep_weight := 1.0
	if in_combat:
		# During combat, reduce separation (it repels from enemies too) so we commit to the fight.
		speed_mult = 1.05
		sep_dist = 60.0
		sep_weight = 0.2
	agent.move_towards(target_point, delta, speed_mult, sep_dist, sep_weight)

func on_focus_target(message: Message) -> void:
	# Leaders can optionally use focus too, but primarily they broadcast it.
	if message == null or message.content == null:
		return
	var tid: String = str(message.content.get("target_id", ""))
	if tid == "":
		return
	_focus_target_id = tid
	_focus_timer = focus_hold_time
