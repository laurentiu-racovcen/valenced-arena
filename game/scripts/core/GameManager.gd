extends Node

enum GameModeType { SURVIVAL, KOTH, CTF, TRANSPORT }

@export var mode_type: GameModeType = GameModeType.SURVIVAL
var mode = null
var time_left: float = 120.0

func _ready():
	_init_mode()

func _process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		if mode and "on_time_expired" in mode:
			mode.on_time_expired()
	if mode and "update" in mode:
		mode.update(delta)

func _init_mode() -> void:
	match mode_type:
		GameModeType.SURVIVAL:
			mode = load("res://scripts/modes/SurvivalMode.gd").new()
		GameModeType.KOTH:
			mode = load("res://scripts/modes/KothMode.gd").new()
		GameModeType.CTF:
			mode = load("res://scripts/modes/CtfMode.gd").new()
		GameModeType.TRANSPORT:
			mode = load("res://scripts/modes/TransportMode.gd").new()
	if mode:
		add_child(mode)
		if "setup" in mode:
			mode.setup(self)

func on_agent_killed(agent, killer) -> void:
	if mode and "on_agent_killed" in mode:
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
