extends Control
class_name RoundCountdown

signal finished

@export var seconds := 5.0 # round pause duration in seconds
@onready var rtl: RichTextLabel = RichTextLabel.new()
@onready var ui_font: FontFile = preload("res://fonts/PixelifySans-Bold.ttf")

var winning_team : String = ""
var _remaining := 0.0

func _ready() -> void:
	_setup_rtl()
	# keep updating while game is paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_process(false)

func _setup_rtl():
	rtl.text = ""
	rtl.bbcode_enabled = true
	rtl.scroll_active = false
	rtl.fit_content = true

	rtl.size = Vector2(900, 220)
	rtl.anchor_left = 0.5
	rtl.anchor_right = 0.5
	rtl.anchor_top = 0.0
	rtl.anchor_bottom = 0.0
	rtl.position = Vector2(515, 490)

	# Theme overrides (font + outline)
	rtl.add_theme_font_override("normal_font", ui_font)
	rtl.add_theme_font_size_override("normal_font_size", 48)
	rtl.add_theme_color_override("default_color", Color("FEBDAE"))
	rtl.add_theme_constant_override("outline_size", 10)
	rtl.add_theme_color_override("font_outline_color", Color.BLACK)

	add_child(rtl)

func _team_color(team_name: String) -> String:
	if team_name == "Blue":
		return "#4aa3ff"
	if team_name == "Red":
		return "#ff4a4a"
	return "#ffffff"

func start(sec: float, winning_team_string: String) -> void:
	winning_team = winning_team_string
	_remaining = sec
	_update_text()
	set_process(true)

func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		_remaining = 0.0
		_update_text()
		set_process(false)
		finished.emit()
		queue_free()
		return

	_update_text()

func _update_text() -> void:
	var col := _team_color(winning_team)
	var n := int(ceil(_remaining))
	rtl.text = (
		"[center][color=%s]%s[/color] team won this round.[/center]\n" % [col, winning_team]
		+ "[center]Next round in [color=#ffffff]%d[/color][/center]" % n
	)
