extends Node
## Autoload singleton (project.godot): `Replay="*res://scripts/stats/ReplayManager.gd"`
##
## Recorded replay approach:
## - During a match, record agent state snapshots at a fixed tick rate (e.g. 15 Hz).
## - Save to `user://last_replay.json`.
## - Replay button loads this file and starts Match.tscn in "playback" mode.
## - In playback mode, AI is disabled and we apply recorded positions/rotations/state.

const LAST_REPLAY_PATH := "user://last_replay.json"

@export var record_tick_rate: float = 15.0

enum ReplayState { IDLE, RECORDING, PLAYBACK }
var _state: int = ReplayState.IDLE
signal playback_finished

var _record_dt: float = 0.0
var _record_accum: float = 0.0
var _record_time: float = 0.0

var _agent_ids: Array[String] = []
var _agents: Array = [] # [Agent] but keep untyped to avoid parse issues
var _agents_by_id: Dictionary = {} # id -> Agent (for rebinding across rounds)

var _data: Dictionary = {}
var _frames: Array = [] # array of {t: float, a: Array[Dictionary]}
var _events: Array = [] # array of {t: float, type: String, ...}
var _last_live_state: Dictionary = {} # agent_id -> {x,y,rot,hp,ammo,alive}

var _pending_playback: bool = false
var _play_idx: int = 0
var _play_time: float = 0.0
var _play_agents_by_id: Dictionary = {} # id -> Agent
var _event_idx: int = 0

func _ready() -> void:
	# Ensure the autoload keeps processing even if scenes pause the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

func _unhandled_input(event: InputEvent) -> void:
	# Allow exiting replay with Esc / ui_cancel.
	if _state == ReplayState.PLAYBACK and event.is_action_pressed("ui_cancel"):
		_exit_playback_to_menu()

func has_last_replay() -> bool:
	return FileAccess.file_exists(LAST_REPLAY_PATH)

func is_playback_pending() -> bool:
	return _pending_playback

func is_recording() -> bool:
	return _state == ReplayState.RECORDING

func is_playing() -> bool:
	return _state == ReplayState.PLAYBACK

func get_playback_time() -> float:
	return _play_time

func get_total_duration() -> float:
	if _frames.is_empty():
		return 0.0
	return float((_frames[_frames.size() - 1] as Dictionary).get("t", 0.0))

func get_mode_type() -> int:
	return int(_data.get("mode", 0))

func request_replay_last() -> void:
	# Called from the menu replay button.
	var loaded := _load_last()
	if loaded.is_empty():
		get_tree().change_scene_to_file("res://scenes/Match.tscn")
		return
	_data = loaded
	_frames = _data.get("frames", []) as Array
	_events = _data.get("events", []) as Array
	_pending_playback = true
	get_tree().change_scene_to_file("res://scenes/Match.tscn")

func begin_recording(agents: Array, mode_type: int) -> void:
	_state = ReplayState.RECORDING
	_pending_playback = false
	_record_dt = 1.0 / max(record_tick_rate, 1.0)
	_record_accum = 0.0
	_record_time = 0.0
	_frames = []
	_events = []
	_last_live_state = {}
	# IMPORTANT: Fix agent id order for the entire match recording.
	_set_agent_ids_for_session(agents)
	_rebind_agents(agents)

	_data = {
		"version": 1,
		"tick_rate": record_tick_rate,
		"mode": mode_type,
		"settings": {
			"agent_fov_index": int(SettingsManager.get_agent_fov_index()),
			"agent_los_index": int(SettingsManager.get_agent_los_index()),
			"agent_speed_index": int(SettingsManager.get_agent_speed_index()),
			"round_duration_index": int(SettingsManager.get_rounds_duration_index()),
			"round_number_index": int(SettingsManager.get_rounds_number_index()),
		},
		"agent_ids": _agent_ids,
		"frames": _frames,
		"events": _events,
		"created_at_unix": int(Time.get_unix_time_from_system()),
	}

func record_shot(shooter_id: String, muzzle_pos: Vector2, fire_dir: Vector2) -> void:
	# Called by Agent when it fires (only recorded during RECORDING).
	if _state != ReplayState.RECORDING:
		return
	var t: float = _record_time + _record_accum
	_events.append({
		"t": t,
		"type": "shot",
		"id": shooter_id,
		"x": float(muzzle_pos.x),
		"y": float(muzzle_pos.y),
		"dx": float(fire_dir.x),
		"dy": float(fire_dir.y),
	})

func set_recording_agents(agents: Array) -> void:
	# Call this after a round reset that respawns agents.
	if _state != ReplayState.RECORDING:
		return
	# DO NOT change `_agent_ids` mid-recording (it corrupts older frames).
	# Only rebind the newly spawned Agent nodes to the existing id order.
	_rebind_agents(agents)

func end_recording(save: bool = true) -> void:
	if _state != ReplayState.RECORDING:
		return
	_state = ReplayState.IDLE
	if save:
		_save_last(_data)

func begin_playback(agents: Array) -> void:
	# Called by GameManager after agents are spawned.
	_pending_playback = false
	_state = ReplayState.PLAYBACK
	_play_idx = 0
	_play_time = 0.0
	_event_idx = 0
	_play_agents_by_id = {}

	# Map current scene agents by their stable id
	for a in agents:
		if a == null:
			continue
		var aid: String = ""
		if "id" in a:
			aid = str(a.id)
		if aid == "":
			aid = str(a.name)
		_play_agents_by_id[aid] = a

	# Disable AI + movement so we can puppet transforms.
	for a in agents:
		if a == null:
			continue
		if a is Node:
			(a as Node).set_process(false)
			(a as Node).set_physics_process(false)
		# Also disable role logic node if present
		if "role_logic" in a and a.role_logic != null:
			(a.role_logic as Node).set_process(false)
			(a.role_logic as Node).set_physics_process(false)
		# Freeze velocity if available
		if "velocity" in a:
			a.velocity = Vector2.ZERO

func _process(delta: float) -> void:
	if _state == ReplayState.RECORDING:
		_record_accum += delta
		while _record_accum >= _record_dt:
			_record_accum -= _record_dt
			_record_time += _record_dt
			_record_frame(_record_time)
	elif _state == ReplayState.PLAYBACK:
		# Respect pause state during playback (like normal gameplay)
		if get_tree().paused:
			return
		_update_playback(delta)

func _record_frame(t: float) -> void:
	var arr: Array = []
	for id_i in range(_agent_ids.size()):
		var aid: String = _agent_ids[id_i]
		var a = _agents[id_i]

		# Default to last known live state to avoid teleporting to (0,0) after the node is freed.
		var prev: Dictionary = _last_live_state.get(aid, {})
		var x: float = float(prev.get("x", 0.0))
		var y: float = float(prev.get("y", 0.0))
		var rot: float = float(prev.get("rot", 0.0))
		var hp: int = int(prev.get("hp", 0))
		var ammo: int = int(prev.get("ammo", 0))
		var alive: bool = bool(prev.get("alive", false))

		if a != null and is_instance_valid(a):
			# Read current state
			var cur_alive := true
			if "is_alive" in a:
				cur_alive = bool(a.is_alive())
			var cur_hp: int = int(a.hp) if "hp" in a else hp
			var cur_ammo: int = int(a.ammo) if "ammo" in a else ammo

			# If alive, update pose; if dead, freeze at last live pose.
			if cur_alive:
				x = float(a.global_position.x)
				y = float(a.global_position.y)
				# Prefer Skin rotation for visuals if present
				if (a as Node).has_node("Skin"):
					var s := (a as Node).get_node("Skin")
					if s is Node2D:
						rot = float((s as Node2D).rotation)
					else:
						rot = float(a.rotation)
				else:
					rot = float(a.rotation)
				_last_live_state[aid] = {"x": x, "y": y, "rot": rot, "hp": cur_hp, "ammo": cur_ammo, "alive": true}
			# Always update hp/ammo/alive flags
			hp = cur_hp
			ammo = cur_ammo
			alive = cur_alive
		else:
			# Node missing this tick (freed). Keep frozen last pose, mark dead.
			alive = false

		arr.append({"x": x, "y": y, "rot": rot, "hp": hp, "ammo": ammo, "alive": alive})

	_frames.append({"t": t, "a": arr})

func _update_playback(delta: float) -> void:
	if _frames.is_empty():
		_state = ReplayState.IDLE
		return

	_play_time += delta

	# Spawn events up to current playback time.
	_process_events()

	# Clamp index to last-1 so we can interpolate with next
	while _play_idx < _frames.size() - 2 and float((_frames[_play_idx + 1] as Dictionary).get("t", 0.0)) <= _play_time:
		_play_idx += 1

	var f0: Dictionary = _frames[_play_idx] as Dictionary
	var f1: Dictionary = _frames[min(_play_idx + 1, _frames.size() - 1)] as Dictionary
	var t0: float = float(f0.get("t", 0.0))
	var t1: float = float(f1.get("t", t0 + 0.0001))
	var alpha: float = 0.0 if t1 <= t0 else clamp((_play_time - t0) / (t1 - t0), 0.0, 1.0)

	var a0: Array = f0.get("a", []) as Array
	var a1: Array = f1.get("a", []) as Array
	var ids: Array = _data.get("agent_ids", []) as Array

	for i in range(min(ids.size(), a0.size(), a1.size())):
		var aid: String = str(ids[i])
		var agent = _play_agents_by_id.get(aid, null)
		if agent == null or not is_instance_valid(agent):
			continue
		var s0: Dictionary = a0[i] as Dictionary
		var s1: Dictionary = a1[i] as Dictionary

		var p0 := Vector2(float(s0.get("x", 0.0)), float(s0.get("y", 0.0)))
		var p1 := Vector2(float(s1.get("x", 0.0)), float(s1.get("y", 0.0)))
		agent.global_position = p0.lerp(p1, alpha)

		# Visual rotation on Skin if present
		var r0: float = float(s0.get("rot", 0.0))
		var r1: float = float(s1.get("rot", r0))
		if (agent as Node).has_node("Skin"):
			var skin := (agent as Node).get_node("Skin")
			if skin is Node2D:
				var r: float = lerp_angle(r0, r1, alpha)
				(skin as Node2D).rotation = r
				# Update aim/move dirs so FOV uses correct facing (aim_dir has priority).
				if "aim_dir" in agent:
					agent.aim_dir = Vector2(cos(r), sin(r))
				if "move_dir" in agent and ("aim_dir" in agent):
					agent.move_dir = agent.aim_dir
		# Force redraw so FOV overlay follows rotation even with agent processing disabled.
		if "debug_draw_fov" in agent and agent.debug_draw_fov:
			(agent as CanvasItem).queue_redraw()

		# Optional state
		if "hp" in agent:
			agent.hp = int(s0.get("hp", agent.hp))
		if "ammo" in agent:
			agent.ammo = int(s0.get("ammo", agent.ammo))

		# Hide dead agents (prevents confusing "teleport to corner" visuals).
		var alive0: bool = bool(s0.get("alive", true))
		(agent as CanvasItem).visible = alive0

	# End of replay: stop at last frame
	var last_t: float = float((_frames[_frames.size() - 1] as Dictionary).get("t", 0.0))
	if _play_time >= last_t + 0.25:
		_state = ReplayState.IDLE
		playback_finished.emit()
		_exit_playback_to_menu()

func _process_events() -> void:
	if _events.is_empty():
		return
	# events are in chronological order
	while _event_idx < _events.size():
		var e: Dictionary = _events[_event_idx] as Dictionary
		var et: float = float(e.get("t", 0.0))
		if et > _play_time:
			break
		_event_idx += 1

		if str(e.get("type", "")) == "shot":
			_spawn_replay_bullet(e)

func _spawn_replay_bullet(e: Dictionary) -> void:
	var from_pos := Vector2(float(e.get("x", 0.0)), float(e.get("y", 0.0)))
	var dir := Vector2(float(e.get("dx", 0.0)), float(e.get("dy", 0.0)))
	if dir.length() < 0.01:
		return
	var ps := preload("res://scenes/bullets/Bullet.tscn")
	var b := ps.instantiate() as Bullet
	b.global_position = from_pos
	b.direction = dir.normalized()
	# Visual-only: no damage/side effects (agents are puppeted by snapshots).
	b.damage = 0
	b.shooter = null
	get_tree().current_scene.add_child(b)

func _exit_playback_to_menu() -> void:
	if get_tree() == null:
		return
	_cleanup_overlay_nodes()
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")

func _cleanup_overlay_nodes() -> void:
	# ScoreHUD is added to the root during matches; clean it up before returning to menu.
	var root := get_tree().root
	if root == null:
		return
	for c in root.get_children():
		if c == null:
			continue
		# Remove ScoreHUD (CanvasLayer named ScoreHud), RoundCountdown, and CTF HUD
		if (c is CanvasLayer and (c as Node).name == "ScoreHud") or (c as Node).name == "RoundCountdown":
			(c as Node).queue_free()
		# Remove CTF HUD (it's a CanvasLayer added to root)
		if c is CanvasLayer and (c as Node).name.begins_with("CtfHUD"):
			(c as Node).queue_free()
	
	# Also clean up any bullets and flags in the current scene
	var current_scene := get_tree().current_scene
	if current_scene != null:
		for child in current_scene.get_children():
			if child is Bullet:
				child.queue_free()
			# Clean up flags
			if child.is_in_group("flags"):
				child.queue_free()

func _set_agents_for_session(agents: Array) -> void:
	# Backwards compatibility (should not be used by recording anymore).
	_set_agent_ids_for_session(agents)
	_rebind_agents(agents)

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
	# Keep deterministic order across runs/rounds.
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

	# Rebuild `_agents` aligned to `_agent_ids` so frame arrays keep the same indexing forever.
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
