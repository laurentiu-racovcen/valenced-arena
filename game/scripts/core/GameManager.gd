extends Node

@export var mode_type: Enums.GameMode = MatchConfig.game_mode
@export var agents_per_team: int = 4
@export var agent_scene: PackedScene = preload("res://scenes/agents/Agent.tscn")
var mode: GameModeBase = null
var time_left: float
@onready var map = $"../GameMap" as GameMap
signal round_ended(winning_team: int)
signal match_ended(winning_team: int)

var scoreA : int = 0
var scoreB : int = 0

var round_over := false
var rounds_played := 0
var match_over := false

signal score_changed(a: int, b: int)
@export var score_hud_scene: PackedScene
var score_hud: ScoreHUD

func _ready():
	# Always sync from MatchConfig at runtime (export default is evaluated early).
	mode_type = MatchConfig.game_mode

	time_left = float(Enums.ROUNDS_SETTING_DURATION[SettingsManager.get_rounds_duration_index()])
	map.map_loaded.connect(_on_map_loaded)

	# Skip ScoreHUD during replay playback (it should not leak into the menu).
	var in_replay_playback := false
	if get_tree().root.has_node("Replay"):
		var replay := get_tree().root.get_node("Replay")
		if replay != null and replay.has_method("is_playback_pending"):
			in_replay_playback = bool(replay.call("is_playback_pending"))

	if not in_replay_playback:
		# for real-time score display
		score_hud = preload("res://scenes/ScoreHUD.tscn").instantiate() as ScoreHUD
		get_tree().root.add_child(score_hud)
		score_hud.set_score(scoreA, scoreB)
		score_changed.connect(score_hud.set_score)

func _on_map_loaded():
	_spawn_agents_and_assign_teams()
	# Replay integration (recording or playback)
	if get_tree().root.has_node("Replay"):
		var replay := get_tree().root.get_node("Replay")
		if replay != null:
			var agents := get_all_agents()
			# If a replay is pending, enter playback mode and skip gameplay logic.
			if replay.has_method("is_playback_pending") and bool(replay.call("is_playback_pending")):
				replay.call("begin_playback", agents)
				set_process(false) # stop match timer + mode updates
				return
			# Otherwise record this round. (If already recording, just update agent refs.)
			if replay.has_method("is_recording") and bool(replay.call("is_recording")):
				if replay.has_method("set_recording_agents"):
					replay.call("set_recording_agents", agents)
			else:
				if replay.has_method("begin_recording"):
					replay.call("begin_recording", agents, int(mode_type))

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

	# Clear team lists (drop references to old agents)
	for t in teams_node.get_children():
		var team := t as Team
		if team:
			team.members.clear()

	# Remove old agent nodes
	for c in agents_root.get_children():
		c.queue_free()

	var team_a := teams_node.get_node("TeamA") as Team
	var team_b := teams_node.get_node("TeamB") as Team

	for team_id in range(2):
		for i in range(agents_per_team):
			var agent := agent_scene.instantiate() as Agent
			agents_root.add_child(agent)
			agent.map = map
			# Assign a stable ID so recordings can map agents across runs.
			agent.id = "T%d_%d" % [team_id, i]
			agent.name = agent.id

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
	if round_over or match_over:
		return
	round_over = true

	print("round winning team = ", winning_team)
	round_ended.emit(winning_team)
	if winning_team == 0:
		scoreA += 1
	elif winning_team == 1:
		scoreB += 1

	score_changed.emit(scoreA, scoreB)

	rounds_played += 1

	# Decide if match ends
	if rounds_played >= Enums.ROUNDS_SETTING_NUMBER[SettingsManager.get_rounds_number_index()]:
		match_over = true
		var match_winner := -1
		if scoreA > scoreB: match_winner = 0
		elif scoreB > scoreA: match_winner = 1

		on_match_ended(match_winner)
		return


	# restart the map
	get_tree().paused = true
	
	# Show countdown UI that still processes while paused
	var ps := preload("res://scenes/RoundCountdown.tscn")
	var countdown := ps.instantiate() as RoundCountdown
	$"../UIRoot".add_child(countdown)  # or wherever your UI lives

	var win_team_str: String
	if winning_team == 0:
		win_team_str = "Blue"
	elif winning_team == 1:
		win_team_str = "Red"
	else:
		win_team_str = "No"
	countdown.start(5.0, win_team_str)

	# Wait until countdown finishes
	await countdown.finished

	# pause for 5 seconds
	get_tree().paused = false

	# reset left round time
	time_left = float(Enums.ROUNDS_SETTING_DURATION[SettingsManager.get_rounds_duration_index()])
	map.time_left = time_left
	
	round_over = false
	
	if mode:
		_on_map_loaded()

func on_match_ended(winning_team: int) -> void:
	# Finalize replay recording
	if get_tree().root.has_node("Replay"):
		var replay := get_tree().root.get_node("Replay")
		if replay != null and replay.has_method("end_recording"):
			replay.call("end_recording", true)

	# Remove in-match score HUD
	if is_instance_valid(score_hud):
		score_hud.queue_free()
		score_hud = null

	print("Team ", winning_team, " won!")
	match_ended.emit(winning_team)

	if has_node("../StatsManager"):
		$"../StatsManager".on_round_ended(winning_team)

	var ps := load("res://scenes/EndRoundMenu.tscn") as PackedScene
	var menu := ps.instantiate()
	add_child(menu)
	menu.show_round_result(winning_team, scoreA, scoreB)

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
