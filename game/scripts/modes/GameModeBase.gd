class_name GameModeBase
extends Node

var context = null

func setup(ctx) -> void:
	context = ctx

func update(delta: float) -> void:
	pass

func on_agent_killed(agent, killer) -> void:
	pass

func on_time_expired() -> void:
	pass
