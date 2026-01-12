extends Control

@onready var btn_restart: TextureButton = $Layout/VBox/Buttons/RestartButton
@onready var btn_main: TextureButton = $Layout/VBox/Buttons/MainMenuButton

signal restart_pressed
signal main_menu_pressed

const RESTART_NORMAL  = preload("res://assets/menu/normal/common/buttons/back.png")
const RESTART_HOVER   = preload("res://assets/menu/hover/common/buttons/back.png")
const MAIN_NORMAL     = preload("res://assets/menu/normal/common/buttons/home.png")
const MAIN_HOVER      = preload("res://assets/menu/hover/common/buttons/home.png")

@onready var rtl: RichTextLabel = $Layout/VBox/TextPanel/StatsLabel
@onready var ui_font: FontFile = preload("res://fonts/PixelifySans-Bold.ttf")

func set_text_format():
	rtl.text = ""

	rtl.add_theme_font_override("normal_font", ui_font)
	rtl.add_theme_font_size_override("normal_font_size", 48)
	rtl.add_theme_color_override("default_color", Color("FEBDAE"))
	rtl.add_theme_constant_override("outline_size", 10)
	rtl.add_theme_color_override("font_outline_color", Color.BLACK)

func show_round_result(winning_team: int, score_a: int, score_b: int) -> void:
	var winning_team_name := "No"
	if winning_team == 0:
		winning_team_name = "Blue"
	elif winning_team == 1:
		winning_team_name = "Red"

	var a_col := "#4aa3ff"
	var b_col := "#ff4a4a"

	rtl.text = (
		"[center]%s team won![/center]\n" % winning_team_name
		+ "[center]Score: [color=%s]%d[/color] - [color=%s]%d[/color][/center]" % [
			a_col, score_a, b_col, score_b
		]
	)

	get_tree().paused = true

func show_round_stats(result: Dictionary) -> void:
	var a_col := "#4aa3ff"
	var b_col := "#ff4a4a"

	var team: Dictionary = result.get("per_team", {}) as Dictionary
	var t0: Dictionary = team.get(0, {}) as Dictionary
	var t1: Dictionary = team.get(1, {}) as Dictionary

	rtl.text = (
		"[center]Round finished[/center]\n"
		+ "[center]Score: [color=%s]%d[/color] - [color=%s]%d[/color][/center]\n" % [a_col, result.get("scoreA",0), b_col, result.get("scoreB",0)]
		+ "[center]Time: %.1fs[/center]\n" % result.get("duration_sec", 0.0)
		+ "[center][color=%s]Blue[/color] K/D: %d/%d | DMG: %d dealt / %d taken[/center]\n" % [a_col, t0.get("kills",0), t0.get("deaths",0), t0.get("damage_dealt",0), t0.get("damage_taken",0)]
		+ "[center][color=%s]Red[/color] K/D: %d/%d | DMG: %d dealt / %d taken[/center]" % [b_col, t1.get("kills",0), t1.get("deaths",0), t1.get("damage_dealt",0), t1.get("damage_taken",0)]
	)

	get_tree().paused = true

func _ready() -> void:
	# So this UI keeps working even if you pause later
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	btn_main.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS

	btn_restart.texture_normal = RESTART_NORMAL
	btn_restart.texture_hover = RESTART_HOVER
	btn_main.texture_normal = MAIN_NORMAL
	btn_main.texture_hover = MAIN_HOVER

	btn_restart.pressed.connect(_on_restart_pressed)
	btn_main.pressed.connect(_on_main_menu_pressed)

	set_text_format()

func set_winner(winning_team: int) -> void:
	pass

func _on_restart_pressed() -> void:
	print("restart button pressed!")
	get_tree().paused = false  # unpause
	get_tree().change_scene_to_file("res://scenes/Match.tscn")  # main menu scene

func _on_main_menu_pressed() -> void:
	print("main menu button pressed!")
	main_menu_pressed.emit()
	get_tree().paused = false  # unpause
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")  # main menu scene
