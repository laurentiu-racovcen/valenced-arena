extends CanvasLayer
class_name ScoreHUD

@onready var rtl: RichTextLabel = RichTextLabel.new()
@onready var ui_font: FontFile = preload("res://fonts/PixelifySans-Bold.ttf")

var _score_a: int = 0
var _score_b: int = 0
var _elapsed_time: float = 0.0  # Current round elapsed time
var _total_match_time: float = 0.0  # Total match time (all rounds combined)
var _match_running: bool = true
var _is_replay_mode: bool = false

func _ready() -> void:
	_setup_rtl()
	_elapsed_time = 0.0
	_total_match_time = 0.0
	
	# Check if we're in replay mode
	if get_tree().root.has_node("Replay"):
		var replay = get_tree().root.get_node("Replay")
		if replay and replay.has_method("is_playing") and replay.call("is_playing"):
			_is_replay_mode = true
	
	set_score(0, 0)

func _process(delta: float) -> void:
	if _match_running and not _is_replay_mode:
		_elapsed_time += delta
	_update_display()

func _setup_rtl():
	rtl.size = Vector2(900, 120)
	rtl.anchor_left = 0.5
	rtl.anchor_right = 0.5
	rtl.anchor_top = 0.0
	rtl.anchor_bottom = 0.0
	rtl.position = Vector2(-450, 10)

	# Rich text
	rtl.bbcode_enabled = true
	rtl.scroll_active = false
	rtl.fit_content = false  # keep fixed size for stable layout
	rtl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rtl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Theme overrides (font, size, outline, default color)
	rtl.add_theme_font_override("normal_font", ui_font)
	rtl.add_theme_font_size_override("normal_font_size", 48)
	rtl.add_theme_color_override("default_color", Color("FEBDAE"))
	rtl.add_theme_constant_override("outline_size", 10)
	rtl.add_theme_color_override("font_outline_color", Color.BLACK)

	add_child(rtl)

func _update_display() -> void:
	var elapsed: float = _elapsed_time
	
	# Get time from replay manager if in replay mode
	if _is_replay_mode:
		if get_tree().root.has_node("Replay"):
			var replay = get_tree().root.get_node("Replay")
			if replay and replay.has_method("get_playback_time"):
				elapsed = float(replay.call("get_playback_time"))
	
	var minutes := int(elapsed) / 60
	var seconds := int(elapsed) % 60
	var time_str := "%d:%02d" % [minutes, seconds]
	
	var a_col := "#4aa3ff"
	var b_col := "#ff4a4a"
	rtl.text = "[center]Score: [color=%s]%d[/color] - [color=%s]%d[/color]\n%s[/center]" % [
		a_col, _score_a, b_col, _score_b, time_str
	]

func set_score(a: int, b: int) -> void:
	_score_a = a
	_score_b = b
	_update_display()

func stop_timer() -> void:
	_match_running = false
	# Add current round time to total match time and reset elapsed
	_total_match_time += _elapsed_time
	_elapsed_time = 0.0  # Reset so it's not double counted

func set_replay_mode(enabled: bool) -> void:
	_is_replay_mode = enabled

func reset_timer() -> void:
	_elapsed_time = 0.0
	_match_running = true

func get_total_match_time() -> float:
	# Returns total time (already accumulated) plus current running round time
	return _total_match_time + _elapsed_time
