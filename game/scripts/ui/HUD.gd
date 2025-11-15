extends Control

@onready var label: Label = Label.new()

func _ready() -> void:
	label.text = ""
	label.anchor_left = 0.5
	label.anchor_top = 0.0
	label.anchor_right = 0.5
	label.anchor_bottom = 0.0
	label.position = Vector2(0, 20)
	add_child(label)

func show_round_result(winning_team: int) -> void:
	label.text = "A câștigat echipa: %d" % winning_team
