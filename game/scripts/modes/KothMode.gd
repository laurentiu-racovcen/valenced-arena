extends GameModeBase
class_name KothMode

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

func update(delta: float) -> void:
	var blue_present: bool = false
	var red_present: bool = false
	
	# Check all agents for presence in the hill
	for node in context.get_all_agents():
		var agent = node as Agent
		if not agent or not agent.is_alive(): 
			continue
		# Buffer distance check (radius + 25px)
		if agent.global_position.distance_to(hill_pos) < (hill_radius + 25.0):
			if agent.team.get_team_id() == 0: 
				blue_present = true
			else: red_present = true
	
	var score_changed: bool = false

	# Independent scoring for Blue Team
	if blue_present:
		blue_accumulator += delta
		if blue_accumulator >= 1.0:
			blue_accumulator -= 1.0
			context.scoreA += 1
			score_changed = true
			
	# Independent scoring for Red Team
	if red_present:
		red_accumulator += delta
		if red_accumulator >= 1.0:
			red_accumulator -= 1.0
			context.scoreB += 1
			score_changed = true
			
	# Update the HUD only if a point was actually added
	if score_changed:
		context.score_changed.emit(context.scoreA, context.scoreB)
func on_time_expired() -> void:
	# In KOTH, the winner is based on SCORE, not who is alive
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
	var teamA_alive = context.get_team_members(0).size()
	var teamB_alive = context.get_team_members(1).size()

	if teamA_alive == 0:
		context.on_round_ended(1)
	elif teamB_alive == 0:
		context.on_round_ended(0)
