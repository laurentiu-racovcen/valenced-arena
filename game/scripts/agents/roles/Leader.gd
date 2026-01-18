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
@export var combat_memory_time: float = 3.0  # Increased to prevent "pass-by" behavior
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
var _returning_to_center: bool = false  # Tracks if we're committed to returning to center
var _searching_at_center: bool = false  # Tracks if we're searching around center
var _center_search_timer: float = 0.0
@export var search_at_center_time: float = 4.0  # How long to search at center before going to enemy base
@export var center_search_radius: float = 300.0  # Roaming radius around center
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
	_center_search_timer = max(_center_search_timer - delta, 0.0)

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
		var dist_to_enemy: float = enemy.global_position.distance_to(agent.global_position)
		
		# CTF MODE: Check if we should prioritize objective over combat
		var should_skip_combat: bool = false
		if agent.has_meta("ctf_behavior"):
			var ctf = agent.get_meta("ctf_behavior")
			if ctf != null and is_instance_valid(ctf) and ctf.has_method("should_prioritize_objective"):
				# DELIVER_FLAG (state 5) = NEVER fight, just run!
				if ctf.current_state == 5:  # DELIVER_FLAG
					should_skip_combat = true  # Always skip combat when carrying flag
				elif ctf.should_prioritize_objective() or (ctf.current_state == 0): # ATTACK_FLAG = 0
					should_skip_combat = dist_to_enemy > 200.0  # Only fight if within 200px
		
		if not should_skip_combat:
			_combat_target = enemy
			_combat_timer = combat_memory_time
		else:
			enemy = null  # Don't enter combat, continue to objective
	elif _combat_timer > 0.0 and _combat_target != null and is_instance_valid(_combat_target) and _combat_target.is_alive():
		# Brief combat persistence so we don't "run past" enemies on LOS/FOV flicker.
		enemy = _combat_target

	var in_combat: bool = enemy != null
	if in_combat:
		_no_contact_timer = 0.0
		_avoid_enemy_base_timer = 0.0
		# Reset patrol states when entering combat - stay and fight!
		_returning_to_center = false
		_searching_at_center = false
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
		
		# CTF MODE: Use CTF behavior target if available
		var ctf_active = false
		if agent.has_meta("ctf_behavior"):
			var ctf = agent.get_meta("ctf_behavior")
			if ctf != null and is_instance_valid(ctf) and ctf.has_method("get_ctf_target"):
				var ctf_target = ctf.get_ctf_target()
				if ctf_target != Vector2.ZERO and ctf_target != agent.global_position:
					target_point = ctf_target
					ctf_active = true
		
		# Fallback to default targeting if CTF not active
		if not ctf_active:
			target_point = _get_default_target()
	
	# Clamp targets to navmesh to avoid drifting into holes/borders
	var unclamped := target_point
	target_point = agent.clamp_point_to_nav(target_point)
	
	# Move toward target using pathfinding
	var speed_mult := 1.0
	var sep_dist := 85.0
	var sep_weight := 1.0
	if in_combat:
		speed_mult = 1.05
		sep_dist = 60.0
		sep_weight = 0.2
	agent.move_towards(target_point, delta, speed_mult, sep_dist, sep_weight)

func _get_default_target() -> Vector2:
	# 3. No enemies: advance toward the enemy base (spawn center).
	# Using "forward * N" can push targets outside the navmesh and make teams stick to corners.
	var enemy_team_id: int = 1 - int(agent.team.id)
	var own_team_id: int = int(agent.team.id)
	var base_map := agent.map.current_map as BaseMap if agent.map else null
	_enemy_base_center = Vector2.ZERO
	if base_map:
		_enemy_base_center = base_map.get_team_spawn_center(enemy_team_id)
		var own_base_center: Vector2 = base_map.get_team_spawn_center(own_team_id)
		var map_center: Vector2 = (own_base_center + _enemy_base_center) * 0.5
		
		# Check if we're already at the enemy base (use large radius to catch agents near spawn)
		var dist_to_enemy_base: float = agent.global_position.distance_to(_enemy_base_center)
		var dist_to_center: float = agent.global_position.distance_to(map_center)
		
		# If we're returning to center, stay committed until we reach it
		if _returning_to_center:
			if dist_to_center < 200.0:
				# Reached center, start searching around center
				_returning_to_center = false
				_searching_at_center = true
				_center_search_timer = search_at_center_time
				if debug_leader:
					print("[LEADER] %s reached center, searching for %.1fs" % [agent.name, search_at_center_time])
			else:
				# Still heading to center
				return map_center
		
		# If searching at center, roam around looking for enemies
		if _searching_at_center:
			if _center_search_timer <= 0.0:
				# Done searching, push to enemy base
				_searching_at_center = false
				if debug_leader:
					print("[LEADER] %s done searching, pushing to enemy base" % agent.name)
			else:
				# Roam around center
				if idle_roam_timer <= 0.0 or agent.global_position.distance_to(idle_roam_target) < idle_roam_reached_dist:
					idle_roam_timer = idle_roam_interval
					var angle: float = randf() * TAU
					idle_roam_target = map_center + Vector2(cos(angle), sin(angle)) * center_search_radius
					idle_roam_target = agent.clamp_point_to_nav(idle_roam_target)
					if debug_leader:
						print("[LEADER] %s searching center, roaming to %s" % [agent.name, str(idle_roam_target)])
				return idle_roam_target
		
		# If we're close to enemy base but no enemies, start returning to center
		# Using 400px radius to ensure we catch agents who are "at" the enemy spawn area
		if dist_to_enemy_base < 400.0:
			_returning_to_center = true
			if debug_leader and randf() < 0.05:
				print("[LEADER] %s at enemy base (dist=%.0f), returning to center" % [agent.name, dist_to_enemy_base])
			return map_center
		
		# Debug: print target occasionally to diagnose survival mode issues
		if debug_leader and randf() < 0.01:
			print("[LEADER] %s _get_default_target -> enemy_base_center=%s (enemy_team=%d)" % [agent.name, str(_enemy_base_center), enemy_team_id])
		return _enemy_base_center
	else:
		# Fallback if map isn't ready for some reason
		var fwd: Vector2 = agent.team.forward_dir
		if debug_leader:
			print("[LEADER] %s _get_default_target -> FALLBACK forward*600" % agent.name)
		return agent.global_position + fwd * 600.0

func on_focus_target(message: Message) -> void:
	# Leaders can optionally use focus too, but primarily they broadcast it.
	if message == null or message.content == null:
		return
	var tid: String = str(message.content.get("target_id", ""))
	if tid == "":
		return
	_focus_target_id = tid
	_focus_timer = focus_hold_time
