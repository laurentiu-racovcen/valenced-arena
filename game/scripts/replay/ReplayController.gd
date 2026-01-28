extends Node
class_name ReplayController
## Handles replay playback in ReplayMatch scene.
## Loads data from ReplayManager autoload and controls puppet agents.

signal playback_started
signal playback_paused
signal playback_resumed
signal playback_finished
signal time_changed(current: float, total: float)
signal score_changed(scoreA: int, scoreB: int)
signal round_started(round_num: int)
signal round_ended(winner: int, scoreA: int, scoreB: int)

const PUPPET_SCENE := preload("res://scenes/replay/PuppetAgent.tscn")

@export var playback_speed: float = 1.0

var _data: Dictionary = {}
var _frames: Array = []
var _events: Array = []
var _agent_ids: Array = []

var _puppets: Dictionary = {}  # agent_id -> PuppetAgent

var _is_playing: bool = false
var _is_paused: bool = false
var _play_time: float = 0.0
var _play_idx: int = 0
var _event_idx: int = 0
var _total_duration: float = 0.0

var _scoreA: int = 0
var _scoreB: int = 0

var _replay_bullets: Array = []  # Track spawned bullets to pause/resume them

@onready var agents_root: Node2D = get_parent().get_node_or_null("AgentsRoot")

func _ready() -> void:
	_load_replay_data()

func _load_replay_data() -> void:
	## Load replay data from ReplayManager autoload
	if not get_tree().root.has_node("Replay"):
		push_error("[ReplayController] Replay autoload not found!")
		return
	
	var replay := get_tree().root.get_node("Replay")
	
	# Access the data from the autoload
	if not replay.has_method("get_replay_data"):
		# Fallback: access internal _data directly (for backwards compatibility)
		if "_data" in replay:
			_data = replay._data
		else:
			push_error("[ReplayController] Cannot access replay data!")
			return
	else:
		_data = replay.get_replay_data()
	
	if _data.is_empty():
		push_error("[ReplayController] Replay data is empty!")
		return
	
	_frames = _data.get("frames", []) as Array
	_events = _data.get("events", []) as Array
	_agent_ids = _data.get("agent_ids", []) as Array
	
	if _frames.is_empty():
		push_error("[ReplayController] No frames in replay!")
		return
	
	_total_duration = float((_frames[_frames.size() - 1] as Dictionary).get("t", 0.0))
	
	print("[ReplayController] Loaded replay: %d frames, %d events, %.1fs duration" % [
		_frames.size(), _events.size(), _total_duration
	])
	
	# Clear pending flag so new matches don't try to replay
	if replay.has_method("clear_pending"):
		replay.call("clear_pending")
	
	_spawn_puppets()
	_start_playback()

func _spawn_puppets() -> void:
	## Spawn puppet agents based on agent_ids from replay data
	if agents_root == null:
		push_error("[ReplayController] AgentsRoot not found!")
		return
	
	# Clear any existing puppets
	for child in agents_root.get_children():
		child.queue_free()
	_puppets.clear()
	
	# Get agent metadata from replay data
	var agent_meta: Dictionary = _data.get("agent_meta", {}) as Dictionary
	
	# Spawn puppets for each agent
	for agent_id in _agent_ids:
		var id_str := str(agent_id)
		
		# Get team and role from recorded metadata
		var meta: Dictionary = agent_meta.get(id_str, {}) as Dictionary
		var team_id: int = int(meta.get("team_id", 0))
		var role: int = int(meta.get("role", 0))
		
		# Fallback: parse from ID format "T{team_id}_{index}" if no metadata
		if meta.is_empty() and id_str.begins_with("T"):
			var parts := id_str.substr(1).split("_")
			if parts.size() >= 2:
				team_id = int(parts[0])
				role = _get_role_for_index(int(parts[1]))
		
		var puppet := PUPPET_SCENE.instantiate() as PuppetAgent
		agents_root.add_child(puppet)
		
		# Setup puppet with team and role from metadata
		puppet.setup(id_str, team_id, role)
		
		_puppets[id_str] = puppet
		
		print("[ReplayController] Spawned puppet: %s (team=%d, role=%d)" % [id_str, team_id, role])
	
	# Apply initial frame to position puppets
	if not _frames.is_empty():
		_apply_frame(0)

func _get_role_for_index(index: int) -> int:
	# Match the role assignment logic from GameManager
	# Usually: 0=Leader, 1=Advance, 2=Tank, 3=Support
	match index:
		0: return 0  # Leader
		1: return 1  # Advance
		2: return 2  # Tank
		3: return 3  # Support
		_: return 1  # Default to Advance

func _start_playback() -> void:
	_is_playing = true
	_is_paused = false
	_play_time = 0.0
	_play_idx = 0
	_event_idx = 0
	_scoreA = 0
	_scoreB = 0
	
	playback_started.emit()
	score_changed.emit(_scoreA, _scoreB)
	set_process(true)

func pause() -> void:
	_is_paused = true
	_set_bullets_paused(true)
	playback_paused.emit()

func resume() -> void:
	_is_paused = false
	_set_bullets_paused(false)
	playback_resumed.emit()

func toggle_pause() -> void:
	if _is_paused:
		resume()
	else:
		pause()

func seek(time: float) -> void:
	## Seek to a specific time in the replay
	_play_time = clampf(time, 0.0, _total_duration)
	
	# Clear all existing bullets when seeking
	_clear_bullets()
	
	# Reset frame index
	_play_idx = 0
	while _play_idx < _frames.size() - 1:
		var next_t := float((_frames[_play_idx + 1] as Dictionary).get("t", 0.0))
		if next_t > _play_time:
			break
		_play_idx += 1
	
	# Reset event index (re-process events up to current time, but skip bullets)
	_event_idx = 0
	_scoreA = 0
	_scoreB = 0
	_process_events_up_to(_play_time, true)  # skip_bullets = true
	
	# Apply the current frame immediately so the user sees the update
	_apply_interpolated_frame()
	
	time_changed.emit(_play_time, _total_duration)

func set_speed(speed: float) -> void:
	playback_speed = clampf(speed, 0.25, 4.0)

func get_playback_time() -> float:
	return _play_time

func get_total_duration() -> float:
	return _total_duration

func is_playing() -> bool:
	return _is_playing and not _is_paused

func _process(delta: float) -> void:
	if not _is_playing or _is_paused:
		return
	
	# Advance playback time
	_play_time += delta * playback_speed
	
	# Process events up to current time
	_process_events()
	
	# Update frame index
	while _play_idx < _frames.size() - 2:
		var next_t := float((_frames[_play_idx + 1] as Dictionary).get("t", 0.0))
		if next_t > _play_time:
			break
		_play_idx += 1
	
	# Apply interpolated frame
	_apply_interpolated_frame()
	
	# Emit time update
	time_changed.emit(_play_time, _total_duration)
	
	# Check if playback finished
	if _play_time >= _total_duration + 0.5:
		_finish_playback()

func _apply_frame(frame_idx: int) -> void:
	## Apply a single frame without interpolation
	if frame_idx < 0 or frame_idx >= _frames.size():
		return
	
	var frame: Dictionary = _frames[frame_idx] as Dictionary
	var agents_data: Array = frame.get("a", []) as Array
	
	for i in range(min(_agent_ids.size(), agents_data.size())):
		var aid: String = str(_agent_ids[i])
		var puppet: PuppetAgent = _puppets.get(aid) as PuppetAgent
		if puppet == null:
			continue
		
		var state: Dictionary = agents_data[i] as Dictionary
		puppet.apply_state(
			float(state.get("x", 0.0)),
			float(state.get("y", 0.0)),
			float(state.get("rot", 0.0)),
			int(state.get("hp", 100)),
			int(state.get("ammo", 30)),
			bool(state.get("alive", true))
		)

func _apply_interpolated_frame() -> void:
	## Apply frames with linear interpolation for smooth movement
	if _frames.is_empty():
		return
	
	var f0: Dictionary = _frames[_play_idx] as Dictionary
	var f1: Dictionary = _frames[min(_play_idx + 1, _frames.size() - 1)] as Dictionary
	
	var t0: float = float(f0.get("t", 0.0))
	var t1: float = float(f1.get("t", t0 + 0.001))
	var alpha: float = 0.0
	if t1 > t0:
		alpha = clampf((_play_time - t0) / (t1 - t0), 0.0, 1.0)
	
	var a0: Array = f0.get("a", []) as Array
	var a1: Array = f1.get("a", []) as Array
	
	for i in range(min(_agent_ids.size(), a0.size(), a1.size())):
		var aid: String = str(_agent_ids[i])
		var puppet: PuppetAgent = _puppets.get(aid) as PuppetAgent
		if puppet == null:
			continue
		
		var s0: Dictionary = a0[i] as Dictionary
		var s1: Dictionary = a1[i] as Dictionary
		
		# Interpolate position
		var p0 := Vector2(float(s0.get("x", 0.0)), float(s0.get("y", 0.0)))
		var p1 := Vector2(float(s1.get("x", 0.0)), float(s1.get("y", 0.0)))
		var pos := p0.lerp(p1, alpha)
		
		# Interpolate rotation
		var r0: float = float(s0.get("rot", 0.0))
		var r1: float = float(s1.get("rot", r0))
		var rot: float = lerp_angle(r0, r1, alpha)
		
		# Use state from f0 for discrete values (hp, ammo, alive)
		puppet.apply_state(
			pos.x,
			pos.y,
			rot,
			int(s0.get("hp", 100)),
			int(s0.get("ammo", 30)),
			bool(s0.get("alive", true))
		)

func _process_events() -> void:
	## Process events up to current playback time
	while _event_idx < _events.size():
		var e: Dictionary = _events[_event_idx] as Dictionary
		var et: float = float(e.get("t", 0.0))
		if et > _play_time:
			break
		
		_event_idx += 1
		_handle_event(e)

func _process_events_up_to(time: float, skip_bullets: bool = false) -> void:
	## Re-process all events up to the given time (for seeking)
	## If skip_bullets is true, don't spawn bullets (avoids spam when scrubbing)
	var idx := 0
	while idx < _events.size():
		var e: Dictionary = _events[idx] as Dictionary
		var et: float = float(e.get("t", 0.0))
		if et > time:
			break
		idx += 1
		_handle_event(e, skip_bullets)
	_event_idx = idx

func _handle_event(e: Dictionary, skip_bullets: bool = false) -> void:
	## Handle a single replay event
	var event_type := str(e.get("type", ""))
	
	match event_type:
		"shot":
			if not skip_bullets:
				_spawn_bullet(e)
		"score_change":
			_scoreA = int(e.get("scoreA", _scoreA))
			_scoreB = int(e.get("scoreB", _scoreB))
			score_changed.emit(_scoreA, _scoreB)
		"round_start":
			var round_num := int(e.get("round", 1))
			print("[Replay] Round %d started" % round_num)
			if not skip_bullets:  # Only show announcement during normal playback
				round_started.emit(round_num)
		"round_end":
			var winner := int(e.get("winner", -1))
			var sa := int(e.get("scoreA", _scoreA))
			var sb := int(e.get("scoreB", _scoreB))
			print("[Replay] Round ended, winner: %d" % winner)
			if not skip_bullets:  # Only show announcement during normal playback
				round_ended.emit(winner, sa, sb)
		"agent_spawn":
			_handle_agent_spawn(e)
		"agent_death":
			_handle_agent_death(e)

func _spawn_bullet(e: Dictionary) -> void:
	## Spawn a visual-only bullet for replay
	var from_pos := Vector2(float(e.get("x", 0.0)), float(e.get("y", 0.0)))
	var dir := Vector2(float(e.get("dx", 0.0)), float(e.get("dy", 0.0)))
	
	if dir.length() < 0.01:
		return
	
	var bullet_scene := preload("res://scenes/bullets/Bullet.tscn")
	var bullet := bullet_scene.instantiate() as Node2D
	bullet.global_position = from_pos
	
	# Set bullet properties (it should have direction property)
	if "direction" in bullet:
		bullet.direction = dir.normalized()
	if "damage" in bullet:
		bullet.damage = 0  # No damage in replay
	if "shooter" in bullet:
		bullet.shooter = null
	
	get_tree().current_scene.add_child(bullet)
	
	# Track bullet for pause/resume
	_replay_bullets.append(bullet)
	
	# If paused, pause the bullet immediately
	if _is_paused:
		bullet.set_physics_process(false)

func _set_bullets_paused(paused: bool) -> void:
	## Pause or resume all tracked bullets
	for bullet in _replay_bullets:
		if is_instance_valid(bullet):
			bullet.set_physics_process(not paused)
	# Clean up freed bullets
	_replay_bullets = _replay_bullets.filter(func(b): return is_instance_valid(b))

func _clear_bullets() -> void:
	## Remove all tracked bullets
	for bullet in _replay_bullets:
		if is_instance_valid(bullet):
			bullet.queue_free()
	_replay_bullets.clear()

func _handle_agent_spawn(e: Dictionary) -> void:
	## Handle respawn event (make puppet visible again)
	var aid := str(e.get("id", ""))
	var puppet: PuppetAgent = _puppets.get(aid) as PuppetAgent
	if puppet:
		puppet.visible = true
		var x := float(e.get("x", puppet.global_position.x))
		var y := float(e.get("y", puppet.global_position.y))
		puppet.global_position = Vector2(x, y)
		puppet.hp = puppet.max_hp
		print("[Replay] Agent %s respawned at (%.0f, %.0f)" % [aid, x, y])

func _handle_agent_death(e: Dictionary) -> void:
	## Handle death event (hide puppet)
	var aid := str(e.get("id", ""))
	var puppet: PuppetAgent = _puppets.get(aid) as PuppetAgent
	if puppet:
		puppet.visible = false
		print("[Replay] Agent %s died" % aid)

func _finish_playback() -> void:
	_is_playing = false
	set_process(false)
	playback_finished.emit()
	
	# Reset replay state in ReplayManager
	if get_tree().root.has_node("Replay"):
		var replay := get_tree().root.get_node("Replay")
		if replay != null and replay.has_method("end_playback"):
			replay.call("end_playback")
	
	print("[ReplayController] Playback finished!")

func exit_to_menu() -> void:
	## Clean up and return to the menu
	_is_playing = false
	set_process(false)
	
	# Reset replay state in ReplayManager
	if get_tree().root.has_node("Replay"):
		var replay := get_tree().root.get_node("Replay")
		if replay != null and replay.has_method("end_playback"):
			replay.call("end_playback")
	
	# Clean up any remaining bullets
	for child in get_tree().current_scene.get_children():
		if child.is_in_group("bullets") or child.get_class() == "Bullet":
			child.queue_free()
	
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")

