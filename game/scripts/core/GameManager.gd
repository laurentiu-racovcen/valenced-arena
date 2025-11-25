extends Node

@export var mode_type: Enums.GameMode = MatchConfig.game_mode
@export var agents_per_team: int = 4
@export var agent_scene: PackedScene = preload("res://scenes/agents/Agent.tscn")
var mode: GameModeBase = null
var time_left: float

func _ready():
	time_left = float(MatchConfig.round_time_seconds)
	_spawn_agents()
	_register_agents_to_teams()
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

func get_spawn_position(team_index: int, index_in_team: int) -> Vector2:
	var team_center_x = -600 if team_index == 0 else 600
	var spacing = 160
	# echipa este centrată pe verticală
	var start_y = -(agents_per_team - 1) * spacing / 2
	var y = start_y + index_in_team * spacing
	return Vector2(team_center_x, y)

func _spawn_agents() -> void:
	var agents_root = $"../AgentsRoot"
	var map = $"../GameMap"

	for team_index in range(2):
		for i in range(agents_per_team):
			var agent = agent_scene.instantiate() as Agent
			agents_root.add_child(agent)
			agent.global_position = get_spawn_position(team_index, i)
			agent.map = map


func _register_agents_to_teams() -> void:
	if not has_node("../Teams"):
		return
	var teams_node = $"../Teams"

	var agents = get_all_agents()
	if agents.is_empty():
		return

	var team_nodes = teams_node.get_children()

	if team_nodes.size() < 2:
		return
	var half = agents.size() / 2
	for i in range(agents.size()):
		var team = team_nodes[0] if i < half else team_nodes[1]
		team.add_member(agents[i])

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
