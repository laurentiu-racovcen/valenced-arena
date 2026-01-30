extends GameModeBase
class_name KothMode

# Preload behavior class
const KothBehaviorClass = preload("res://scripts/agents/KothBehavior.gd")

var hill_pos: Vector2 = Vector2.ZERO
var hill_radius: float = 200.0
var score_accumulator: float = 0.0 # Track partial seconds
var blue_accumulator: float = 0.0
var red_accumulator: float = 0.0

func setup(ctx) -> void:
	super(ctx)
	var map_instance = context.map.current_map 
	
	if not map_instance:
		return

	var hill_node = map_instance.find_child("Hill", true, false)
	
	if hill_node:
		# FIX: Store the global position so the update loop knows where the hill is
		hill_pos = hill_node.global_position
		var rad = 200.0
		
		var col = hill_node.find_child("CollisionShape2D", true, false)
		if col and col.shape is CircleShape2D:
			rad = col.shape.radius
		
		hill_radius = rad

		for agent in context.get_all_agents():
			if agent is Agent:
				agent.koth_mode = true
				agent.hill_location = hill_pos
				agent.hill_radius = rad
		
		# Attach KOTH behavior with role weights to all agents
		_setup_agents_for_koth()

func _setup_agents_for_koth() -> void:
	for agent in context.get_all_agents():
		_attach_koth_behavior(agent)

## Attach KOTH behavior to a single agent (used for initial setup and respawns)
func _attach_koth_behavior(agent: Node) -> void:
	if not agent is Agent:
		return
	
	# Skip if already has behavior attached
	if agent.has_meta("koth_behavior"):
		var existing = agent.get_meta("koth_behavior")
		if existing != null and is_instance_valid(existing):
			return
	
	# Set KOTH mode vars
	agent.koth_mode = true
	agent.hill_location = hill_pos
	agent.hill_radius = hill_radius
	agent.set_meta("koth_mode", true)
	
	# Attach KOTH behavior module with role-based weights
	var koth_behavior = KothBehaviorClass.new()
	koth_behavior.setup(agent, hill_pos, hill_radius)
	agent.add_child(koth_behavior)
	agent.set_meta("koth_behavior", koth_behavior)
	
	print("[KOTH] %s (%s) behavior attached - hold:%.1f, attack:%.1f" % [
		agent.name,
		Agent.Role.keys()[agent.role],
		koth_behavior.get_hold_weight(),
		koth_behavior.get_attack_weight()
	])

func update(delta: float) -> void:
	var blue_count: int = 0
	var red_count: int = 0
	
	# Check all agents - attach behavior if missing (handles respawns)
	for node in context.get_all_agents():
		var agent = node as Agent
		if not agent or not agent.is_alive(): 
			continue
		
		# RESPAWN FIX: Attach KOTH behavior if agent doesn't have it
		if not agent.has_meta("koth_behavior") or not is_instance_valid(agent.get_meta("koth_behavior")):
			_attach_koth_behavior(agent)
		
		# Calculate distance to hill center
		var dist_to_hill = agent.global_position.distance_to(hill_pos)
		
		# Use radius plus small buffer for accuracy
		if dist_to_hill < (hill_radius + 25.0):
			if agent.team.get_team_id() == 0:
				blue_count += 1
			else:
				red_count += 1

	# MAJORITY CONTROL: Team with MORE agents on the hill scores
	# If tied (same count), no one scores (contested)
	if blue_count > red_count and blue_count > 0:
		# Blue Team has majority control
		blue_accumulator += delta
		if blue_accumulator >= 1.0:
			blue_accumulator -= 1.0
			context.scoreA += 1
			context.score_changed.emit(context.scoreA, context.scoreB)
		# Reset red accumulator when blue controls
		red_accumulator = 0.0
			
	elif red_count > blue_count and red_count > 0:
		# Red Team has majority control
		red_accumulator += delta
		if red_accumulator >= 1.0:
			red_accumulator -= 1.0
			context.scoreB += 1
			context.score_changed.emit(context.scoreA, context.scoreB)
		# Reset blue accumulator when red controls
		blue_accumulator = 0.0
			
	else:
		# Contested (equal count) or empty - no points, reset accumulators
		blue_accumulator = 0.0
		red_accumulator = 0.0

func on_time_expired() -> void:
	# Winner decided by accumulated score in GameManager
	var winner = -1
	if context.scoreA > context.scoreB:
		winner = 0
	elif context.scoreB > context.scoreA:
		winner = 1
	
	context.on_round_ended(winner)

func on_agent_killed(agent, killer) -> void:
	# Keep this so agents don't respawn or to check if an entire team is wiped
	context.call_deferred("check_win_condition_deferred")

func check_win_condition() -> void:
	pass
