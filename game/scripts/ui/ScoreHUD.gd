extends CanvasLayer
class_name ScoreHUD

@onready var rtl: RichTextLabel = RichTextLabel.new()
@onready var ui_font: FontFile = preload("res://fonts/PixelifySans-Bold.ttf")

var _score_a: int = 0
var _score_b: int = 0
var _match_start_time: float = 0.0
var _match_running: bool = true

func _ready() -> void:
	_setup_rtl()
	_match_start_time = Time.get_ticks_msec() / 1000.0
	set_score(0, 0)

func _process(_delta: float) -> void:
	if _match_running:
		_update_display()

func _setup_rtl():
	rtl.size = Vector2(900, 80)
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
	var elapsed := Time.get_ticks_msec() / 1000.0 - _match_start_time
	var minutes := int(elapsed) / 60
	var seconds := int(elapsed) % 60
	var time_str := "%d:%02d" % [minutes, seconds]
	
	var a_col := "#4aa3ff"
	var b_col := "#ff4a4a"
	rtl.text = "[center]Score: [color=%s]%d[/color] - [color=%s]%d[/color]  |  %s[/center]" % [
		a_col, _score_a, b_col, _score_b, time_str
	]

func set_score(a: int, b: int) -> void:
	_score_a = a
	_score_b = b
	_update_display()

func stop_timer() -> void:
	_match_running = false
