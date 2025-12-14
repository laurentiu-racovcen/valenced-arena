extends Control

@export var end_round_menu_scene: PackedScene
@onready var game_manager = $"../core/GameManager"
var end_menu: Control

func _ready() -> void:
	if game_manager and game_manager.has_signal("round_ended"):
		game_manager.round_ended.connect(_on_round_ended)

func _on_round_ended(winning_team: int) -> void:
	#get_tree().paused = true

	if end_menu:
		end_menu.queue_free()

	end_menu = end_round_menu_scene.instantiate()
	add_child(end_menu)
	end_menu.set_winner(winning_team)

	end_menu.restart_pressed.connect(_on_end_restart)
	end_menu.main_menu_pressed.connect(_on_end_main_menu)

func _on_end_continue() -> void:
	end_menu.queue_free()

func _on_end_restart() -> void:
	# restart logic here (or emit a signal upward)
	print("restarting the game...")

func _on_end_main_menu() -> void:
	# change scene to main menu here (or emit a signal upward)
	print("going to the main menu...")
