extends Control

const BUTTONS := [
	{"text": "Select gamemode",   "id": "select_gamemode"},
	{"text": "Select Map",        "id": "select_map"},
	{"text": "Round time",        "id": "round_time"},   # becomes SpinBox
	{"text": "Number of rounds",  "id": "rounds"},
	{"text": "Back to menu",      "id": "back"},
	{"text": "Start game",        "id": "start"},
]

var round_time_seconds: int = MatchConfig.round_time_seconds
var num_rounds: int = MatchConfig.num_rounds
var map_type: StringName = MatchConfig.map_type
var game_mode: Enums.GameMode = MatchConfig.game_mode

var _map_selector: OptionButton
var _mode_selector: OptionButton

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.custom_minimum_size = Vector2(500, 300)
	center.add_child(grid)

	for data in BUTTONS:
		match data.id:
			"select_gamemode":
				var box_mode := VBoxContainer.new()
				grid.add_child(box_mode)

				var label_mode := Label.new()
				label_mode.text = "Game mode"
				label_mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				box_mode.add_child(label_mode)

				_mode_selector = OptionButton.new()
				_mode_selector.custom_minimum_size = Vector2(220, 40)
				_mode_selector.add_item("Survival")   # index 0
				_mode_selector.add_item("King of the Hill") # index 1
				_mode_selector.add_item("Capture the Flag") # index 2
				_mode_selector.add_item("Transport")        # index 3

				match game_mode:
					"survival":
						_mode_selector.select(0)
					"koth":
						_mode_selector.select(1)
					"ctf":
						_mode_selector.select(2)
					"transport":
						_mode_selector.select(3)

				_mode_selector.item_selected.connect(_on_game_mode_selected)
				box_mode.add_child(_mode_selector)

			"select_map":
				var box_map := VBoxContainer.new()
				grid.add_child(box_map)

				var label_map := Label.new()
				label_map.text = "Map type"
				label_map.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				box_map.add_child(label_map)

				_map_selector = OptionButton.new()
				_map_selector.custom_minimum_size = Vector2(220, 40)
				_map_selector.add_item("Easy map")   # index 0
				_map_selector.add_item("Medium map") # index 1
				_map_selector.add_item("Hard map")   # index 2

				# set initial selection from MatchConfig
				match map_type:
					"easy":
						_map_selector.select(0)
					"medium":
						_map_selector.select(1)
					"hard":
						_map_selector.select(2)

				_map_selector.item_selected.connect(_on_map_type_selected)
				box_map.add_child(_map_selector)

			"round_time":
				var box_rt := VBoxContainer.new()
				grid.add_child(box_rt)

				var label_rt := Label.new()
				label_rt.text = "Round time (s)"
				label_rt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				box_rt.add_child(label_rt)

				var spin_rt := SpinBox.new()
				spin_rt.min_value = 30
				spin_rt.max_value = 90
				spin_rt.step = 5 # from 5 to 5 seconds
				spin_rt.value = round_time_seconds
				spin_rt.custom_minimum_size = Vector2(220, 40)
				spin_rt.value_changed.connect(_on_round_time_changed)
				box_rt.add_child(spin_rt)

			"rounds":
				var box_nr := VBoxContainer.new()
				grid.add_child(box_nr)

				var label_nr := Label.new()
				label_nr.text = "Number of rounds"
				label_nr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				box_nr.add_child(label_nr)

				var spin_nr := SpinBox.new()
				spin_nr.min_value = 1
				spin_nr.max_value = 4
				spin_nr.step = 1
				spin_nr.value = num_rounds
				spin_nr.custom_minimum_size = Vector2(220, 40)
				spin_nr.value_changed.connect(_on_num_rounds_changed)
				box_nr.add_child(spin_nr)

			_:
				var btn := Button.new()
				btn.text = data.text
				btn.custom_minimum_size = Vector2(220, 50)
				grid.add_child(btn)
				btn.pressed.connect(_on_button_pressed.bind(data.id))

func _on_game_mode_selected(index: int) -> void:
	match index:
		0:
			game_mode = Enums.GameMode.SURVIVAL
		1:
			game_mode = Enums.GameMode.KOTH
		2:
			game_mode = Enums.GameMode.CTF
		3:
			game_mode = Enums.GameMode.TRANSPORT

func _on_map_type_selected(index: int) -> void:
	match index:
		0:
			map_type = "easy"
		1:
			map_type = "medium"
		2:
			map_type = "hard"

func _on_round_time_changed(value: float) -> void:
	round_time_seconds = int(value)

func _on_num_rounds_changed(value: float) -> void:
	num_rounds = int(value)

func _on_button_pressed(id: String) -> void:
	match id:
		"back":
			get_tree().change_scene_to_file("res://scenes/MenuManager.tscn")
		"start":
			_on_start_game()

func _on_start_game() -> void:
	MatchConfig.round_time_seconds = round_time_seconds
	MatchConfig.num_rounds = num_rounds
	MatchConfig.map_type = map_type
	MatchConfig.game_mode = game_mode
	print("round time=", MatchConfig.round_time_seconds)
	print("num rounds=", MatchConfig.num_rounds)
	print("map type=", MatchConfig.map_type)
	print("game mode=", MatchConfig.game_mode)

	get_tree().change_scene_to_file("res://scenes/Match.tscn")
