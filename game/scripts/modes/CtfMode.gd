extends GameModeBase
class_name CtfMode

var score := {0: 0, 1: 0}

func setup(ctx) -> void:
    super(ctx)
    # conectează-te la semnalele de la steaguri aici

func on_flag_delivered(team_id: int) -> void:
    if not score.has(team_id):
        score[team_id] = 0
    score[team_id] += 1
    # condiție exemplu: primul la 3
    if score[team_id] >= 3:
        context.on_round_ended(team_id)
