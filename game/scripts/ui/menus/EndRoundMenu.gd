extends Control

@onready var btn_restart: TextureButton = $RestartButton
@onready var btn_main: TextureButton = $MainMenuButton
@onready var winner_text: Label = $WinnerText

signal restart_pressed
signal main_menu_pressed

const RESTART_NORMAL  = preload("res://assets/menu/normal/common/buttons/back.png")
const RESTART_HOVER   = preload("res://assets/menu/hover/common/buttons/back.png")
const MAIN_NORMAL     = preload("res://assets/menu/normal/common/buttons/home.png")
const MAIN_HOVER      = preload("res://assets/menu/hover/common/buttons/home.png")

@onready var label: Label = Label.new()
@onready var ui_font: FontFile = preload("res://fonts/PixelifySans-Bold.ttf")
var ls : LabelSettings

func set_text_format():
	label.text = ""
	label.anchor_left = 0.5
	label.anchor_top = 0.0
	label.anchor_right = 0.5
	label.anchor_bottom = 0.0
	label.position = Vector2(-175, 540)

	ls = LabelSettings.new()
	ls.font = ui_font
	ls.font_size = 48
	ls.font_color = Color("FEBDAE")
	ls.outline_size = 10             # stroke thickness in pixels
	ls.outline_color = Color.BLACK   # stroke color (black)

	label.label_settings = ls
	
	add_child(label)

func show_round_result(winning_team: int) -> void:
	var winning_team_name : String
	if winning_team == 0:
		winning_team_name = "Blue"
	elif winning_team == 1:
		winning_team_name = "Red"
	else:
		winning_team_name = "No"

	label.text = winning_team_name + " team won!"

	# Stop the world
	get_tree().paused = true

func _ready() -> void:
	# So this UI keeps working even if you pause later.
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
	#winner_text.text = "A câștigat echipa %d" % winning_team

func _on_restart_pressed() -> void:
	print("restart button pressed!")
	get_tree().paused = false  # unpause
	get_tree().change_scene_to_file("res://scenes/Match.tscn")  # main menu scene

func _on_main_menu_pressed() -> void:
	print("main menu button pressed!")
	main_menu_pressed.emit()
	get_tree().paused = false  # unpause
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")  # main menu scene
