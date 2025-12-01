extends Node

@export var mode_type: Enums.GameMode = MatchConfig.game_mode
@export var agents_per_team: int = 4
@export var agent_scene: PackedScene = preload("res://scenes/agents/Agent.tscn")
var mode: GameModeBase = null
var time_left: float

#func _ready():
	#time_left = float(MatchConfig.round_time_seconds)
	#_spawn_agents()
	#_register_agents_to_teams()
	#_init_mode()
	#_connect_agent_signals()
func _ready():
	time_left = float(MatchConfig.round_time_seconds)
	_spawn_agents_and_assign_teams()
	_init_mode()
	_connect_agent_signals()

func _process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		if mode and mode.has_method("on_time_expired"):
			mode.on_time_expired()
	if mode:
		mode.update(delta)

func _init_mode() -> void:
	print("selected mode type=",mode_type)
	match mode_type:
		Enums.GameMode.SURVIVAL:
			mode = SurvivalMode.new()
		Enums.GameMode.KOTH:
			mode = KothMode.new()
		Enums.GameMode.CTF:
			mode = CtfMode.new()
		Enums.GameMode.TRANSPORT:
			mode = null

	if mode:
		add_child(mode)
		mode.setup(self)

func get_spawn_position(team_id: int, index_in_team: int, map: GameMap) -> Vector2:
	var center: Vector2 = map.get_team_spawn_center(team_id)

	# small “cluster” formation (2 columns)
	var cols := 2
	var spacing := 120.0
	var rows := int(ceil(float(agents_per_team) / float(cols)))

	var row := int(index_in_team / cols)
	var col := index_in_team % cols

	var x_off := (float(col) - (float(cols) - 1.0) * 0.5) * spacing
	var y_off := (float(row) - (float(rows) - 1.0) * 0.5) * spacing

	return center + Vector2(x_off, y_off)


func _spawn_agents_and_assign_teams() -> void:
	var agents_root := $"../AgentsRoot"
	var map := $"../GameMap" as GameMap
	var teams_node := $"../Teams"

	# Optional but strongly recommended: remove any Agent you placed in the editor
	for c in agents_root.get_children():
		c.queue_free()

	var team_a := teams_node.get_node("TeamA") as Team
	var team_b := teams_node.get_node("TeamB") as Team

	for team_id in range(2):
		for i in range(agents_per_team):
			var agent := agent_scene.instantiate() as Agent
			agents_root.add_child(agent)
			agent.map = map

			var team := team_a if team_id == 0 else team_b
			team.add_member(agent)

			var spawn_pos := get_spawn_position(team_id, i, map)
			agent.global_position = spawn_pos
			agent.global_position = _find_free_spawn_pos(agent, agent.global_position)

			
func _find_free_spawn_pos(agent: CharacterBody2D, desired: Vector2, tries := 60, step := 28.0) -> Vector2:
	var space := agent.get_world_2d().direct_space_state
	# Alternatively: var space := get_viewport().get_world_2d().direct_space_state

	var cs := agent.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null or cs.shape == null:
		return desired

	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = cs.shape
	params.collision_mask = agent.collision_mask
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.exclude = [agent.get_rid()]

	# Start from the collision shape's actual world transform
	params.transform = cs.global_transform

	# Try desired first
	params.transform.origin = desired
	if space.intersect_shape(params, 1).is_empty():
		return desired

	# Then search nearby in expanding rings
	for i in range(tries):
		var ring := float(i / 8) + 1.0
		var angle := float(i) * 0.61803398875 * TAU  # golden-angle spiral
		var candidate := desired + Vector2(cos(angle), sin(angle)) * (ring * step)

		params.transform.origin = candidate
		if space.intersect_shape(params, 1).is_empty():
			return candidate

	return desired


#func _spawn_agents() -> void:
	#var agents_root = $"../AgentsRoot"
	#var map = $"../GameMap"
#
	#for team_index in range(2):
		#for i in range(agents_per_team):
			#var agent = agent_scene.instantiate() as Agent
			#agents_root.add_child(agent)
			#agent.global_position = get_spawn_position(team_index, i)
			#agent.map = map
#
#
#func _register_agents_to_teams() -> void:
	#if not has_node("../Teams"):
		#return
	#var teams_node = $"../Teams"
#
	#var agents = get_all_agents()
	#if agents.is_empty():
		#return
#
	#var team_nodes = teams_node.get_children()
#
	#if team_nodes.size() < 2:
		#return
	#var half = agents.size() / 2
	#for i in range(agents.size()):
		#var team = team_nodes[0] if i < half else team_nodes[1]
		#team.add_member(agents[i])

func _connect_agent_signals() -> void:
	for a in get_all_agents():
		if not a.is_connected("died", Callable(self, "_on_agent_died")):
			a.connect("died", Callable(self, "_on_agent_died"))

func _on_agent_died(agent, killer) -> void:
	on_agent_killed(agent, killer)

func on_agent_killed(agent, killer) -> void:
	if mode and mode.has_method("on_agent_killed"):
		mode.on_agent_killed(agent, killer)
	if has_node("../StatsManager"):
		$"../StatsManager".on_agent_killed(agent, killer)

func get_all_agents() -> Array:
	if has_node("../AgentsRoot"):
		return $"../AgentsRoot".get_children()
	return []

func on_round_ended(winning_team: int) -> void:
	if has_node("../StatsManager"):
		$"../StatsManager".on_round_ended(winning_team)
	if has_node("../UIRoot"):
		$"../UIRoot".call_deferred("show_round_result", winning_team)
		

func check_win_condition_deferred():
	await get_tree().process_frame   # ensures all agents fully die
	if mode and mode.has_method("check_win_condition"):
		mode.check_win_condition()

func get_team_members(team_id: int) -> Array:
	if not has_node("../Teams"):
		return []
	for t in $"../Teams".get_children():
		if t.get_team_id() == team_id:
			return t.members
	return []
