extends Control

@onready var back_button = $BackButton
@onready var menus := {
	"main": $Main,
	"gamemode": $Gamemode,
	"settings": $SettingsManager/Selector
}

var menu_stack: Array[StringName] = []
var current_menu_id: String = ""


func _ready() -> void:
	show_menu("main")

func _apply_menu_visibility() -> void:
	for key in menus.keys():
		menus[key].visible = (key == current_menu_id)

func show_menu(id: StringName, push_current: bool = true) -> void:
	if push_current and current_menu_id != "":
		menu_stack.append(current_menu_id)
	current_menu_id = id
	back_button.visible = current_menu_id != "main"
	_apply_menu_visibility()


func _on_back_button_pressed() -> void:
	if menu_stack.is_empty():
		return
	var prev_id : String = menu_stack.pop_back()
	show_menu(prev_id, false)
