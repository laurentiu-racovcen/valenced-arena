extends GameModeBase
class_name KothMode

var score := {0: 0.0, 1: 0.0}
@export var max_score: float = 100.0

func update(delta: float) -> void:
    if not context or not context.has_node("../KothZone"):
        return
    var zone = context.get_node("../KothZone")
    var team0_in = zone.get_team_presence(0)
    var team1_in = zone.get_team_presence(1)
    if team0_in > 0 and team1_in == 0:
        score[0] += delta
    elif team1_in > 0 and team0_in == 0:
        score[1] += delta
    if score[0] >= max_score:
        context.on_round_ended(0)
    elif score[1] >= max_score:
        context.on_round_ended(1)
