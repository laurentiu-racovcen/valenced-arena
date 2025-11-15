extends Node
class_name StatsManager

func on_agent_killed(agent, killer) -> void:
	# logare KDA, DPS, etc.
	pass

func on_round_ended(winning_team: int) -> void:
	# salvează statistici de meci
	pass
