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

# Side stats panels
@onready var left_stats: RichTextLabel = $LeftPanel/StatsLabel if has_node("LeftPanel/StatsLabel") else null
@onready var right_stats: RichTextLabel = $RightPanel/StatsLabel if has_node("RightPanel/StatsLabel") else null

func set_text_format():
	rtl.text = ""

	rtl.add_theme_font_override("normal_font", ui_font)
	rtl.add_theme_font_size_override("normal_font_size", 48)
	rtl.add_theme_color_override("default_color", Color("FEBDAE"))
	rtl.add_theme_constant_override("outline_size", 10)
	rtl.add_theme_color_override("font_outline_color", Color.BLACK)

func _setup_side_panel(label: RichTextLabel, font_size: int = 24) -> void:
	if label == null:
		return
	label.add_theme_font_override("normal_font", ui_font)
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", Color("FEBDAE"))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color.BLACK)

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

	# Main panel - brief summary
	rtl.text = (
		"[center]Match Finished[/center]\n"
		+ "[center]Score: [color=%s]%d[/color] - [color=%s]%d[/color][/center]\n" % [a_col, result.get("scoreA",0), b_col, result.get("scoreB",0)]
		+ "[center]Time: %.1fs[/center]" % result.get("duration_sec", 0.0)
	)

	# Build side panel stats
	_show_team_stats(left_stats, t0, "BLUE TEAM", a_col)
	_show_team_stats(right_stats, t1, "RED TEAM", b_col)

	get_tree().paused = true

func _show_team_stats(label: RichTextLabel, stats: Dictionary, team_name: String, color: String) -> void:
	if label == null:
		return
	
	_setup_side_panel(label, 20)
	
	var kills: int = stats.get("kills", 0)
	var deaths: int = stats.get("deaths", 0)
	var assists: int = stats.get("assists", 0)
	var damage_dealt: int = stats.get("damage_dealt", 0)
	var damage_taken: int = stats.get("damage_taken", 0)
	var overkill: int = stats.get("overkill", 0)
	var bullets_fired: int = stats.get("bullets_fired", 0)
	var dps: float = stats.get("dps", 0.0)
	var dtps: float = stats.get("dtps", 0.0)
	var accuracy: float = stats.get("accuracy", 0.0)
	var avg_survival: float = stats.get("avg_survival_time", 0.0)
	var avg_distance: float = stats.get("avg_distance", 0.0)
	var agents_alive: int = stats.get("agents_alive", 0)
	
	# KDA calculation
	var kda: float = 0.0
	if deaths > 0:
		kda = float(kills + assists) / float(deaths)
	else:
		kda = float(kills + assists)
	
	label.text = (
		"[center][color=%s][b]%s[/b][/color][/center]\n" % [color, team_name]
		+ "[center]━━━━━━━━━━━━━━[/center]\n"
		+ "[center]K/D/A: %d / %d / %d[/center]\n" % [kills, deaths, assists]
		+ "[center]KDA Ratio: %.2f[/center]\n" % kda
		+ "[center]━━━━━━━━━━━━━━[/center]\n"
		+ "[center]DPS: %.1f[/center]\n" % dps
		+ "[center]DTPS: %.1f[/center]\n" % dtps
		+ "[center]━━━━━━━━━━━━━━[/center]\n"
		+ "[center]Damage Dealt: %d[/center]\n" % damage_dealt
		+ "[center]Damage Taken: %d[/center]\n" % damage_taken
		+ "[center]Overkill: %d[/center]\n" % overkill
		+ "[center]━━━━━━━━━━━━━━[/center]\n"
		+ "[center]Bullets Fired: %d[/center]\n" % bullets_fired
		+ "[center]Accuracy: %.1f%%[/center]\n" % accuracy
		+ "[center]━━━━━━━━━━━━━━[/center]\n"
		+ "[center]Avg Survival: %.1fs[/center]\n" % avg_survival
		+ "[center]Avg Distance: %.0f px[/center]\n" % avg_distance
		+ "[center]━━━━━━━━━━━━━━[/center]\n"
		+ "[center]Agents Alive: %d[/center]" % agents_alive
	)

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
	get_tree().change_scene_to_file("res://scenes/Match.tscn")

func _on_main_menu_pressed() -> void:
	print("main menu button pressed!")
	main_menu_pressed.emit()
	get_tree().paused = false  # unpause
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")
