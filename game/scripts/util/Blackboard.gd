extends Node
class_name Blackboard

var data := {}

func set_value(key: String, value) -> void:
	data[key] = value

func get_value(key: String, default_value = null):
	return data.get(key, default_value)
