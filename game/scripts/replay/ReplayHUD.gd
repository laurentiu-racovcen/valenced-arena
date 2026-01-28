extends CanvasLayer
class_name ReplayHUD
## HUD for replay playback showing time, score, and replay indicator.

@onready var info_label: RichTextLabel = RichTextLabel.new()
@onready var controls_container: HBoxContainer = HBoxContainer.new()
@onready var play_pause_btn: Button = Button.new()
@onready var speed_label: Label = Label.new()
@onready var time_slider: HSlider = HSlider.new()
@onready var exit_btn: Button = Button.new()

@onready var ui_font: FontFile = preload("res://fonts/PixelifySans-Bold.ttf")

var _controller: ReplayController = null
var _current_time: float = 0.0
var _total_time: float = 0.0
var _scoreA: int = 0
var _scoreB: int = 0
var _is_paused: bool = false
var _speed: float = 1.0

var _seeking: bool = false

var _announcement_label: RichTextLabel = null
var _announcement_timer: float = 0.0

func _ready() -> void:
	layer = 100  # Above everything
	_setup_ui()
	
	# Connect to controller
	await get_tree().process_frame
	_find_controller()

func _find_controller() -> void:
	var controller := get_tree().current_scene.get_node_or_null("ReplayController")
	if controller is ReplayController:
		_controller = controller as ReplayController
		_controller.time_changed.connect(_on_time_changed)
		_controller.score_changed.connect(_on_score_changed)
		_controller.playback_paused.connect(_on_paused)
		_controller.playback_resumed.connect(_on_resumed)
		_controller.playback_finished.connect(_on_finished)
		_controller.round_started.connect(_on_round_started)
		_controller.round_ended.connect(_on_round_ended)
		_total_time = _controller.get_total_duration()
		time_slider.max_value = _total_time
		_update_display()

func _setup_ui() -> void:
	# Main container
	var main_vbox := VBoxContainer.new()
	main_vbox.anchor_left = 0.0
	main_vbox.anchor_right = 1.0
	main_vbox.anchor_top = 0.0
	main_vbox.anchor_bottom = 0.0
	main_vbox.offset_bottom = 150
	add_child(main_vbox)
	
	# Info label (score, time, replay indicator)
	_setup_info_label()
	main_vbox.add_child(info_label)
	
	# Bottom controls bar
	var bottom_bar := HBoxContainer.new()
	bottom_bar.anchor_left = 0.0
	bottom_bar.anchor_right = 1.0
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.offset_top = -60
	bottom_bar.offset_left = 20
	bottom_bar.offset_right = -20
	bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(bottom_bar)
	
	# Play/Pause button
	play_pause_btn.text = "⏸"
	play_pause_btn.custom_minimum_size = Vector2(50, 40)
	play_pause_btn.add_theme_font_size_override("font_size", 24)
	play_pause_btn.pressed.connect(_on_play_pause_pressed)
	bottom_bar.add_child(play_pause_btn)
	
	# Time slider
	time_slider.custom_minimum_size = Vector2(400, 30)
	time_slider.min_value = 0.0
	time_slider.max_value = 100.0
	time_slider.step = 0.1
	time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_slider.drag_started.connect(_on_slider_drag_started)
	time_slider.drag_ended.connect(_on_slider_drag_ended)
	time_slider.value_changed.connect(_on_slider_value_changed)
	bottom_bar.add_child(time_slider)
	
	# Speed controls
	var speed_down := Button.new()
	speed_down.text = "◀"
	speed_down.custom_minimum_size = Vector2(40, 40)
	speed_down.pressed.connect(_on_speed_down)
	bottom_bar.add_child(speed_down)
	
	speed_label.text = "1.0x"
	speed_label.custom_minimum_size = Vector2(60, 40)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speed_label.add_theme_font_override("font", ui_font)
	speed_label.add_theme_font_size_override("font_size", 20)
	bottom_bar.add_child(speed_label)
	
	var speed_up := Button.new()
	speed_up.text = "▶"
	speed_up.custom_minimum_size = Vector2(40, 40)
	speed_up.pressed.connect(_on_speed_up)
	bottom_bar.add_child(speed_up)
	
	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(20, 0)
	bottom_bar.add_child(spacer)
	
	# Exit button
	exit_btn.text = "Exit Replay"
	exit_btn.custom_minimum_size = Vector2(120, 40)
	exit_btn.add_theme_font_size_override("font_size", 16)
	exit_btn.pressed.connect(_on_exit_pressed)
	bottom_bar.add_child(exit_btn)

func _setup_info_label() -> void:
	info_label.size = Vector2(900, 100)
	info_label.anchor_left = 0.5
	info_label.anchor_right = 0.5
	info_label.position = Vector2(-450, 10)
	
	info_label.bbcode_enabled = true
	info_label.scroll_active = false
	info_label.fit_content = false
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	info_label.add_theme_font_override("normal_font", ui_font)
	info_label.add_theme_font_size_override("normal_font_size", 36)
	info_label.add_theme_color_override("default_color", Color("FEBDAE"))
	info_label.add_theme_constant_override("outline_size", 8)
	info_label.add_theme_color_override("font_outline_color", Color.BLACK)

func _update_display() -> void:
	var minutes := int(_current_time) / 60
	var seconds := int(_current_time) % 60
	var total_min := int(_total_time) / 60
	var total_sec := int(_total_time) % 60
	var time_str := "%d:%02d / %d:%02d" % [minutes, seconds, total_min, total_sec]
	
	var a_col := "#4aa3ff"
	var b_col := "#ff4a4a"
	var replay_col := "#ffcc00"
	
	info_label.text = "[center][color=%s]◉ REPLAY[/color]  |  Score: [color=%s]%d[/color] - [color=%s]%d[/color]  |  %s[/center]" % [
		replay_col, a_col, _scoreA, b_col, _scoreB, time_str
	]
	
	# Update slider (only if not being dragged)
	if not _seeking:
		time_slider.value = _current_time
	
	# Update play/pause button
	play_pause_btn.text = "▶" if _is_paused else "⏸"
	
	# Update speed label
	speed_label.text = "%.1fx" % _speed

func _on_time_changed(current: float, total: float) -> void:
	_current_time = current
	_total_time = total
	time_slider.max_value = total
	_update_display()

func _on_score_changed(scoreA: int, scoreB: int) -> void:
	_scoreA = scoreA
	_scoreB = scoreB
	_update_display()

func _on_paused() -> void:
	_is_paused = true
	_update_display()

func _on_resumed() -> void:
	_is_paused = false
	_update_display()

func _on_finished() -> void:
	_is_paused = true
	play_pause_btn.text = "↺"  # Replay icon
	_update_display()

func _on_play_pause_pressed() -> void:
	if _controller:
		if _current_time >= _total_time:
			# Restart from beginning
			_controller.seek(0.0)
			_controller.resume()
		else:
			_controller.toggle_pause()

func _on_slider_drag_started() -> void:
	_seeking = true
	if _controller:
		_controller.pause()

func _on_slider_drag_ended(_value_changed: bool) -> void:
	_seeking = false
	if _controller:
		_controller.seek(time_slider.value)
		# Don't auto-resume, let user click play

func _on_slider_value_changed(value: float) -> void:
	if _seeking and _controller:
		# Preview position while dragging
		_current_time = value
		_update_display()

func _on_speed_down() -> void:
	var speeds := [0.25, 0.5, 1.0, 1.5, 2.0, 4.0]
	var current_idx := _find_closest_speed_idx(speeds, _speed)
	if current_idx > 0:
		_speed = speeds[current_idx - 1]
		if _controller:
			_controller.set_speed(_speed)
		_update_display()

func _on_speed_up() -> void:
	var speeds := [0.25, 0.5, 1.0, 1.5, 2.0, 4.0]
	var current_idx := _find_closest_speed_idx(speeds, _speed)
	if current_idx < speeds.size() - 1:
		_speed = speeds[current_idx + 1]
		if _controller:
			_controller.set_speed(_speed)
		_update_display()

func _find_closest_speed_idx(speeds: Array, target: float) -> int:
	var closest_idx: int = 0
	var closest_diff: float = abs(float(speeds[0]) - target)
	for i in range(speeds.size()):
		var diff: float = abs(float(speeds[i]) - target)
		if diff < closest_diff:
			closest_diff = diff
			closest_idx = i
	return closest_idx

func _on_exit_pressed() -> void:
	if _controller:
		_controller.exit_to_menu()
	else:
		get_tree().change_scene_to_file("res://scenes/Menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	# Allow Escape to exit replay
	if event.is_action_pressed("ui_cancel"):
		_on_exit_pressed()
	# Space to toggle pause
	elif event.is_action_pressed("ui_accept"):
		_on_play_pause_pressed()

func _process(delta: float) -> void:
	# Handle announcement fade out
	if _announcement_timer > 0.0:
		_announcement_timer -= delta
		if _announcement_timer <= 0.0 and _announcement_label:
			_announcement_label.visible = false
		elif _announcement_timer < 0.5 and _announcement_label:
			# Fade out
			_announcement_label.modulate.a = _announcement_timer / 0.5

func _on_round_started(round_num: int) -> void:
	_show_announcement("[center][font_size=64]ROUND %d[/font_size][/center]" % round_num, 2.0)

func _on_round_ended(winner: int, sa: int, sb: int) -> void:
	var winner_text := "DRAW"
	var winner_color := "#ffffff"
	if winner == 0:
		winner_text = "BLUE WINS"
		winner_color = "#4aa3ff"
	elif winner == 1:
		winner_text = "RED WINS"
		winner_color = "#ff4a4a"
	_show_announcement("[center][font_size=48]ROUND OVER[/font_size]\n[font_size=64][color=%s]%s[/color][/font_size][/center]" % [winner_color, winner_text], 2.5)

func _show_announcement(text: String, duration: float) -> void:
	# Create announcement label if it doesn't exist
	if _announcement_label == null:
		_announcement_label = RichTextLabel.new()
		_announcement_label.bbcode_enabled = true
		_announcement_label.scroll_active = false
		_announcement_label.fit_content = true
		_announcement_label.size = Vector2(800, 200)
		_announcement_label.anchor_left = 0.5
		_announcement_label.anchor_right = 0.5
		_announcement_label.anchor_top = 0.4
		_announcement_label.anchor_bottom = 0.4
		_announcement_label.position = Vector2(-400, -100)
		_announcement_label.add_theme_font_override("normal_font", ui_font)
		_announcement_label.add_theme_font_size_override("normal_font_size", 48)
		_announcement_label.add_theme_color_override("default_color", Color.WHITE)
		_announcement_label.add_theme_constant_override("outline_size", 12)
		_announcement_label.add_theme_color_override("font_outline_color", Color.BLACK)
		add_child(_announcement_label)
	
	_announcement_label.text = text
	_announcement_label.visible = true
	_announcement_label.modulate.a = 1.0
	_announcement_timer = duration
