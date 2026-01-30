extends Node
## Autoload singleton (project.godot): `Replay="*res://scripts/stats/ReplayManager.gd"`
##
## Recorded replay approach (v2):
## - During a match, record agent state snapshots at a fixed tick rate (e.g. 15 Hz).
## - Also record game events (score changes, round ends, respawns).
## - Save to `user://last_replay.json`.
## - Replay button loads ReplayMatch.tscn which uses ReplayController for playback.

const LAST_REPLAY_PATH := "user://last_replay.json"

@export var record_tick_rate: float = 15.0

enum ReplayState { IDLE, RECORDING, PLAYBACK }
var _state: int = ReplayState.IDLE

var _record_dt: float = 0.0
var _record_accum: float = 0.0
var _record_time: float = 0.0

var _agent_ids: Array[String] = []
var _agents: Array = []  # [Agent] but keep untyped to avoid parse issues
var _agents_by_id: Dictionary = {}  # id -> Agent

var _data: Dictionary = {}
var _frames: Array = []  # array of {t: float, a: Array[Dictionary]}
var _events: Array = []  # array of {t: float, type: String, ...}
var _last_live_state: Dictionary = {}  # agent_id -> {x,y,rot,hp,ammo,alive}

var _pending_playback: bool = false

func _ready() -> void:
	# Ensure the autoload keeps processing even if scenes pause the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	
	# Delete any old replay file - replays are session-only
	if FileAccess.file_exists(LAST_REPLAY_PATH):
		DirAccess.remove_absolute(LAST_REPLAY_PATH)

## ===== PUBLIC API =====

func has_last_replay() -> bool:
	return FileAccess.file_exists(LAST_REPLAY_PATH)

func is_playback_pending() -> bool:
	return _pending_playback

func is_recording() -> bool:
	return _state == ReplayState.RECORDING

func is_playing_replay() -> bool:
	## Returns true if we're currently playing back a replay
	return _state == ReplayState.PLAYBACK or _pending_playback

func is_playing() -> bool:
	return _state == ReplayState.PLAYBACK

func get_mode_type() -> int:
	return int(_data.get("mode", 0))

func get_replay_data() -> Dictionary:
	## Returns the loaded replay data for ReplayController to use.
	return _data

func request_replay_last() -> void:
	## Called from the menu replay button.
	## Loads saved replay and opens the dedicated ReplayMatch scene.
	var loaded := _load_last()
	if loaded.is_empty():
		print("[Replay] No replay data found, returning to menu")
		return
	
	_data = loaded
	_frames = _data.get("frames", []) as Array
	_events = _data.get("events", []) as Array
	_pending_playback = true
	_state = ReplayState.PLAYBACK
	
	# Store the mode so GameMap can load the correct map
	var mode_type: int = int(_data.get("mode", 0))
	MatchConfig.game_mode = mode_type as Enums.GameMode
	
	# Restore the selected map path (empty string means use default for mode)
	MatchConfig.selected_map = str(_data.get("selected_map", ""))
	
	print("[Replay] Loading replay: mode=%d, map=%s, frames=%d, events=%d" % [
		mode_type, MatchConfig.selected_map if MatchConfig.selected_map != "" else "default", _frames.size(), _events.size()
	])
	
	# Use the new dedicated ReplayMatch scene
	get_tree().change_scene_to_file("res://scenes/replay/ReplayMatch.tscn")

func clear_pending() -> void:
	## Called by ReplayController after it takes over playback.
	_pending_playback = false

func end_playback() -> void:
	## Called when replay playback ends.
	_state = ReplayState.IDLE
	_pending_playback = false

## ===== RECORDING API =====

func begin_recording(agents: Array, mode_type: int) -> void:
	_state = ReplayState.RECORDING
	_pending_playback = false
	_record_dt = 1.0 / max(record_tick_rate, 1.0)
	_record_accum = 0.0
	_record_time = 0.0
	_frames = []
	_events = []
	_last_live_state = {}
	
	# Fix agent id order for the entire match recording.
	_set_agent_ids_for_session(agents)
	_rebind_agents(agents)
	
	# Build agent metadata (team_id, role) for each agent
	var agent_meta: Dictionary = {}
	for a in agents:
		if a == null:
			continue
		var aid: String = ""
		if "id" in a:
			aid = str(a.id)
		if aid == "":
			aid = str(a.name)
		
		var team_id: int = 0
		if "team" in a and a.team != null:
			team_id = int(a.team.id) if "id" in a.team else 0
		
		var role: int = 0
		if "role" in a:
			role = int(a.role)
		
		agent_meta[aid] = {"team_id": team_id, "role": role}
	
	_data = {
		"version": 2,  # New version with improved event system
		"tick_rate": record_tick_rate,
		"mode": mode_type,
		"selected_map": MatchConfig.selected_map,  # Save map path for replay
		"settings": {
			"agent_fov_index": int(SettingsManager.get_agent_fov_index()),
			"agent_los_index": int(SettingsManager.get_agent_los_index()),
			"agent_speed_index": int(SettingsManager.get_agent_speed_index()),
			"round_duration_index": int(SettingsManager.get_rounds_duration_index()),
			"round_number_index": int(SettingsManager.get_rounds_number_index()),
		},
		"agent_ids": _agent_ids,
		"agent_meta": agent_meta,  # New: stores team_id and role per agent
		"frames": _frames,
		"events": _events,
		"created_at_unix": int(Time.get_unix_time_from_system()),
	}
	
	# Record initial round start
	record_round_start(1)
	
	print("[Replay] Started recording: %d agents, mode=%d" % [agents.size(), mode_type])

func set_recording_agents(agents: Array) -> void:
	## Call this after a round reset that respawns agents.
	if _state != ReplayState.RECORDING:
		return
	# Keep existing _agent_ids, just rebind to new agent nodes
	_rebind_agents(agents)

func rebind_single_agent(agent) -> void:
	## Call when a single agent respawns to update its reference in the recording.
	if _state != ReplayState.RECORDING:
		return
	if agent == null:
		return
	
	var aid: String = ""
	if "id" in agent:
		aid = str(agent.id)
	if aid == "":
		aid = str(agent.name)
	
	# Find the index for this agent ID and update the reference
	_agents_by_id[aid] = agent
	for i in range(_agent_ids.size()):
		if _agent_ids[i] == aid:
			_agents[i] = agent
			break

func end_recording(save: bool = true) -> void:
	if _state != ReplayState.RECORDING:
		return
	_state = ReplayState.IDLE
	if save:
		_save_last(_data)
		print("[Replay] Saved recording: %d frames, %d events" % [_frames.size(), _events.size()])

## ===== EVENT RECORDING =====

func record_shot(shooter_id: String, muzzle_pos: Vector2, fire_dir: Vector2) -> void:
	## Called by Agent when it fires.
	if _state != ReplayState.RECORDING:
		return
	var t: float = _get_current_time()
	_events.append({
		"t": t,
		"type": "shot",
		"id": shooter_id,
		"x": float(muzzle_pos.x),
		"y": float(muzzle_pos.y),
		"dx": float(fire_dir.x),
		"dy": float(fire_dir.y),
	})

func record_score_change(scoreA: int, scoreB: int) -> void:
	## Called when the score changes.
	if _state != ReplayState.RECORDING:
		return
	var t: float = _get_current_time()
	_events.append({
		"t": t,
		"type": "score_change",
		"scoreA": scoreA,
		"scoreB": scoreB,
	})

func record_round_start(round_num: int) -> void:
	## Called at the start of each round.
	if _state != ReplayState.RECORDING:
		return
	var t: float = _get_current_time()
	_events.append({
		"t": t,
		"type": "round_start",
		"round": round_num,
	})

func record_round_end(winner: int, scoreA: int, scoreB: int) -> void:
	## Called at the end of each round.
	if _state != ReplayState.RECORDING:
		return
	var t: float = _get_current_time()
	_events.append({
		"t": t,
		"type": "round_end",
		"winner": winner,
		"scoreA": scoreA,
		"scoreB": scoreB,
	})

func record_agent_death(agent_id: String) -> void:
	## Called when an agent dies.
	if _state != ReplayState.RECORDING:
		return
	var t: float = _get_current_time()
	_events.append({
		"t": t,
		"type": "agent_death",
		"id": agent_id,
	})

func record_agent_spawn(agent_id: String, pos: Vector2) -> void:
	## Called when an agent spawns/respawns.
	if _state != ReplayState.RECORDING:
		return
	var t: float = _get_current_time()
	_events.append({
		"t": t,
		"type": "agent_spawn",
		"id": agent_id,
		"x": float(pos.x),
		"y": float(pos.y),
	})

## ===== CTF MODE EVENTS =====

func record_flag_pickup(flag_team_id: int, carrier_id: String) -> void:
	## Called when an agent picks up a flag.
	if _state != ReplayState.RECORDING:
		return
	var t: float = _get_current_time()
	_events.append({
		"t": t,
		"type": "flag_pickup",
		"flag_team": flag_team_id,
		"carrier": carrier_id,
	})

func record_flag_drop(flag_team_id: int, pos: Vector2) -> void:
	## Called when a flag is dropped.
	if _state != ReplayState.RECORDING:
		return
	var t: float = _get_current_time()
	_events.append({
		"t": t,
		"type": "flag_drop",
		"flag_team": flag_team_id,
		"x": float(pos.x),
		"y": float(pos.y),
	})

func record_flag_return(flag_team_id: int) -> void:
	## Called when a flag returns to base.
	if _state != ReplayState.RECORDING:
		return
	var t: float = _get_current_time()
	_events.append({
		"t": t,
		"type": "flag_return",
		"flag_team": flag_team_id,
	})

func record_flag_capture(flag_team_id: int, capturer_id: String) -> void:
	## Called when a flag is captured (delivered to base).
	if _state != ReplayState.RECORDING:
		return
	var t: float = _get_current_time()
	_events.append({
		"t": t,
		"type": "flag_capture",
		"flag_team": flag_team_id,
		"capturer": capturer_id,
	})

## ===== INTERNAL =====

func _get_current_time() -> float:
	return _record_time + _record_accum

func _process(delta: float) -> void:
	if _state == ReplayState.RECORDING:
		# Don't advance recording time or record frames while the game is paused
		if get_tree().paused:
			return
			
		_record_accum += delta
		while _record_accum >= _record_dt:
			_record_accum -= _record_dt
			_record_time += _record_dt
			_record_frame(_record_time)

func _record_frame(t: float) -> void:
	var arr: Array = []
	for id_i in range(_agent_ids.size()):
		var aid: String = _agent_ids[id_i]
		var a = _agents[id_i]

		# Default to last known live state
		var prev: Dictionary = _last_live_state.get(aid, {})
		var x: float = float(prev.get("x", 0.0))
		var y: float = float(prev.get("y", 0.0))
		var rot: float = float(prev.get("rot", 0.0))
		var hp: int = int(prev.get("hp", 0))
		var ammo: int = int(prev.get("ammo", 0))
		var alive: bool = bool(prev.get("alive", false))

		if a != null and is_instance_valid(a):
			var cur_alive := true
			if "is_alive" in a:
				cur_alive = bool(a.is_alive())
			var cur_hp: int = int(a.hp) if "hp" in a else hp
			var cur_ammo: int = int(a.ammo) if "ammo" in a else ammo

			if cur_alive:
				x = float(a.global_position.x)
				y = float(a.global_position.y)
				if (a as Node).has_node("Skin"):
					var s := (a as Node).get_node("Skin")
					if s is Node2D:
						rot = float((s as Node2D).rotation)
					else:
						rot = float(a.rotation)
				else:
					rot = float(a.rotation)
				_last_live_state[aid] = {"x": x, "y": y, "rot": rot, "hp": cur_hp, "ammo": cur_ammo, "alive": true}
			hp = cur_hp
			ammo = cur_ammo
			alive = cur_alive
		else:
			alive = false

		arr.append({"x": x, "y": y, "rot": rot, "hp": hp, "ammo": ammo, "alive": alive})

	_frames.append({"t": t, "a": arr})

func _set_agent_ids_for_session(agents: Array) -> void:
	_agent_ids = []
	for a in agents:
		if a == null:
			continue
		var aid: String = ""
		if "id" in a:
			aid = str(a.id)
		if aid == "":
			aid = str(a.name)
		_agent_ids.append(aid)
	_agent_ids.sort()

func _rebind_agents(agents: Array) -> void:
	_agents_by_id = {}
	for a in agents:
		if a == null:
			continue
		var aid: String = ""
		if "id" in a:
			aid = str(a.id)
		if aid == "":
			aid = str(a.name)
		_agents_by_id[aid] = a

	_agents = []
	for aid in _agent_ids:
		_agents.append(_agents_by_id.get(aid, null))

func _load_last() -> Dictionary:
	if not FileAccess.file_exists(LAST_REPLAY_PATH):
		return {}
	var f := FileAccess.open(LAST_REPLAY_PATH, FileAccess.READ)
	if f == null or f.get_length() <= 0:
		return {}
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data as Dictionary

func _save_last(meta: Dictionary) -> void:
	var f := FileAccess.open(LAST_REPLAY_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(meta))
