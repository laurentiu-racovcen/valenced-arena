extends Node

@export var mode_type: Enums.GameMode = MatchConfig.game_mode
@export var agents_per_team: int = 4
@export var agent_scene: PackedScene = preload("res://scenes/agents/Agent.tscn")
var mode: GameModeBase = null
var time_left: float
@onready var map = $"../GameMap" as GameMap

func _ready():
	time_left = float(MatchConfig.round_time_seconds)
	map.map_loaded.connect(_on_map_loaded)

func _on_map_loaded():
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
		_:
			push_error("Unknown game mode")

	if mode:
		add_child(mode)
		mode.setup(self)

func _spawn_agents_and_assign_teams() -> void:
	var agents_root := $"../AgentsRoot"
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

			agent.global_position = map.get_spawn_global(team_id, i)
			var team_id_str: String
			if team_id == 0:
				team_id_str = "blue"
			else:
				team_id_str = "red"
			agent.apply_team_skin(team_id_str, agent.role)

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
