extends Node
class_name KothBehavior

## KOTH-specific AI controller
## Takes full control of agent movement/combat decisions in KOTH mode

var agent: Agent = null
var hill_location: Vector2 = Vector2.ZERO
var hill_radius: float = 200.0

## Add debug output
@export var debug_koth: bool = true

## Role-based behavior weights
var role_weights := {
	Agent.Role.LEADER: {
		"hold_point": 0.5,
		"attack": 0.5,
		"optimal_distance": 0.35,
		"combat_range": 400.0,
		"angle_offset": 0.0,
		"max_chase_distance": 1.3  # How far from hill center to chase (ratio of radius)
	},
	Agent.Role.ADVANCE: {
		"hold_point": 0.2,
		"attack": 0.8,
		"optimal_distance": 1.1,  # Patrol outside the hill perimeter
		"combat_range": 700.0,    # Much larger engagement range
		"angle_offset": PI / 2,
		"max_chase_distance": 2.0  # Advance can chase further
	},
	Agent.Role.TANK: {
		"hold_point": 0.9,
		"attack": 0.1,
		"optimal_distance": 0.15,
		"combat_range": 180.0,
		"angle_offset": PI,
		"max_chase_distance": 0.8  # Tank stays very close to center
	},
	Agent.Role.SUPPORT: {
		"hold_point": 0.7,
		"attack": 0.3,
		"optimal_distance": 0.55,
		"combat_range": 320.0,
		"angle_offset": 3 * PI / 2,
		"max_chase_distance": 1.0  # Support stays on the hill
	}
}

## Assigned position
var assigned_angle: float = 0.0
var base_angle: float = 0.0

## Combat
var current_target: Agent = null
var combat_timer: float = 0.0
const COMBAT_MEMORY: float = 3.0

## State
var is_on_hill: bool = false
var target_position: Vector2 = Vector2.ZERO
var current_state: String = "INIT"
var is_tethered: bool = false  # True when agent should return to hill

## Update timing
var update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.1

func _ready() -> void:
	set_physics_process(true)

func setup(_agent: Agent, _hill_location: Vector2, _hill_radius: float) -> void:
	agent = _agent
	hill_location = _hill_location
	hill_radius = _hill_radius
	
	# Get role settings for angle offset
	var weights = role_weights.get(agent.role, role_weights[Agent.Role.LEADER])
	
	# Assign unique angle: base offset from role + variation based on instance
	var role_offset: float = weights.get("angle_offset", 0.0)
	var instance_variation: float = fmod(float(agent.get_instance_id()) * 0.618, PI / 4) - PI / 8
	
	# Also offset based on team to prevent both teams having same positions
	var team_offset: float = 0.0
	if agent.team:
		team_offset = agent.team.get_team_id() * PI / 3
	
	base_angle = role_offset + instance_variation + team_offset
	assigned_angle = base_angle
	
	if debug_koth:
		var role_name = Agent.Role.keys()[agent.role]
		print("[KOTH] %s (%s) - Hold:%.1f Attack:%.1f Range:%.0f MaxChase:%.0f%%" % [
			agent.name, role_name,
			weights.get("hold_point", 0.5),
			weights.get("attack", 0.5),
			weights.get("combat_range", 300.0),
			weights.get("max_chase_distance", 1.0) * 100
		])

func _physics_process(delta: float) -> void:
	if not agent or not agent.is_alive():
		return
	
	update_timer -= delta
	combat_timer = max(combat_timer - delta, 0.0)
	
	if update_timer <= 0:
		update_timer = UPDATE_INTERVAL
		_update_behavior()
	
	_execute_movement(delta)

func _update_behavior() -> void:
	var dist_to_hill = agent.global_position.distance_to(hill_location)
	is_on_hill = dist_to_hill < hill_radius * 1.2
	
	# Get role settings
	var weights = role_weights.get(agent.role, role_weights[Agent.Role.LEADER])
	var attack_weight: float = weights.get("attack", 0.5)
	var combat_range: float = weights.get("combat_range", 300.0)
	var optimal_dist_ratio: float = weights.get("optimal_distance", 0.5)
	var max_chase_dist: float = weights.get("max_chase_distance", 1.0) * hill_radius
	
	# TETHER CHECK: If too far from hill, MUST return (except Advance has more leeway)
	if dist_to_hill > max_chase_dist:
		is_tethered = true
		current_target = null
		combat_timer = 0.0
		current_state = "RETURN_TO_HILL"
		_set_hold_position(optimal_dist_ratio)
		
		if debug_koth and randf() < 0.01:
			print("[KOTH] %s TETHERED - returning to hill (dist:%.0f max:%.0f)" % [
				agent.name, dist_to_hill, max_chase_dist
			])
		return
	else:
		is_tethered = false
	
	# Get visible enemies
	var visible_enemies: Array = []
	if agent.perception:
		visible_enemies = agent.perception.get_visible_enemies()
	
	# PRIORITY 1: Check for enemies
	if visible_enemies.size() > 0:
		var best_enemy: Agent = null
		var best_score: float = -INF
		
		for e in visible_enemies:
			var enemy := e as Agent
			if not enemy or not is_instance_valid(enemy) or not enemy.is_alive():
				continue
			
			var enemy_dist = agent.global_position.distance_to(enemy.global_position)
			var enemy_dist_to_hill = enemy.global_position.distance_to(hill_location)
			var enemy_on_hill = enemy_dist_to_hill < hill_radius * 1.3
			
			# Score this enemy
			var score: float = 0.0
			
			# Enemies ON the hill get massive priority
			if enemy_on_hill:
				score += 1000.0
			
			# Closer enemies score higher
			score += 500.0 * (1.0 - min(enemy_dist / 600.0, 1.0))
			
			# Within combat range gets bonus
			if enemy_dist < combat_range:
				score += 200.0
			
			if score > best_score:
				best_score = score
				best_enemy = enemy
		
		if best_enemy:
			var enemy_dist = agent.global_position.distance_to(best_enemy.global_position)
			var enemy_dist_to_hill = best_enemy.global_position.distance_to(hill_location)
			var enemy_on_hill = enemy_dist_to_hill < hill_radius * 1.3
			
			# ALWAYS attack enemies on the hill
			if enemy_on_hill:
				current_target = best_enemy
				combat_timer = COMBAT_MEMORY
				current_state = "ATTACK_ON_HILL"
				_set_combat_position(best_enemy)
				
				if debug_koth and randf() < 0.02:
					print("[KOTH] %s ATTACKING %s (enemy ON hill)" % [agent.name, best_enemy.name])
				return
			
			# Attack enemies within combat range based on attack weight
			if enemy_dist < combat_range:
				# Deterministic engagement: high attack weight = always engage
				# attack_weight 0.8 (Advance) -> engage threshold 200px
				# attack_weight 0.1 (Tank) -> engage threshold 900px (basically never)
				var engage_distance_threshold = combat_range * (1.0 - attack_weight)
				
				# HIGH ATTACK weight (>0.5) means ALWAYS engage within combat range
				# LOW ATTACK weight means only engage if very very close
				if attack_weight >= 0.5 or enemy_dist < engage_distance_threshold:
					current_target = best_enemy
					combat_timer = COMBAT_MEMORY
					current_state = "ATTACK_CHASE"
					_set_combat_position(best_enemy)
					
					if debug_koth and randf() < 0.02:
						print("[KOTH] %s CHASING %s (dist:%.0f range:%.0f attack_weight:%.1f)" % [
							agent.name, best_enemy.name, enemy_dist, combat_range, attack_weight
						])
					return
	
	# Keep pursuit if we have combat memory
	if combat_timer > 0 and current_target and is_instance_valid(current_target) and current_target.is_alive():
		current_state = "PURSUING"
		_set_combat_position(current_target)
		return
	
	# Clear stale target
	current_target = null
	
	# PRIORITY 2: Hold position on hill
	current_state = "HOLD_POSITION"
	_set_hold_position(optimal_dist_ratio)

func _set_combat_position(enemy: Agent) -> void:
	var to_enemy = enemy.global_position - agent.global_position
	var dist = to_enemy.length()
	var dir = to_enemy.normalized() if dist > 1.0 else Vector2.RIGHT
	
	# Get max chase distance for this role
	var weights = role_weights.get(agent.role, role_weights[Agent.Role.LEADER])
	var max_chase_dist: float = weights.get("max_chase_distance", 1.0) * hill_radius
	
	# Combat distance based on role
	var desired_dist: float
	match agent.role:
		Agent.Role.TANK:
			desired_dist = 100.0  # Tank gets very close
		Agent.Role.ADVANCE:
			desired_dist = 140.0  # Advance medium-close
		Agent.Role.SUPPORT:
			desired_dist = 200.0  # Support stays back
		_:
			desired_dist = 160.0  # Leader medium
	
	var has_los = agent.has_line_of_sight_to(enemy)
	
	if not has_los or dist > desired_dist * 1.4:
		# Close in
		target_position = enemy.global_position - dir * desired_dist * 0.7
	elif dist < desired_dist * 0.5:
		# Too close, back off toward hill
		var back_dir = (hill_location - agent.global_position).normalized()
		target_position = agent.global_position + back_dir * 60.0
	else:
		# Good range - strafe but stay near hill
		var right = Vector2(-dir.y, dir.x)
		var strafe_dir = 1.0 if fmod(agent.get_instance_id(), 2) == 0 else -1.0
		var strafe_phase = sin(Time.get_ticks_msec() * 0.003 + float(agent.get_instance_id()))
		target_position = enemy.global_position - dir * desired_dist + right * strafe_dir * strafe_phase * 80.0
	
	# HILL TETHER: Clamp target position to stay within max chase distance of hill
	var target_dist_to_hill = target_position.distance_to(hill_location)
	if target_dist_to_hill > max_chase_dist:
		var to_target = target_position - hill_location
		target_position = hill_location + to_target.normalized() * max_chase_dist

func _set_hold_position(optimal_dist_ratio: float) -> void:
	# Calculate optimal position based on role
	var optimal_dist = hill_radius * optimal_dist_ratio
	
	# Slowly rotate patrol angle
	assigned_angle = base_angle + Time.get_ticks_msec() * 0.0002
	
	var offset = Vector2(cos(assigned_angle), sin(assigned_angle)) * optimal_dist
	target_position = hill_location + offset

func _execute_movement(delta: float) -> void:
	if target_position == Vector2.ZERO:
		target_position = hill_location
	
	# Clamp to navmesh
	target_position = agent.clamp_point_to_nav(target_position)
	
	# Movement parameters - MUCH higher separation to prevent clustering
	var speed_mult: float
	var sep_dist: float
	var sep_weight: float
	
	match current_state:
		"ATTACK_ON_HILL", "ATTACK_CHASE", "PURSUING":
			speed_mult = 1.2
			sep_dist = 40.0  # Less separation when chasing
			sep_weight = 0.2
		"HOLD_POSITION":
			if is_on_hill:
				speed_mult = 0.7
				sep_dist = 120.0  # HIGH separation on hill
				sep_weight = 1.5  # Strong push apart
			else:
				speed_mult = 1.1
				sep_dist = 80.0
				sep_weight = 0.8
		_:
			speed_mult = 1.0
			sep_dist = 80.0
			sep_weight = 0.8
	
	agent.move_towards(target_position, delta, speed_mult, sep_dist, sep_weight)

## Public API
func get_koth_target() -> Vector2:
	return target_position

func is_in_combat() -> bool:
	return current_target != null and is_instance_valid(current_target)

func is_holding_hill() -> bool:
	return is_on_hill and not is_in_combat()

func get_hold_weight() -> float:
	var weights = role_weights.get(agent.role, {"hold_point": 0.5})
	return weights.get("hold_point", 0.5)

func get_attack_weight() -> float:
	var weights = role_weights.get(agent.role, {"attack": 0.5})
	return weights.get("attack", 0.5)

func should_hold_point() -> bool:
	return current_state == "HOLD_POSITION"

func should_attack() -> bool:
	return is_in_combat()

func get_state_name() -> String:
	return current_state
