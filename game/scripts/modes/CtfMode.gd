extends GameModeBase
class_name CtfMode

# Preload classes to ensure they're available
const FlagClass = preload("res://scripts/modes/Flag.gd")
const CtfBehaviorClass = preload("res://scripts/agents/CtfBehavior.gd")
const CtfHUDClass = preload("res://scripts/ui/CtfHUD.gd")

## References to the two flags
var blue_flag = null  # Team 0's flag (in blue base)
var red_flag = null   # Team 1's flag (in red base)

## Score tracking
var score := {0: 0, 1: 0}
@export var score_to_win: int = 3

## Flag spawn positions (extracted from map)
var blue_flag_spawn: Vector2 = Vector2.ZERO
var red_flag_spawn: Vector2 = Vector2.ZERO

## Capture zones
var blue_capture_zone: Area2D = null
var red_capture_zone: Area2D = null

## Preloaded flag scene
const FLAG_SCENE = preload("res://scenes/modes/Flag.tscn")

## CTF HUD reference
var ctf_hud = null

## Replay mode flag - skip AI setup if true
var _is_replay_mode: bool = false

func setup(ctx) -> void:
	super(ctx)
	
	# Check if we're in replay mode
	if context.has_method("get") or "_in_replay_mode" in context:
		_is_replay_mode = context._in_replay_mode if "_in_replay_mode" in context else false
	
	# Wait a frame to ensure map is fully loaded
	await context.get_tree().process_frame
	
	var map_instance = context.map.current_map
	if not map_instance:
		# Try waiting a bit more if map isn't ready
		await context.get_tree().create_timer(0.1).timeout
		map_instance = context.map.current_map
		
	if not map_instance:
		push_error("[CTF] No map instance found!")
		return
	
	# Clean up old flags if they exist (for round restarts)
	_cleanup_flags()
	
	# Find flag spawn points in the map
	_find_flag_spawns(map_instance)
	
	# Spawn the flags
	_spawn_flags()
	
	# Find or create capture zones
	_setup_capture_zones(map_instance)
	
	# Configure agents for CTF mode (skip if in replay)
	if not _is_replay_mode:
		_setup_agents_for_ctf()
	
	# Setup CTF HUD (only once)
	if ctf_hud == null:
		_setup_hud()
	
	var mode_str = "REPLAY" if _is_replay_mode else "NORMAL"
	print("[CTF] Mode initialized (%s)! Blue flag at %s, Red flag at %s" % [
		mode_str, str(blue_flag_spawn), str(red_flag_spawn)
	])

func _cleanup_flags() -> void:
	# Remove old flags
	if blue_flag and is_instance_valid(blue_flag):
		blue_flag.queue_free()
		blue_flag = null
	if red_flag and is_instance_valid(red_flag):
		red_flag.queue_free()
		red_flag = null
	
	# Also clean up any stray flags in the scene
	for node in get_tree().get_nodes_in_group("flags"):
		if is_instance_valid(node):
			node.queue_free()

func _find_flag_spawns(map_instance: Node) -> void:
	# Look for dedicated flag spawn nodes
	var blue_spawn_node = map_instance.find_child("BlueFlagSpawn", true, false)
	var red_spawn_node = map_instance.find_child("RedFlagSpawn", true, false)
	
	if blue_spawn_node:
		blue_flag_spawn = blue_spawn_node.global_position
	else:
		# Fallback: use team spawn area center
		var spawns = map_instance.find_child("Spawns", true, false)
		if spawns:
			var t0_spawns = []
			for child in spawns.get_children():
				if child.name.begins_with("T0_"):
					t0_spawns.append(child.global_position)
			if t0_spawns.size() > 0:
				blue_flag_spawn = _get_center(t0_spawns) + Vector2(-100, 0)
	
	if red_spawn_node:
		red_flag_spawn = red_spawn_node.global_position
	else:
		# Fallback: use team spawn area center
		var spawns = map_instance.find_child("Spawns", true, false)
		if spawns:
			var t1_spawns = []
			for child in spawns.get_children():
				if child.name.begins_with("T1_"):
					t1_spawns.append(child.global_position)
			if t1_spawns.size() > 0:
				red_flag_spawn = _get_center(t1_spawns) + Vector2(100, 0)

func _get_center(positions: Array) -> Vector2:
	if positions.is_empty():
		return Vector2.ZERO
	var sum = Vector2.ZERO
	for pos in positions:
		sum += pos
	return sum / positions.size()

func _spawn_flags() -> void:
	var agents_root = context.get_node("../AgentsRoot")
	if not agents_root:
		push_error("[CTF] No AgentsRoot found!")
		return
	
	# Spawn blue team's flag (at blue base)
	blue_flag = FLAG_SCENE.instantiate()
	blue_flag.team_id = 0
	blue_flag.global_position = blue_flag_spawn
	agents_root.get_parent().add_child(blue_flag)
	
	# Spawn red team's flag (at red base)
	red_flag = FLAG_SCENE.instantiate()
	red_flag.team_id = 1
	red_flag.global_position = red_flag_spawn
	agents_root.get_parent().add_child(red_flag)
	
	# Connect flag signals
	blue_flag.picked_up.connect(_on_flag_picked_up)
	blue_flag.dropped.connect(_on_flag_dropped)
	blue_flag.returned_to_base.connect(_on_flag_returned)
	blue_flag.delivered.connect(_on_flag_delivered)
	
	red_flag.picked_up.connect(_on_flag_picked_up)
	red_flag.dropped.connect(_on_flag_dropped)
	red_flag.returned_to_base.connect(_on_flag_returned)
	red_flag.delivered.connect(_on_flag_delivered)

func _setup_capture_zones(map_instance: Node) -> void:
	# Look for existing capture zones or create them based on spawns
	blue_capture_zone = map_instance.find_child("BlueCaptureZone", true, false)
	red_capture_zone = map_instance.find_child("RedCaptureZone", true, false)
	
	# If no dedicated zones, flags can be captured near their own spawn
	# The actual capture check happens in update()

func _setup_agents_for_ctf() -> void:
	for agent in context.get_all_agents():
		if agent is Agent:
			agent.set_meta("ctf_mode", true)
			
			# Attach CTF behavior module
			var ctf_behavior = CtfBehaviorClass.new()
			ctf_behavior.setup(agent, self)
			agent.add_child(ctf_behavior)
			agent.set_meta("ctf_behavior", ctf_behavior)
			
			# Connect death signal to handle flag dropping
			if not agent.died.is_connected(_on_agent_died):
				agent.died.connect(_on_agent_died)

func _setup_hud() -> void:
	# Instantiate CTF HUD
	var hud_scene = preload("res://scenes/CtfHUD.tscn")
	ctf_hud = hud_scene.instantiate()
	
	# Get camera reference for off-screen indicators
	var camera: Camera2D = null
	var camera_nodes = get_tree().get_nodes_in_group("camera")
	if camera_nodes.size() > 0:
		camera = camera_nodes[0] as Camera2D
	else:
		# Try to find camera in viewport
		var viewport = get_tree().root.get_viewport()
		if viewport:
			for child in get_tree().root.get_children():
				if child is Camera2D:
					camera = child
					break
	
	ctf_hud.setup(self, camera)
	get_tree().root.add_child(ctf_hud)
	print("[CTF] HUD initialized")

func update(delta: float) -> void:
	# Check for flag captures (carrier reaching their own base with enemy flag)
	_check_captures()
	
	# Update flag positions if carried
	# (handled by Flag._process)

func _check_captures() -> void:
	# Check if blue team can capture (someone with red flag at blue base)
	if red_flag and red_flag.state == FlagClass.State.CARRIED:
		var carrier = red_flag.carrier
		if carrier and carrier.team and carrier.team.get_team_id() == 0:
			# Blue team member has red flag
			# Check if blue's own flag is at base (required for capture in most CTF rules)
			var can_capture = true
			if blue_flag and blue_flag.state != FlagClass.State.AT_BASE:
				can_capture = false  # Can't capture if your flag is not at base
			
			if can_capture:
				# Check if carrier is at blue base
				var dist_to_base = carrier.global_position.distance_to(blue_flag_spawn)
				if dist_to_base < 150.0:  # Capture radius
					red_flag.deliver(carrier)
	
	# Check if red team can capture
	if blue_flag and blue_flag.state == FlagClass.State.CARRIED:
		var carrier = blue_flag.carrier
		if carrier and carrier.team and carrier.team.get_team_id() == 1:
			# Red team member has blue flag
			var can_capture = true
			if red_flag and red_flag.state != FlagClass.State.AT_BASE:
				can_capture = false
			
			if can_capture:
				var dist_to_base = carrier.global_position.distance_to(red_flag_spawn)
				if dist_to_base < 150.0:
					blue_flag.deliver(carrier)

func _on_flag_picked_up(flag, agent: Agent) -> void:
	print("[CTF] %s picked up the %s flag!" % [
		agent.name, "Blue" if flag.team_id == 0 else "Red"
	])
	# Record for replay
	_record_replay_flag_pickup(flag.team_id, agent.id if "id" in agent else agent.name)
	# Notify all agents about flag status
	_broadcast_flag_status(flag)

func _on_flag_dropped(flag, position: Vector2) -> void:
	print("[CTF] %s flag dropped at %s" % [
		"Blue" if flag.team_id == 0 else "Red", str(position)
	])
	# Record for replay
	_record_replay_flag_drop(flag.team_id, position)
	_broadcast_flag_status(flag)

func _on_flag_returned(flag) -> void:
	print("[CTF] %s flag returned to base!" % [
		"Blue" if flag.team_id == 0 else "Red"
	])
	# Record for replay
	_record_replay_flag_return(flag.team_id)
	_broadcast_flag_status(flag)

func _on_flag_delivered(flag, agent: Agent) -> void:
	# Enemy team captured this flag
	var capturing_team = agent.team.get_team_id() if agent.team else -1
	
	if capturing_team >= 0:
		score[capturing_team] += 1
		print("[CTF] Team %d captured the %s flag! Score: %d-%d" % [
			capturing_team,
			"Blue" if flag.team_id == 0 else "Red",
			score[0], score[1]
		])
		
		# Record for replay
		_record_replay_flag_capture(flag.team_id, agent.id if "id" in agent else agent.name)
		
		# Update GameManager score
		context.scoreA = score[0]
		context.scoreB = score[1]
		context.score_changed.emit(context.scoreA, context.scoreB)
		
		# Check win condition
		if score[capturing_team] >= score_to_win:
			context.on_round_ended(capturing_team)

func _on_agent_died(agent: Agent, killer: Agent) -> void:
	# Check if the dead agent was carrying a flag
	if blue_flag and blue_flag.is_carried_by(agent):
		blue_flag.on_carrier_died()
	if red_flag and red_flag.is_carried_by(agent):
		red_flag.on_carrier_died()

func _broadcast_flag_status(flag) -> void:
	# Send flag status message to all agents (for AI decision making)
	for agent in context.get_all_agents():
		if agent is Agent and agent.has_method("on_flag_status_changed"):
			agent.on_flag_status_changed(flag)

func on_time_expired() -> void:
	# Winner is the team with more captures
	var winner = -1
	if score[0] > score[1]:
		winner = 0
	elif score[1] > score[0]:
		winner = 1
	
	# If a flag is being carried when time expires, give a slight advantage?
	# For now, tie remains a tie
	
	context.on_round_ended(winner)

func on_agent_killed(agent: Agent, killer: Agent) -> void:
	# Flag dropping is handled by _on_agent_died
	pass

func check_win_condition() -> void:
	# Already handled in _on_flag_delivered
	pass

## Get flag by team ID
func get_flag(team_id: int):
	return blue_flag if team_id == 0 else red_flag

## Get enemy flag for a team
func get_enemy_flag(team_id: int):
	return red_flag if team_id == 0 else blue_flag

## Get the flag carrier for a team's flag (if being carried)
func get_flag_carrier(team_id: int) -> Agent:
	var flag = get_flag(team_id)
	if flag and flag.state == FlagClass.State.CARRIED:
		return flag.carrier
	return null

## Check if a team's flag is safe
func is_flag_safe(team_id: int) -> bool:
	var flag = get_flag(team_id)
	return flag != null and flag.state == FlagClass.State.AT_BASE

## Get flag position
func get_flag_position(team_id: int) -> Vector2:
	var flag = get_flag(team_id)
	if flag:
		return flag.global_position
	return Vector2.ZERO

## Get flag base position for delivery
func get_flag_base_position(team_id: int) -> Vector2:
	return blue_flag_spawn if team_id == 0 else red_flag_spawn

## Cleanup when round/match ends
func cleanup_ctf() -> void:
	_cleanup_flags()
	if ctf_hud and is_instance_valid(ctf_hud):
		ctf_hud.queue_free()
		ctf_hud = null

func _exit_tree() -> void:
	cleanup_ctf()

## ===== REPLAY RECORDING HELPERS =====

func _record_replay_flag_pickup(flag_team_id: int, carrier_id: String) -> void:
	if get_tree().root.has_node("Replay"):
		var replay := get_tree().root.get_node("Replay")
		if replay != null and replay.has_method("record_flag_pickup"):
			replay.call("record_flag_pickup", flag_team_id, carrier_id)

func _record_replay_flag_drop(flag_team_id: int, pos: Vector2) -> void:
	if get_tree().root.has_node("Replay"):
		var replay := get_tree().root.get_node("Replay")
		if replay != null and replay.has_method("record_flag_drop"):
			replay.call("record_flag_drop", flag_team_id, pos)

func _record_replay_flag_return(flag_team_id: int) -> void:
	if get_tree().root.has_node("Replay"):
		var replay := get_tree().root.get_node("Replay")
		if replay != null and replay.has_method("record_flag_return"):
			replay.call("record_flag_return", flag_team_id)

func _record_replay_flag_capture(flag_team_id: int, capturer_id: String) -> void:
	if get_tree().root.has_node("Replay"):
		var replay := get_tree().root.get_node("Replay")
		if replay != null and replay.has_method("record_flag_capture"):
			replay.call("record_flag_capture", flag_team_id, capturer_id)
