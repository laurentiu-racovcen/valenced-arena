extends Node
class_name CtfBehavior

# Preload classes
const FlagClass = preload("res://scripts/modes/Flag.gd")

## CTF-specific AI decision module
## This is attached to agents when CTF mode is active

## CTF States
enum CtfState {
	ATTACK_FLAG,      # Go get the enemy flag
	ESCORT_CARRIER,   # Protect our flag carrier
	DEFEND_BASE,      # Defend our flag at base
	CHASE_CARRIER,    # Chase enemy flag carrier
	RETURN_FLAG,      # Return our dropped flag
	DELIVER_FLAG      # I have the flag, get to base
}

## Current CTF state
var current_state: CtfState = CtfState.ATTACK_FLAG

## Reference to the agent this behavior is attached to
var agent: Agent = null

## Reference to the CTF mode
var ctf_mode = null

## State timers
var state_update_timer: float = 0.0
const STATE_UPDATE_INTERVAL: float = 0.5

## Role-based behavior weights
var role_weights := {
	Agent.Role.LEADER: {
		"attack": 0.6,
		"defend": 0.3,
		"escort": 0.5
	},
	Agent.Role.ADVANCE: {
		"attack": 0.8,
		"defend": 0.1,
		"escort": 0.7
	},
	Agent.Role.TANK: {
		"attack": 0.3,
		"defend": 0.7,
		"escort": 0.5
	},
	Agent.Role.SUPPORT: {
		"attack": 0.2,
		"defend": 0.5,
		"escort": 0.9
	}
}

## Persistent role assignments (decided once on setup, not every frame)
var assigned_role_attack: bool = false
var assigned_role_escort: bool = false
var assigned_role_defend: bool = false
var role_assigned: bool = false

func _ready() -> void:
	set_physics_process(true)

func setup(_agent: Agent, _ctf_mode) -> void:
	agent = _agent
	ctf_mode = _ctf_mode
	
	# Assign persistent roles once based on agent role
	# Only TANK defends, everyone else attacks
	if not role_assigned and agent:
		assigned_role_attack = agent.role != Agent.Role.TANK  # Everyone except Tank attacks
		assigned_role_escort = agent.role == Agent.Role.SUPPORT  # Support escorts
		assigned_role_defend = agent.role == Agent.Role.TANK  # Only Tank defends
		role_assigned = true

func _physics_process(delta: float) -> void:
	if not agent or not agent.is_alive() or not ctf_mode:
		return
	
	state_update_timer -= delta
	if state_update_timer <= 0:
		state_update_timer = STATE_UPDATE_INTERVAL
		_update_state()

func _update_state() -> void:
	var team_id = agent.team.get_team_id() if agent.team else 0
	var our_flag = ctf_mode.get_flag(team_id)
	var enemy_flag = ctf_mode.get_enemy_flag(team_id)
	
	if not our_flag or not enemy_flag:
		return
	
	# Priority 1: I have the flag - deliver it!
	if enemy_flag.is_carried_by(agent):
		current_state = CtfState.DELIVER_FLAG
		return
	
	# Priority 2: Our flag is being carried - chase!
	if our_flag.state == FlagClass.State.CARRIED:
		if _should_chase(our_flag.carrier):
			current_state = CtfState.CHASE_CARRIER
			return
	
	# Priority 3: Our flag is dropped - return it!
	if our_flag.state == FlagClass.State.DROPPED:
		if _should_return_flag():
			current_state = CtfState.RETURN_FLAG
			return
	
	# Priority 4: Enemy flag is being carried by teammate - escort!
	if enemy_flag.state == FlagClass.State.CARRIED:
		var carrier = enemy_flag.carrier
		if carrier and carrier.team and carrier.team.get_team_id() == team_id:
			if _should_escort():
				current_state = CtfState.ESCORT_CARRIER
				return
	
	# Priority 5: Decide between attack and defend based on role
	if _should_defend():
		current_state = CtfState.DEFEND_BASE
	else:
		current_state = CtfState.ATTACK_FLAG

func _should_chase(carrier: Agent) -> bool:
	if not carrier or not is_instance_valid(carrier):
		return false
	
	# Distance check
	var dist = agent.global_position.distance_to(carrier.global_position)
	
	# Advance and Leader are more likely to chase
	var weights = role_weights.get(agent.role, {"attack": 0.5})
	var chase_chance = weights.get("attack", 0.5)
	
	# Everyone chases if close enough
	if dist < 400:
		return true
	
	return randf() < chase_chance

func _should_return_flag() -> bool:
	var team_id = agent.team.get_team_id() if agent.team else 0
	var our_flag = ctf_mode.get_flag(team_id)
	
	if not our_flag:
		return false
	
	var dist = agent.global_position.distance_to(our_flag.global_position)
	
	# Tank and Support prioritize returning
	var weights = role_weights.get(agent.role, {"defend": 0.5})
	var return_chance = weights.get("defend", 0.5)
	
	# If close, definitely return
	if dist < 300:
		return true
	
	return randf() < return_chance

func _should_escort() -> bool:
	return assigned_role_escort

func _should_defend() -> bool:
	return assigned_role_defend

## Get the target position based on current CTF state
func get_ctf_target() -> Vector2:
	if not agent or not ctf_mode:
		return agent.global_position if agent else Vector2.ZERO
	
	var team_id = agent.team.get_team_id() if agent.team else 0
	var our_flag = ctf_mode.get_flag(team_id)
	var enemy_flag = ctf_mode.get_enemy_flag(team_id)
	
	match current_state:
		CtfState.DELIVER_FLAG:
			# Go to our base to capture
			if our_flag:
				return our_flag.base_position
		
		CtfState.ATTACK_FLAG:
			# Go to enemy flag
			if enemy_flag:
				return enemy_flag.global_position
		
		CtfState.CHASE_CARRIER:
			# Chase the enemy carrying our flag
			if our_flag and our_flag.carrier:
				return our_flag.carrier.global_position
		
		CtfState.RETURN_FLAG:
			# Go to our dropped flag
			if our_flag:
				return our_flag.global_position
		
		CtfState.ESCORT_CARRIER:
			# Follow our teammate with the enemy flag
			if enemy_flag and enemy_flag.carrier:
				var carrier = enemy_flag.carrier
				# Stay slightly behind/beside the carrier
				var to_base = (our_flag.base_position - carrier.global_position).normalized()
				return carrier.global_position - to_base * 100
		
		CtfState.DEFEND_BASE:
			# Stay near our flag
			if our_flag:
				# Patrol around the flag
				var angle = Time.get_ticks_msec() * 0.001 + agent.get_instance_id()
				var offset = Vector2(cos(angle), sin(angle)) * 150
				return our_flag.base_position + offset
	
	return agent.global_position

## Check if we should override normal combat behavior for CTF objective
func should_prioritize_objective() -> bool:
	match current_state:
		CtfState.DELIVER_FLAG:
			# ALWAYS prioritize delivery - never stop to fight when carrying flag!
			return true
		CtfState.ATTACK_FLAG:
			# Prioritize attacking the flag
			return true
		CtfState.CHASE_CARRIER:
			# Prioritize if close to carrier
			var team_id = agent.team.get_team_id() if agent.team else 0
			var our_flag = ctf_mode.get_flag(team_id)
			if our_flag and our_flag.carrier:
				var dist = agent.global_position.distance_to(our_flag.carrier.global_position)
				return dist < 500
		CtfState.RETURN_FLAG:
			# Prioritize if close to flag
			var team_id = agent.team.get_team_id() if agent.team else 0
			var our_flag = ctf_mode.get_flag(team_id)
			if our_flag:
				var dist = agent.global_position.distance_to(our_flag.global_position)
				return dist < 300
	
	return false

## Get state name for debugging
func get_state_name() -> String:
	match current_state:
		CtfState.ATTACK_FLAG: return "ATTACK_FLAG"
		CtfState.ESCORT_CARRIER: return "ESCORT_CARRIER"
		CtfState.DEFEND_BASE: return "DEFEND_BASE"
		CtfState.CHASE_CARRIER: return "CHASE_CARRIER"
		CtfState.RETURN_FLAG: return "RETURN_FLAG"
		CtfState.DELIVER_FLAG: return "DELIVER_FLAG"
	return "UNKNOWN"
