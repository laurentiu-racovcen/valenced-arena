extends GameModeBase
class_name SurvivalMode

var team_alive := {}

func setup(ctx) -> void:
    super(ctx)
    team_alive = {}
    for a in context.get_all_agents():
        if not team_alive.has(a.team_id):
            team_alive[a.team_id] = 0
        team_alive[a.team_id] += 1

func update(delta: float) -> void:
    pass

func on_agent_killed(agent, killer) -> void:
    if team_alive.has(agent.team_id):
        team_alive[agent.team_id] -= 1
        if team_alive[agent.team_id] <= 0:
            var winning_team := -1
            for t in team_alive.keys():
                if t != agent.team_id:
                    winning_team = t
            context.on_round_ended(winning_team)

func on_time_expired() -> void:
    var winner := -1
    var best := -1
    for t in team_alive.keys():
        if team_alive[t] > best:
            best = team_alive[t]
            winner = t
    context.on_round_ended(winner)
