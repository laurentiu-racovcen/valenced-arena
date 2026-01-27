extends Node

@export var mode_type: Enums.GameMode = MatchConfig.game_mode
@export var agents_per_team: int = 4
@export var agent_scene: PackedScene = preload("res://scenes/agents/Agent.tscn")
var mode: GameModeBase = null
var time_left: float
@onready var map = $"../GameMap" as GameMap

@export var music_survival: AudioStream
@export var music_koth: AudioStream
@export var music_ctf: AudioStream
@onready var music: AudioStreamPlayer = $"../Music"

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

var _in_replay_mode: bool = false

func _ready():
	# Always sync from MatchConfig at runtime (export default is evaluated early).
	mode_type = MatchConfig.game_mode
	
	_play_mode_music()

	time_left = float(Enums.ROUNDS_SETTING_DURATION[SettingsManager.get_rounds_duration_index()])
	map.map_loaded.connect(_on_map_loaded)

	# Check if we're going into replay mode
	var in_replay_playback := false
	if get_tree().root.has_node("Replay"):
		var replay := get_tree().root.get_node("Replay")
		if replay != null and replay.has_method("is_playback_pending"):
			in_replay_playback = bool(replay.call("is_playback_pending"))
			if in_replay_playback and replay.has_method("get_mode_type"):
				# Use the recorded mode type for visual initialization
				mode_type = replay.call("get_mode_type") as Enums.GameMode

	# Always create ScoreHUD (works for both normal and replay mode)
	score_hud = preload("res://scenes/ScoreHUD.tscn").instantiate() as ScoreHUD
	get_tree().root.add_child(score_hud)
	if in_replay_playback:
		score_hud.set_replay_mode(true)
	score_hud.set_score(scoreA, scoreB)
	score_changed.connect(score_hud.set_score)

func _on_map_loaded():
	_spawn_agents_and_assign_teams()
	var sm := $"../StatsManager" as StatsManager
	if sm != null and sm.has_method("start_round"):
		sm.start_round(get_all_agents())
	# Replay integration (recording or playback)
	if get_tree().root.has_node("Replay"):
		var replay := get_tree().root.get_node("Replay")
		if replay != null:
			var agents := get_all_agents()
			# If a replay is pending, enter playback mode
			if replay.has_method("is_playback_pending") and bool(replay.call("is_playback_pending")):
				_in_replay_mode = true
				replay.call("begin_playback", agents)
				set_process(false) # stop match timer + mode updates
				# Still init mode for visual elements (flags for CTF, etc.)
				_init_mode()
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
	

var _time_expired_called: bool = false

func _process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		if not _time_expired_called and mode and mode.has_method("on_time_expired"):
			_time_expired_called = true
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

func _play_mode_music() -> void:
	if music == null:
		return

	match mode_type:
		Enums.GameMode.SURVIVAL:
			music.stream = music_survival
		Enums.GameMode.KOTH:
			music.stream = music_koth
		Enums.GameMode.CTF:
			music.stream = music_ctf

	if music.stream != null:
		music.play()

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
			team.add_member(agent, 0)

			agent.global_position = map.get_spawn_global(team_id, i)
			var team_id_str: String
			if team_id == 0:
				team_id_str = "blue"
			else:
				team_id_str = "red"
			agent.apply_team_skin(team_id_str, agent.role)

func _connect_agent_signals() -> void:
	# Connect died signal for all modes (Survival, KOTH, CTF)
	for a in get_all_agents():
		if not a.is_connected("died", Callable(self, "_on_agent_died")):
			a.connect("died", Callable(self, "_on_agent_died"))

#func _on_agent_died(agent, killer) -> void:
	#on_agent_killed(agent, killer)
#func _on_agent_died(agent, killer) -> void:
	## Identificăm echipa și indexul pentru respawn
	#var team_id = 0 if agent.team.name.contains("TeamA") else 1
	## Folosim un index generic sau păstrăm indexul original dacă e necesar
	#respawn_agent(team_id, randi() % agents_per_team)
	#
	#on_agent_killed(agent, killer)
# În GameManager.gd
var _respawn_queues = {
	0: [], # Echipa Albastră (TeamA)
	1: []  # Echipa Roșie (TeamB)
}

func _on_agent_died(agent: Agent, killer) -> void:
	if round_over or match_over:
		return

	# Identificăm echipa (0 pentru Blue, 1 pentru Red)
	var team_id = 0
	if agent.team and agent.team.name.contains("TeamB"):
		team_id = 1
		
	# Salvăm rolul exact în coada echipei [cite: 38, 39]
	_respawn_queues[team_id].push_back(agent.role)
	
	
	on_agent_killed(agent, killer)
	
	# Pornim timer-ul de respawn
	if mode is KothMode:
		get_tree().create_timer(5.0).timeout.connect(_on_respawn_timer_expired.bind(team_id))
	elif mode is CtfMode:
		get_tree().create_timer(5.0).timeout.connect(_on_respawn_timer_expired.bind(team_id))

func _on_respawn_timer_expired(team_id: int):
	if round_over or match_over:
		return
	
	# Extragem primul rol care a murit din coadă
	if _respawn_queues[team_id].is_empty():
		return
		
	var next_role = _respawn_queues[team_id].pop_front()
	_perform_respawn(team_id, next_role)

func _perform_respawn(team_id: int, role_to_apply: int):
	var agents_root := $"../AgentsRoot"
	var teams_node := $"../Teams"
	
	var team = teams_node.get_node("TeamA") if team_id == 0 else teams_node.get_node("TeamB")
	
	# For CTF mode, always respawn with the original role
	var actual_role := role_to_apply
	
	# Only check for missing roles in non-CTF modes (e.g., KOTH with promotions)
	if not (mode is CtfMode):
		# Check what role is actually MISSING on the team (in case of promotion)
		var existing_roles := {}
		for m in team.members:
			if m != null and is_instance_valid(m) and m.is_alive():
				existing_roles[m.role] = true
		
		var role_priority := [Agent.Role.LEADER, Agent.Role.TANK, Agent.Role.SUPPORT, Agent.Role.ADVANCE]
		
		# If the requested role already exists, find a missing one
		if existing_roles.has(role_to_apply):
			for r in role_priority:
				if not existing_roles.has(r):
					actual_role = r
					break
	
	var agent = agent_scene.instantiate() as Agent
	
	# SETĂM ROLUL înainte de add_child
	agent.role = actual_role
	
	agents_root.add_child(agent)
	
	# Forțăm încărcarea AI-ului pentru rolul nou
	agent.set_role(actual_role) 

	agent.map = map
	team.add_member(agent, 1)
	
	# Poziționare [cite: 41]
	var spawn_idx = randi() % agents_per_team
	agent.global_position = map.get_spawn_global(team_id, spawn_idx)
	
	# Configurare finală [cite: 2, 42]
	var team_id_str = "blue" if team_id == 0 else "red"
	agent.apply_team_skin(team_id_str, agent.role)
	
	if mode is KothMode:
		agent.koth_mode = true
		agent.hill_location = mode.hill_pos
		agent.hill_radius = mode.hill_radius
	
	# CTF mode setup for respawned agent
	if mode is CtfMode:
		agent.set_meta("ctf_mode", true)
		var ctf_behavior = load("res://scripts/agents/CtfBehavior.gd").new()
		ctf_behavior.setup(agent, mode)
		agent.add_child(ctf_behavior)
		agent.set_meta("ctf_behavior", ctf_behavior)
	
	# Conectăm moartea pentru a continua ciclul [cite: 8]
	if mode is KothMode or mode is CtfMode:
		agent.died.connect(_on_agent_died)

func on_agent_killed(agent, killer) -> void:
	if mode and mode.has_method("on_agent_killed"):
		# Pass null for killer if it's been freed to avoid invalid reference errors
		var valid_killer = killer if is_instance_valid(killer) else null
		mode.on_agent_killed(agent, valid_killer)

func get_all_agents() -> Array:
	if has_node("../AgentsRoot"):
		return $"../AgentsRoot".get_children()
	return []

func on_round_ended(winning_team: int) -> void:
	if round_over or match_over:
		return
	round_over = true
	
	# Stop HUD timer immediately
	if is_instance_valid(score_hud):
		score_hud.stop_timer()

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
	$"../UILayer".add_child(countdown)  # Add to UI layer

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
	_time_expired_called = false  # Reset timer flag for new round
	
	# Reset HUD timer for new round
	if is_instance_valid(score_hud):
		score_hud.reset_timer()
	
	round_over = false
	
	if mode:
		_on_map_loaded()

func on_match_ended(winning_team: int) -> void:
	# Capture total match time BEFORE freeing the HUD
	var total_match_time: float = 0.0
	if is_instance_valid(score_hud) and score_hud.has_method("get_total_match_time"):
		total_match_time = score_hud.get_total_match_time()
	
	# Finalize replay recording
	if get_tree().root.has_node("Replay"):
		var replay := get_tree().root.get_node("Replay")
		if replay != null and replay.has_method("end_recording"):
			replay.call("end_recording", true)

	# Remove in-match score HUD
	if is_instance_valid(score_hud):
		score_hud.queue_free()
		score_hud = null
	
	# Cleanup mode-specific resources (e.g., CTF HUD)
	if mode and mode.has_method("cleanup_ctf"):
		mode.cleanup_ctf()

	print("Team ", winning_team, " won!")
	match_ended.emit(winning_team)

	var ps := load("res://scenes/EndRoundMenu.tscn") as PackedScene
	var menu := ps.instantiate()
	add_child(menu)

	var sm := $"../StatsManager" as StatsManager
	if sm != null and sm.has_method("build_round_result"):
		# ia comms din echipe (Team.gd are $Comms) [file:56]
		var teamA := $"../Teams/TeamA" as Team
		var teamB := $"../Teams/TeamB" as Team
		var result := sm.build_round_result(
			winning_team,
			scoreA,
			scoreB,
			teamA.comms if teamA != null else null,
			teamB.comms if teamB != null else null
		)
		
		# Use total match time captured earlier
		result["duration_sec"] = total_match_time

		menu.show_round_stats(result)
	else:
		# fallback (cum e acum)
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

func respawn_agent(team_id: int, agent_index: int):
	# Așteptăm 3 secunde înainte de respawn
	await get_tree().create_timer(3.0).timeout
	
	if round_over or match_over: return

	var agents_root := $"../AgentsRoot"
	var teams_node := $"../Teams"
	var team_a := teams_node.get_node("TeamA") as Team
	var team_b := teams_node.get_node("TeamB") as Team
	var team = team_a if team_id == 0 else team_b

	# Creăm agentul nou
	var agent := agent_scene.instantiate() as Agent
	agents_root.add_child(agent)
	agent.map = map
	
	# Îl adăugăm în echipă [cite: 5, 6]
	team.add_member(agent, 1)
	
	# Poziționăm agentul la spawn-ul corespunzător [cite: 5, 6]
	agent.global_position = map.get_spawn_global(team_id, agent_index)
	
	# Aplicăm skin-ul și setăm modul KOTH [cite: 1, 2, 5, 6]
	var team_id_str = "blue" if team_id == 0 else "red"
	agent.apply_team_skin(team_id_str, agent.role)
	
	# Re-inițializăm setările de KOTH pentru agentul nou
	if mode is KothMode:
		agent.koth_mode = true
		agent.hill_location = mode.hill_pos
		agent.hill_radius = mode.hill_radius

	# Reconectăm semnalul de moarte
	agent.died.connect(_on_agent_died)
