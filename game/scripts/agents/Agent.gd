extends CharacterBody2D
class_name Agent

enum Role { LEADER, ADVANCE, TANK, SUPPORT }
var role_logic: Node = null

@export var role: Role = Role.ADVANCE

@export var max_hp: int = 100
@export var damage_per_shot: int = 10
@export var fire_rate: float = 2.0
@export var ammo_max: int = 30
@export var reload_time: float = 2.0

@export var fov_angle_deg: float = Enums.AGENT_SETTING_FOV[SettingsManager.get_agent_fov_index()]  # Field of view angle in degrees (120 = can see 60 degrees each side)
@export var los_range: float = Enums.AGENT_SETTING_LOS[SettingsManager.get_agent_los_index()]
@export var move_speed: float = Enums.AGENT_SETTING_SPEED[SettingsManager.get_agent_speed_index()]
# Existing navigation variables

# --- KOTH Mode Variables ---
@export var koth_mode: bool = false
@export var hill_location: Vector2 = Vector2.ZERO
@export var hill_radius: float = 200.0
var movement_locked: bool = false

@onready var perception: AgentPerception = $AgentPerception

@onready var skin: Sprite2D = $Skin
@onready var collision_shape: CollisionShape2D = $Collision

# Navigation pathfinding
var navigation_agent: NavigationAgent2D = null
var navigation_ready: bool = false

const TEAM_ROLE_SKINS := {
	"blue": {
		Role.LEADER: preload("res://assets/agents/Blue Team/blue_leader_agent.png"),
		Role.ADVANCE: preload("res://assets/agents/Blue Team/blue_advance_agent.png"),
		Role.TANK: preload("res://assets/agents/Blue Team/blue_tank_agent.png"),
		Role.SUPPORT: preload("res://assets/agents/Blue Team/blue_support_agent.png"),
	},
	"red": {
		Role.LEADER: preload("res://assets/agents/Red Team/red_leader_agent.png"),
		Role.ADVANCE: preload("res://assets/agents/Red Team/red_advance_agent.png"),
		Role.TANK: preload("res://assets/agents/Red Team/red_tank_agent.png"),
		Role.SUPPORT: preload("res://assets/agents/Red Team/red_support_agent.png"),
	},
}


var move_dir: Vector2 = Vector2.ZERO
var aim_dir: Vector2 = Vector2.ZERO
@export var body_turn_speed: float = 8.0
@export var accel := 10.0  # higher = snappier steering

var hp: int
var ammo: int
var id: String = ""
var team
var map: GameMap
var fire_cooldown: float = 0.0

# Debug toggles (printing a lot can cause visible stutter)
@export var debug_pathfinding: bool = false
@export var debug_shooting: bool = false
@export var debug_perception: bool = false
@export var debug_ai: bool = false  # enables AI role debug logs (Leader, etc.)
@export var debug_draw_fov: bool = false
@export var debug_fov_fill_color: Color = Color(0.1, 0.8, 1.0, 0.14)
@export var debug_fov_edge_color: Color = Color(0.1, 0.8, 1.0, 0.6)
@export var debug_fov_line_width: float = 2.0
@export var debug_fov_segments: int = 26
@export var debug_fov_radius: float = -1.0 # <=0 uses `los_range`; set to e.g. 600 for clearer visuals
@export var debug_fov_clip_to_walls: bool = false # if true, raycast the arc and stop at walls (more accurate, more expensive)
@export var debug_fov_use_team_colors: bool = true
@export var debug_fov_fill_color_team0: Color = Color(0.1, 0.6, 1.0, 0.18) # Team A (blue-ish)
@export var debug_fov_edge_color_team0: Color = Color(0.05, 0.8, 1.0, 0.85)
@export var debug_fov_fill_color_team1: Color = Color(1.0, 0.25, 0.15, 0.18) # Team B (red-ish)
@export var debug_fov_edge_color_team1: Color = Color(1.0, 0.35, 0.2, 0.9)

# Map obstacles often default to collision layer 1. Some projects put them on layer 2.
# Use both by default; you can override per-agent in the Inspector if needed.
@export var wall_mask: int = (1 << 0) | (1 << 1)
@export var avoid_probe: float = 80.0   # how far ahead to probe for walls (should be > agent radius * 2)
@export var avoid_angle_step_deg := 15.0
@export var avoid_steps := 8            # tries per side (8*15=120 deg)

var avoid_dir := Vector2.ZERO
var avoid_lock := 0.0
@export var avoid_lock_time := 0.25

var wall_following := false
var wall_follow_dir := Vector2.ZERO

@export var stuck_time_to_unstuck := 0.35
@export var min_progress_px := 2.0
@export var unstuck_duration := 0.45

var _last_pos: Vector2
var _stuck_time := 0.0
var _unstuck_time := 0.0
var _unstuck_dir := Vector2.ZERO

var roam_target: Vector2
var roam_timer := 0.0
@export var roam_retarget_time := 2.5
@export var roam_reached_dist := 60.0

# Navigation retarget smoothing (reduces jitter / oscillation)
@export var nav_retarget_distance: float = 40.0  # only update nav target if it moved this much
@export var nav_retarget_interval: float = 0.25  # or if this much time passed
var _nav_retarget_timer: float = 0.0
var _nav_target: Vector2 = Vector2.ZERO
var _nav_target_valid: bool = false

# Nav clamping: prevents roles from picking unreachable/off-mesh points.
# Important: if the snap is too large, it can "teleport" the target across walls/holes and
# cause back-and-forth oscillation. These settings make clamping more conservative.
@export var nav_clamp_max_delta: float = 45.0 # max allowed snap distance to the navmesh
@export var nav_clamp_step: float = 260.0     # fallback step toward target if snap would be too large
@export var nav_clamp_iterations: int = 4     # how many times to halve the step

signal died(agent, killer)

func _ready():
	add_to_group("agents")  # ca să îi putem găsi ușor pe toți
	hp = max_hp
	ammo = ammo_max
	_last_pos = global_position
	_setup_navigation()
	_load_role_logic()

func _ray_first_non_agent_hit(from_pos: Vector2, to_pos: Vector2, extra_exclude: Array[RID] = []) -> Dictionary:
	var space := get_world_2d().direct_space_state
	var params := PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	params.collision_mask = wall_mask

	var exclude_rids: Array[RID] = [get_rid()]
	exclude_rids.append_array(extra_exclude)
	params.exclude = exclude_rids

	# If we hit an agent first, ignore it and continue the ray.
	# This matters when agents share collision layer 1 with map collisions.
	for _i in range(8):
		var hit: Dictionary = space.intersect_ray(params)
		if hit.is_empty():
			return {}
		var collider: Object = hit.get("collider")
		if collider != null and collider is Node and (collider as Node).is_in_group("agents"):
			var rid: RID = hit.get("rid", RID())
			exclude_rids.append(rid)
			params.exclude = exclude_rids
			continue
		return hit

	return {}

func _ray_hits_wall(from_pos: Vector2, to_pos: Vector2, extra_exclude: Array[RID] = []) -> bool:
	return not _ray_first_non_agent_hit(from_pos, to_pos, extra_exclude).is_empty()

func _blocked_to_target(target_pos: Vector2) -> bool:
	return _ray_hits_wall(global_position, target_pos)

func _clamp_point_to_nav(pos: Vector2) -> Vector2:
	# If a role asks for a point outside the walkable area (e.g. "move forward 1000px"),
	# clamp it to the closest point on the current navigation map so agents don't
	# pile up against the map border.
	if not navigation_agent or not navigation_ready:
		return pos
	var nav_map: RID = navigation_agent.get_navigation_map()
	if nav_map == RID():
		return pos

	# Keep targets inside the map rectangle to avoid pathological cases like negative Y
	# (we saw combat targets like y=-120), which then clamp to weird far nav points.
	var desired: Vector2 = pos
	if map != null and map.current_map != null and map.current_map is BaseMap:
		var base_map := map.current_map as BaseMap
		var center: Vector2 = base_map.get_map_center()
		var half: Vector2 = base_map.get_map_half_extents()
		var margin: float = 0.95
		var min_x: float = center.x - half.x * margin
		var max_x: float = center.x + half.x * margin
		var min_y: float = center.y - half.y * margin
		var max_y: float = center.y + half.y * margin
		desired = Vector2(clamp(desired.x, min_x, max_x), clamp(desired.y, min_y, max_y))

	# First attempt: clamp requested point directly.
	var closest: Vector2 = NavigationServer2D.map_get_closest_point(nav_map, desired)
	# Godot may return (0,0) when the nav query fails / map isn't ready yet.
	# Treat that as "invalid" unless the original point is actually near the origin.
	if closest == Vector2.ZERO and desired.distance_to(Vector2.ZERO) > 8.0:
		return desired

	var snap_delta: float = closest.distance_to(desired)
	if snap_delta <= nav_clamp_max_delta:
		return closest

	# If snap is too large, try clamping an intermediate point toward the target.
	# This avoids huge target jumps across holes/walls.
	var to_target: Vector2 = desired - global_position
	var dist_to_target: float = to_target.length()
	if dist_to_target < 1.0:
		return closest

	var step: float = min(nav_clamp_step, dist_to_target)
	var dir: Vector2 = to_target / max(dist_to_target, 0.001)
	for _i in range(max(nav_clamp_iterations, 1)):
		var candidate: Vector2 = global_position + dir * step
		var candidate_closest: Vector2 = NavigationServer2D.map_get_closest_point(nav_map, candidate)
		var cand_valid := not (candidate_closest == Vector2.ZERO and candidate.distance_to(Vector2.ZERO) > 8.0)
		if cand_valid and candidate_closest.distance_to(candidate) <= nav_clamp_max_delta:
			return candidate_closest
		step *= 0.5

	# Last resort: still return a nav point (better than off-mesh), even if the snap is large.
	return closest

func clamp_point_to_nav(pos: Vector2) -> Vector2:
	# Public helper so role scripts can clamp their targets early.
	return _clamp_point_to_nav(pos)

func _tangent_dir_from_collision(desired_vel: Vector2) -> Vector2:
	if get_slide_collision_count() == 0:
		return Vector2.ZERO
	var c := get_slide_collision(0)
	var n: Vector2 = c.get_normal()
	var t := Vector2(-n.y, n.x).normalized()
	if t.dot(desired_vel) < 0.0:
		t = -t
	return t

func _is_dir_blocked(dir: Vector2) -> bool:
	if dir.length() < 0.01:
		return false
	var from := global_position
	var to := from + dir.normalized() * avoid_probe
	return _ray_hits_wall(from, to)

func _pick_unblocked_dir(preferred: Vector2, delta: float) -> Vector2:
	if avoid_lock > 0.0 and avoid_dir != Vector2.ZERO and not _is_dir_blocked(avoid_dir):
		avoid_lock -= delta
		return avoid_dir

	# normal search...
	var base := preferred.normalized()
	if base == Vector2.ZERO:
		return Vector2.ZERO
	if not _is_dir_blocked(base):
		avoid_dir = Vector2.ZERO
		avoid_lock = 0.0
		return base

	var step := deg_to_rad(avoid_angle_step_deg)
	for i in range(1, avoid_steps + 1):
		var d1 := base.rotated(step * i)
		if not _is_dir_blocked(d1):
			avoid_dir = d1; avoid_lock = avoid_lock_time
			return d1
		var d2 := base.rotated(-step * i)
		if not _is_dir_blocked(d2):
			avoid_dir = d2; avoid_lock = avoid_lock_time
			return d2
	return Vector2.ZERO

#func move_towards(target_pos: Vector2, delta: float, speed_mult := 1.0, sep_dist := 60.0, sep_weight := 0.8) -> void:
	#if movement_locked:
		## Hard stop. No nav. No separation. No unstuck. 
		#move_dir = Vector2.ZERO
		#velocity = velocity.lerp(Vector2.ZERO, clamp(accel * delta, 0.0, 1.0))
		#move_and_slide()
		#return
#
	## --- KOTH OVERRIDE START ---
	#var final_target = target_pos
	#if koth_mode:
		#var dist_to_hill = global_position.distance_to(hill_location)
		#
		## If we are inside the hill, stop moving ("freeze") 
		## We use a small margin (0.9) to ensure we stay inside the scoring area
		#if dist_to_hill < hill_radius * 0.9:
			#move_dir = Vector2.ZERO
			## Rapidly decelerate to stand still and shoot
			#velocity = velocity.lerp(Vector2.ZERO, clamp(accel * delta * 2.0, 0.0, 1.0))
			#move_and_slide()
			#return 
		#else:
			## If outside, the hill center is our only priority
			#final_target = hill_location
	## --- KOTH OVERRIDE END ---
	## 1) Compute preferred seek direction (your old behavior)
	#var dir := get_path_dir(target_pos)
	#var sep := get_separation_dir(sep_dist)
	#if sep != Vector2.ZERO:
		#dir = (dir + sep * sep_weight).normalized()
#
	## 2) If currently in "unstuck", override direction for a short time
	#if _unstuck_time > 0.0:
		#_unstuck_time -= delta
		#if _unstuck_dir != Vector2.ZERO:
			#dir = _unstuck_dir
	#else:
		## 2.5) Only do "probe + steer away" when NOT using navmesh.
		## If navmesh is active, this probe can fight the nav-agent steering and cause oscillation/stuck.
		#var using_nav := navigation_agent != null and navigation_ready
		#if not using_nav:
			#if dir != Vector2.ZERO and _is_dir_blocked(dir):
				#var unblocked_dir = _pick_unblocked_dir(dir, delta)
				#if unblocked_dir != Vector2.ZERO:
					#dir = unblocked_dir
#
	#move_dir = dir
#
	## 3) Move
	#var desired_vel := dir * move_speed * speed_mult
	#velocity = velocity.lerp(desired_vel, clamp(accel * delta, 0.0, 1.0))
	#move_and_slide()
#
	## 4) Detect lack of progress
	#var progressed := global_position.distance_to(_last_pos)
	#_last_pos = global_position
#
	#var collided := get_slide_collision_count() > 0
	#var trying_to_move := desired_vel.length() > 1.0
#
	#if trying_to_move and (progressed < min_progress_px or collided):
		#_stuck_time += delta
	#else:
		#_stuck_time = 0.0
#
	## 5) Trigger "unstuck": pick a direction away from walls (biased by wall tangent if colliding)
	#if _stuck_time >= stuck_time_to_unstuck and _unstuck_time <= 0.0:
		#_stuck_time = 0.0
		#_unstuck_time = unstuck_duration
#
		#var base_dir: Vector2
		#if collided:
			## Use wall tangent to slide along the wall instead of into it
			#var c := get_slide_collision(0)
			#var n := c.get_normal()
			#var t := Vector2(-n.y, n.x).normalized()
			## Choose the tangent direction that's closer to our desired direction
			#if t.dot(dir) < 0.0:
				#t = -t
			## Add some randomness so agents don't all follow the same line
			#base_dir = t.rotated(randf_range(-0.4, 0.4))
		#else:
			## Not colliding but not making progress - try a direction perpendicular to current
			#base_dir = dir.rotated(PI/2 + randf_range(-0.5, 0.5))
			#if base_dir.length() < 0.1:
				#base_dir = Vector2.RIGHT.rotated(randf() * TAU)  # fallback to random
#
		## Make sure the unstuck direction is actually clear
		#_unstuck_dir = _pick_unblocked_dir(base_dir, delta)
		#if _unstuck_dir == Vector2.ZERO:
			## If we can't find a clear direction, use the base direction anyway
			#_unstuck_dir = base_dir.normalized()

func move_towards(target_pos: Vector2, delta: float, speed_mult := 1.0, sep_dist := 60.0, sep_weight := 0.8) -> void:
	if movement_locked:
		# Hard stop. No nav. No separation. No unstuck. 
		move_dir = Vector2.ZERO
		velocity = velocity.lerp(Vector2.ZERO, clamp(accel * delta, 0.0, 1.0))
		move_and_slide()
		return

	# --- KOTH OVERRIDE ---
	var final_target = target_pos
	if koth_mode:
		#if koth_mode and Engine.get_frames_drawn() % 60 == 0:
			#print(name, " is moving to hill_location: ", hill_location)
		var dist_to_hill = global_position.distance_to(hill_location)
		
		# If inside the hill, stop moving and exit early 
		if dist_to_hill < hill_radius * 0.5:
			move_dir = Vector2.ZERO
			velocity = velocity.lerp(Vector2.ZERO, clamp(accel * delta * 5.0, 0.0, 1.0))
			move_and_slide()
			return # This prevents them from moving around once inside
		else:
			final_target = hill_location
	# ---------------------

	# 1) Compute preferred seek direction
	var dir := get_path_dir(final_target)
	var sep := get_separation_dir(sep_dist)
	if sep != Vector2.ZERO:
		dir = (dir + sep * sep_weight).normalized()

	# 2) If currently in "unstuck", override direction for a short time
	if _unstuck_time > 0.0:
		_unstuck_time -= delta
		if _unstuck_dir != Vector2.ZERO:
			dir = _unstuck_dir
	else:
		var using_nav := navigation_agent != null and navigation_ready
		if not using_nav:
			if dir != Vector2.ZERO and _is_dir_blocked(dir):
				var unblocked_dir = _pick_unblocked_dir(dir, delta)
				if unblocked_dir != Vector2.ZERO:
					dir = unblocked_dir

	move_dir = dir

	# 3) Move
	var desired_vel := dir * move_speed * speed_mult
	velocity = velocity.lerp(desired_vel, clamp(accel * delta, 0.0, 1.0))
	move_and_slide()

	# 4) Detect lack of progress
	var progressed := global_position.distance_to(_last_pos)
	_last_pos = global_position

	var collided := get_slide_collision_count() > 0
	var trying_to_move := desired_vel.length() > 1.0

	if trying_to_move and (progressed < min_progress_px or collided):
		_stuck_time += delta
	else:
		_stuck_time = 0.0

	# 5) Trigger "unstuck" logic (implemented inline)
	if _stuck_time >= stuck_time_to_unstuck and _unstuck_time <= 0.0:
		_stuck_time = 0.0
		_unstuck_time = unstuck_duration

		var base_dir: Vector2
		if collided:
			var c := get_slide_collision(0)
			var n := c.get_normal()
			var t := Vector2(-n.y, n.x).normalized()
			if t.dot(dir) < 0.0:
				t = -t
			base_dir = t.rotated(randf_range(-0.4, 0.4))
		else:
			base_dir = dir.rotated(PI/2 + randf_range(-0.5, 0.5))
			if base_dir.length() < 0.1:
				base_dir = Vector2.RIGHT.rotated(randf() * TAU)

		_unstuck_dir = _pick_unblocked_dir(base_dir, delta)
		if _unstuck_dir == Vector2.ZERO:
			_unstuck_dir = base_dir.normalized()
func get_separation_dir(min_dist: float = 50.0) -> Vector2:
	var push: Vector2 = Vector2.ZERO

	# ne uităm la TOȚI agenții din scenă
	for node in get_tree().get_nodes_in_group("agents"):
		var other := node as Agent
		if other == null or other == self or not other.is_alive():
			continue
		# Only separate from teammates; separating from enemies makes agents "avoid" fights.
		if team != null and other.team != null and other.team != team:
			continue

		var diff: Vector2 = global_position - other.global_position
		var dist := diff.length()
		if dist <= 0.01:
			continue

		if dist < min_dist:
			# cu cât e mai aproape, cu atât împingem mai tare
			var strength := (min_dist - dist) / min_dist
			push += diff.normalized() * strength

	if push.length() == 0.0:
		return Vector2.ZERO

	return push.normalized()


func _load_role_logic():
	# Șterge AI-ul vechi dacă există
	if role_logic:
		role_logic.queue_free()
		role_logic = null
	
	var logic_node = null
	
	match role:
		Role.LEADER:
			logic_node = Leader.new()
		Role.ADVANCE:
			logic_node = Advance.new()
		Role.SUPPORT:
			logic_node = Support.new()
		Role.TANK:
			logic_node = Tank.new()
	
	if logic_node:
		add_child(logic_node)
		logic_node.agent = self
		role_logic = logic_node

		# Propagate Agent-level debug flag to role logic scripts that support it.
		# (Role nodes are created at runtime, so exported vars aren't set via editor.)
		if debug_ai:
			var props: Array = role_logic.get_property_list()
			for p in props:
				if not (p is Dictionary):
					continue
				# `get()` returns Variant; cast to String to avoid "Variant inference" parse errors.
				var n: String = str((p as Dictionary).get("name", ""))
				if n == "debug_leader" or n == "debug_advance" or n == "debug_tank" or n == "debug_support":
					role_logic.set(n, true)

		print("[Agent._load_role_logic] %s loaded %s successfully!" % [name, logic_node.get_class()])
	else:
		print("[Agent._load_role_logic] %s FAILED - no logic for role %s!" % [name, Role.keys()[role]])

func apply_team_skin(team_id: String, role_value: int) -> void:
	if not skin:
		return
	var tex = TEAM_ROLE_SKINS.get(team_id, {}).get(role_value, null)
	if tex:
		skin.visible = true
		skin.texture = tex

func is_alive() -> bool:
	return hp > 0

func take_damage(amount: int, from_agent) -> void:
	# Safety: prevent friendly fire (and self-damage).
	# Bullets pass `shooter` here, so this blocks team-kills even if they happen.
	if from_agent != null and from_agent is Agent:
		var src := from_agent as Agent
		if src == self:
			return
		if team != null and src.team != null and src.team == team:
			return
		
		# Turn around to face attacker
		var direction_to_attacker = (src.global_position - global_position).normalized()
		aim_dir = direction_to_attacker

	hp -= amount
	var stats := get_tree().current_scene.get_node_or_null("StatsManager") as StatsManager
	if stats != null:
		var attacker: Agent = null
		if is_instance_valid(from_agent) and from_agent is Agent:
			attacker = from_agent as Agent
		stats.record_damage(self, amount, attacker)
	
	# Cerere ajutor dacă HP critic
	if hp > 0 and hp < max_hp * 0.3:
		if has_node("AgentComms"):
			var agent_comms = get_node("AgentComms")
			# Verifică că AgentComms e complet inițializat
			if agent_comms and agent_comms.has_method("request_assist") and agent_comms.comms_manager:
				var urgency = 5 if hp < max_hp * 0.15 else 3
				agent_comms.request_assist(global_position, urgency)
				print("[Agent] %s cere ajutor! (HP: %d/%d, urgency: %d)" % [
					id, hp, max_hp, urgency
				])
	
	if hp <= 0:
		if team:
			team.remove_member(self)
		emit_signal("died", self, from_agent)
		queue_free()

func _has_friendly_in_line_of_fire(target: Agent) -> bool:
	# Returns true if a teammate is the first agent hit along the shot line.
	if target == null or team == null:
		return false
	if not has_node("Skin/Muzzle"):
		return false

	var from_pos: Vector2 = $Skin/Muzzle.global_position
	var to_pos: Vector2 = target.global_position
	var space := get_world_2d().direct_space_state
	var params := PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	# Use a broad mask so we definitely hit agents + map geometry.
	params.collision_mask = 0x7FFFFFFF
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.exclude = [get_rid()]

	var hit: Dictionary = space.intersect_ray(params)
	if hit.is_empty():
		return false

	var collider: Object = hit.get("collider")
	if collider == null or not (collider is Agent):
		return false

	var a := collider as Agent
	if a == target:
		return false
	return a.team != null and a.team == team


func _try_shoot() -> void:
	if not perception:
		return

	var enemies = perception.get_visible_enemies()
	if enemies.is_empty():
		# nu avem țintă, ne uităm în direcția de mers
		aim_dir = move_dir
		return

	# căutăm cel mai apropiat inamic cu linie de tragere liberă
	var best_target: Agent = null
	var best_dist := INF

	for e in enemies:
		var enemy := e as Agent
		if enemy == null:
			continue

		# Double-check FOV (should already be filtered, but be safe)
		if not is_in_fov(enemy.global_position):
			continue

		# NU tragem dacă avem perete între noi și el
		if not has_line_of_sight_to(enemy):
			continue

		var d := enemy.global_position.distance_to(global_position)
		if d < best_dist:
			best_dist = d
			best_target = enemy

	# dacă niciun inamic nu are LOS liber → nu tragem
	if best_target == null:
		aim_dir = move_dir
		return

	# Final safety check before shooting
	if not is_in_fov(best_target.global_position):
		aim_dir = move_dir
		return
	
	if not has_line_of_sight_to(best_target):
		aim_dir = move_dir
		return

	# Don't shoot if a teammate is between us and the target.
	var fire_dir: Vector2 = (best_target.global_position - global_position).normalized()
	if _has_friendly_in_line_of_fire(best_target):
		aim_dir = fire_dir
		if debug_shooting and randf() < 0.05:
			print("[SHOOT] %s: HOLD (friendly in line) -> %s" % [name, best_target.name])
		return

	# aici avem o țintă cu LOS liber și în FOV -> tragem
	fire_cooldown = 1.0 / fire_rate

	# Replay recording: log the shot event (for visual playback).
	if get_tree().root.has_node("Replay"):
		var replay := get_tree().root.get_node("Replay")
		if replay != null and replay.has_method("record_shot"):
			var muzzle_pos: Vector2 = $Skin/Muzzle.global_position if has_node("Skin/Muzzle") else global_position
			replay.call("record_shot", str(id if id != "" else name), muzzle_pos, fire_dir)

	var bullet_scene = preload("res://scenes/bullets/Bullet.tscn")
	var bullet = bullet_scene.instantiate() as Bullet

	bullet.direction = fire_dir
	bullet.shooter = self
	bullet.damage = damage_per_shot

	aim_dir = fire_dir

	bullet.global_position = $Skin/Muzzle.global_position
	get_tree().current_scene.add_child(bullet)
	if debug_shooting and randf() < 0.05:
		print("[SHOOT] %s -> %s | dir=%s" % [name, best_target.name, str(fire_dir)])

	
func _update_poses(delta: float) -> void:
	if aim_dir.length() <= 0.1:
		return

	# agentul tău e desenat cu fața în jos => compensăm cu -PI/2
	var target_angle = aim_dir.angle()
	
	skin.rotation = lerp_angle(
		skin.rotation,
		target_angle,
		body_turn_speed * delta
	)
	

func _physics_process(delta: float) -> void:
	_nav_retarget_timer = max(_nav_retarget_timer - delta, 0.0)
	if debug_draw_fov:
		queue_redraw()

	# (your movement/roam/role logic can run before this)
	if perception.get_visible_enemies().is_empty():
		aim_dir = move_dir.normalized()

	_update_poses(delta)

	fire_cooldown -= delta
	if fire_cooldown <= 0.0:
		_try_shoot()


func set_role(new_role: Role):
	# Update role and (re)load the matching behavior node.
	# NOTE: roles are assigned by Team after the Agent is instanced, so we must
	# rebuild the AI here (otherwise every agent keeps the default role logic).
	if role == new_role and role_logic != null:
		return
	role = new_role
	_load_role_logic()

## === CALLBACKS PENTRU MESAJE === ##

func on_teammate_status(message: Message) -> void:
	# Procesare status update
	if role_logic and role_logic.has_method("on_teammate_status"):
		role_logic.on_teammate_status(message)

func on_teammate_move(message: Message) -> void:
	if role_logic and role_logic.has_method("on_teammate_move"):
		role_logic.on_teammate_move(message)

func on_assist_request(message: Message) -> void:
	# Support răspunde prioritar
	if role == Role.SUPPORT:
		print("[Agent] %s primit ASSIST de la %s (urgency: %d)" % [
			id, message.sender, message.content.urgency
		])
	
	if role_logic and role_logic.has_method("on_assist_request"):
		role_logic.on_assist_request(message)

func on_focus_target(message: Message) -> void:
	if role_logic and role_logic.has_method("on_focus_target"):
		role_logic.on_focus_target(message)

func on_teammate_retreat(message: Message) -> void:
	if role_logic and role_logic.has_method("on_teammate_retreat"):
		role_logic.on_teammate_retreat(message)

func on_objective_assigned(message: Message) -> void:
	if role_logic and role_logic.has_method("on_objective_assigned"):
		role_logic.on_objective_assigned(message)

## Wrapper pentru backwards compatibility
func receive_message(message: Message) -> void:
	# Delegare la AgentComms
	if has_node("AgentComms"):
		get_node("AgentComms").receive_message(message)
	
func _setup_navigation() -> void:
	# Create NavigationAgent2D programmatically
	navigation_agent = NavigationAgent2D.new()
	navigation_agent.name = "NavigationAgent2D"
	add_child(navigation_agent)
	
	# Configure navigation agent
	# Agent collision radius is ~21 pixels (130 * 0.16 scale), so use 25 for safety margin
	navigation_agent.path_desired_distance = 50.0   # distance to waypoint before getting next one
	navigation_agent.target_desired_distance = 35.0 # distance to final target before considering it reached
	navigation_agent.radius = 25.0                   # agent radius for pathfinding (slightly larger than actual for safety)
	navigation_agent.max_speed = move_speed
	navigation_agent.path_max_distance = 3000.0
	
	if debug_pathfinding:
		print("[PATHFINDING] %s: Setting up navigation agent" % name)
	
	# Wait for map to be ready
	if map and map.current_map:
		var base_map = map.current_map as BaseMap
		if base_map:
			# Wait for navigation to be built
			if base_map.nav_region:
				if debug_pathfinding:
					print("[PATHFINDING] %s: Navigation region found, connecting..." % name)
				_update_navigation_map()
			else:
				if debug_pathfinding:
					print("[PATHFINDING] %s: Waiting for navigation region..." % name)
				# Wait for navigation_ready signal
				if base_map.is_connected("navigation_ready", Callable(self, "_on_navigation_ready")):
					base_map.disconnect("navigation_ready", Callable(self, "_on_navigation_ready"))
				base_map.navigation_ready.connect(_on_navigation_ready)
				# Also try to update after a delay
				await get_tree().create_timer(0.5).timeout
				_update_navigation_map()
	
	# Wait for navigation to initialize
	await get_tree().physics_frame
	await get_tree().physics_frame
	navigation_ready = true
	var nav_map = navigation_agent.get_navigation_map() if navigation_agent else null
	if debug_pathfinding:
		print("[PATHFINDING] %s: Navigation agent ready! (nav_map: %s)" % [
			name, "YES" if nav_map else "NO"
		])

func _on_navigation_ready() -> void:
	if debug_pathfinding:
		print("[PATHFINDING] %s: Received navigation_ready signal" % name)
	_update_navigation_map()

func _update_navigation_map() -> void:
	if not navigation_agent:
		return

	# Find the navigation region from the map
	if map and map.current_map:
		var base_map = map.current_map as BaseMap
		if base_map and base_map.nav_region:
			navigation_agent.navigation_map = base_map.nav_region.get_navigation_map()
			var nav_map = navigation_agent.get_navigation_map()
			if debug_pathfinding:
				print("[PATHFINDING] %s: Connected to navigation map! (map valid: %s)" % [
					name, "YES" if nav_map else "NO"
				])
			return

	# Fallback: search for NavigationRegion2D in scene tree
	var nav_region = get_tree().get_first_node_in_group("navigation") as NavigationRegion2D
	if nav_region:
		navigation_agent.navigation_map = nav_region.get_navigation_map()
		var nav_map = navigation_agent.get_navigation_map()
		if debug_pathfinding:
			print("[PATHFINDING] %s: Connected to navigation map via fallback search (map valid: %s)" % [
				name, "YES" if nav_map else "NO"
			])
	else:
		if debug_pathfinding:
			print("[PATHFINDING] %s: WARNING - No navigation map found!" % name)

func get_path_dir(target_pos: Vector2) -> Vector2:
	# Use NavigationAgent2D if available and ready
	if navigation_agent and navigation_ready:
		# Clamp the requested target onto the navmesh.
		# We do it with a "max snap delta" + step fallback to avoid huge target jumps across holes/walls.
		var desired_target: Vector2 = target_pos
		var clamped_target: Vector2 = _clamp_point_to_nav(desired_target)
		target_pos = clamped_target
		if debug_pathfinding and clamped_target.distance_to(desired_target) > 4.0 and randf() < 0.01:
			print("[PATHFINDING] %s: Target clamped (%.0f, %.0f) -> (%.0f, %.0f)" % [
				name, desired_target.x, desired_target.y, clamped_target.x, clamped_target.y
			])

		# Retarget smoothing: don't change the nav target every frame for tiny variations.
		var should_retarget := (not _nav_target_valid) \
			or clamped_target.distance_to(_nav_target) >= nav_retarget_distance \
			or _nav_retarget_timer <= 0.0
		if should_retarget:
			_nav_target = clamped_target
			_nav_target_valid = true
			_nav_retarget_timer = nav_retarget_interval
			# Set target position (this triggers path calculation)
			navigation_agent.target_position = clamped_target
		
		# Check if we're at the target or very close
		if navigation_agent.is_navigation_finished():
			# We're at the target or very close
			var dir := target_pos - global_position
			var dist = dir.length()
			if dist < 10.0:
				return Vector2.ZERO
			return dir.normalized()
		
		# Get the next position on the path
		var next_pos: Vector2 = navigation_agent.get_next_path_position()
		if next_pos != Vector2.ZERO and next_pos != global_position:
			var dir: Vector2 = next_pos - global_position
			if dir.length() < 1.0:
				return Vector2.ZERO

			# If the straight segment to the next waypoint is blocked by map collisions,
			# it usually means the navmesh is baked too close to obstacles (no clearance).
			# In that case, steer along the obstacle tangent instead of pushing into it.
			var hit_wp: Dictionary = _ray_first_non_agent_hit(global_position, next_pos)
			if not hit_wp.is_empty():
				var n: Vector2 = hit_wp.get("normal", Vector2.ZERO)
				if n.length() > 0.001:
					var t: Vector2 = Vector2(-n.y, n.x).normalized()
					if t.dot(dir) < 0.0:
						t = -t
					return t
			
			# Check if the waypoint itself is blocked (too close to a wall)
			# If so, the navigation path might be giving us a bad waypoint
			# We'll still try to move toward it, but the wall avoidance in move_towards will handle it
			
			# Debug: Print pathfinding info (only occasionally to avoid spam)
			if debug_pathfinding and randf() < 0.01:  # Print 1% of the time
				var dist_to_waypoint = global_position.distance_to(next_pos)
				var dist_to_target = global_position.distance_to(target_pos)
				var is_reachable = navigation_agent.is_target_reachable()
				var hit: Dictionary = _ray_first_non_agent_hit(global_position, next_pos)
				var waypoint_blocked := not hit.is_empty()
				var blocker := ""
				if waypoint_blocked:
					var collider: Object = hit.get("collider")
					if collider != null:
						if collider is Node:
							blocker = (collider as Node).name
						else:
							blocker = str(collider)
				print("[PATHFINDING] %s: Using NAV path | Waypoint: (%.0f, %.0f) | Target: (%.0f, %.0f) | Dist to waypoint: %.1f, Dist to target: %.1f | Reachable: %s | Waypoint blocked: %s" % [
					name, next_pos.x, next_pos.y, target_pos.x, target_pos.y,
					dist_to_waypoint, dist_to_target, "YES" if is_reachable else "NO",
					("YES (%s)" % blocker) if waypoint_blocked else "NO"
				])
			
			return dir.normalized()
		else:
			# No waypoint available - navigation might not have a path
			if debug_pathfinding and randf() < 0.01:  # Print 1% of the time
				var is_reachable = navigation_agent.is_target_reachable()
				var dist_to_target = global_position.distance_to(target_pos)
				print("[PATHFINDING] %s: NAV active but no waypoint | Target: (%.0f, %.0f) | Dist: %.1f | Reachable: %s | Finished: %s" % [
					name, target_pos.x, target_pos.y, dist_to_target,
					"YES" if is_reachable else "NO",
					"YES" if navigation_agent.is_navigation_finished() else "NO"
				])
	
	# Fallback to direct path if navigation not available
	if debug_pathfinding and randf() < 0.01:  # Print 1% of the time
		var has_nav_map = false
		if navigation_agent:
			var nav_map = navigation_agent.get_navigation_map()
			has_nav_map = nav_map != null
		var nav_status = "agent=%s, ready=%s, map=%s" % [
			"YES" if navigation_agent else "NO",
			"YES" if navigation_ready else "NO",
			"YES" if has_nav_map else "NO"
		]
		var dist_to_target = global_position.distance_to(target_pos)
		print("[PATHFINDING] %s: FALLBACK - Using direct path (%s) | Target: (%.0f, %.0f) | Dist: %.1f" % [
			name, nav_status, target_pos.x, target_pos.y, dist_to_target
		])
	
	var dir := target_pos - global_position
	if dir.length() < 1.0:
		return Vector2.ZERO
	return dir.normalized()

func has_line_of_sight_to(target: Agent) -> bool:
	if target == null:
		return false

	var from := global_position
	# Aim slightly at the center of the target to avoid skimming edges
	var to := target.global_position

	# Exclude the target from the raycast; self is excluded in helper.
	return not _ray_hits_wall(from, to, [target.get_rid()])

func is_in_fov(target_pos: Vector2) -> bool:
	# Check if target is within field of view
	# Use the agent's facing direction (skin rotation) as the FOV center
	var facing_dir: Vector2
	
	# Try to use aim direction first (where agent is aiming)
	if aim_dir.length() > 0.1:
		facing_dir = aim_dir.normalized()
	# Fall back to movement direction
	elif move_dir.length() > 0.1:
		facing_dir = move_dir.normalized()
	# Fall back to skin rotation (visual facing direction)
	elif skin:
		var angle = skin.rotation + PI/2  # Compensate for sprite facing down
		facing_dir = Vector2(cos(angle), sin(angle))
	else:
		# No direction available, allow it (edge case at spawn)
		return true
	
	var to_target = (target_pos - global_position).normalized()
	var dot = facing_dir.dot(to_target)
	var fov_cos = cos(deg_to_rad(fov_angle_deg / 2.0))
	
	# dot product >= cos(angle/2) means within FOV
	# dot of 1.0 = directly ahead, 0.0 = 90 degrees to side
	return dot >= fov_cos

func _get_facing_dir_for_fov() -> Vector2:
	# Same priority order as `is_in_fov`: aim_dir > move_dir > skin rotation.
	if aim_dir.length() > 0.1:
		return aim_dir.normalized()
	if move_dir.length() > 0.1:
		return move_dir.normalized()
	if skin:
		var angle = skin.rotation + PI / 2.0  # compensate for sprite facing down
		return Vector2(cos(angle), sin(angle))
	return Vector2.RIGHT

func _get_debug_fov_colors() -> Array[Color]:
	# Returns [fill, edge]
	if debug_fov_use_team_colors and team != null and team.id != null:
		var tid := int(team.id)
		if tid == 0:
			return [debug_fov_fill_color_team0, debug_fov_edge_color_team0]
		if tid == 1:
			return [debug_fov_fill_color_team1, debug_fov_edge_color_team1]
	return [debug_fov_fill_color, debug_fov_edge_color]

func _draw() -> void:
	if not debug_draw_fov:
		return

	var facing: Vector2 = _get_facing_dir_for_fov()
	if facing.length() < 0.01:
		return

	var cols := _get_debug_fov_colors()
	var fill_col: Color = cols[0]
	var edge_col: Color = cols[1]

	var radius: float = max(debug_fov_radius if debug_fov_radius > 0.0 else los_range, 1.0)
	var half: float = deg_to_rad(fov_angle_deg * 0.5)
	var center_angle: float = facing.angle()
	var seg: int = max(debug_fov_segments, 6)

	# Build a filled cone polygon (origin + arc points).
	var cone: PackedVector2Array = PackedVector2Array()
	cone.append(Vector2.ZERO)
	for i in range(seg + 1):
		var t: float = float(i) / float(seg)
		var a: float = center_angle - half + t * (half * 2.0)
		var dir: Vector2 = Vector2(cos(a), sin(a))
		if debug_fov_clip_to_walls:
			var from_g: Vector2 = global_position
			var to_g: Vector2 = from_g + dir * radius
			var hit: Dictionary = _ray_first_non_agent_hit(from_g, to_g)
			if not hit.is_empty():
				var hp: Vector2 = hit.get("position", to_g)
				cone.append(to_local(hp))
			else:
				cone.append(to_local(to_g))
		else:
			cone.append(dir * radius)

	draw_colored_polygon(cone, fill_col)

	# Edge rays + arc outline.
	var left: Vector2 = cone[1] if cone.size() > 1 else Vector2.ZERO
	var right: Vector2 = cone[cone.size() - 1] if cone.size() > 1 else Vector2.ZERO
	draw_line(Vector2.ZERO, left, edge_col, debug_fov_line_width, true)
	draw_line(Vector2.ZERO, right, edge_col, debug_fov_line_width, true)

	var arc: PackedVector2Array = PackedVector2Array()
	for i in range(1, cone.size()):
		arc.append(cone[i])
	draw_polyline(arc, edge_col, debug_fov_line_width, true)
