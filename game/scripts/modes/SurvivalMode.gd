extends GameModeBase
class_name SurvivalMode

func setup(ctx) -> void:
	super(ctx)
	# No need to track anything manually
	pass

func update(delta: float) -> void:
	pass

func on_agent_killed(agent, killer) -> void:
	# context == GameManager
	context.call_deferred("check_win_condition_deferred")

func on_time_expired() -> void:
	var teamA_alive = context.get_team_members(0).size()
	var teamB_alive = context.get_team_members(1).size()

	var winner = -1
	if teamA_alive > teamB_alive:
		winner = 0
	elif teamB_alive > teamA_alive:
		winner = 1

	context.on_round_ended(winner)

func check_win_condition() -> void:
	var teamA_alive = context.get_team_members(0).size()
	var teamB_alive = context.get_team_members(1).size()

	if teamA_alive == 0 and teamB_alive > 0:
		context.on_round_ended(1)
	elif teamB_alive == 0 and teamA_alive > 0:
		context.on_round_ended(0)
