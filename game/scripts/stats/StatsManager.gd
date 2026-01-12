extends Node
class_name StatsManager

var round_start_time: float = 0.0

# agent_id -> stats
var per_agent := {} # { "A1": {team_id,kills,deaths,damage_dealt,damage_taken,alive_time} }
var damage_events := [] # optional log

func start_round(agents: Array) -> void:
	per_agent.clear()
	damage_events.clear()
	round_start_time = Time.get_ticks_msec() / 1000.0

	for a in agents:
		var ag := a as Agent
		if ag == null:
			continue

		# init
		per_agent[ag.id] = {
			"team_id": ag.team.get_team_id() if ag.team else -1,
			"kills": 0,
			"deaths": 0,
			"damage_dealt": 0,
			"damage_taken": 0,
			"alive": true,
		}

		# connect death
		if not ag.died.is_connected(_on_agent_died):
			ag.died.connect(_on_agent_died)

func record_damage(victim: Agent, amount: int, attacker: Agent) -> void:
	if victim == null or amount <= 0:
		return

	var vid := victim.id
	if per_agent.has(vid):
		per_agent[vid]["damage_taken"] += amount

	if attacker != null:
		var aid := attacker.id
		if per_agent.has(aid):
			per_agent[aid]["damage_dealt"] += amount

func _on_agent_died(agent: Agent, killer: Agent) -> void:
	if agent != null and per_agent.has(agent.id):
		per_agent[agent.id]["deaths"] += 1
		per_agent[agent.id]["alive"] = false

	if killer != null and per_agent.has(killer.id):
		per_agent[killer.id]["kills"] += 1

func build_round_result(winning_team: int, score_a: int, score_b: int, commsA: CommsManager = null, commsB: CommsManager = null) -> Dictionary:
	var end_time := Time.get_ticks_msec() / 1000.0
	var duration := end_time - round_start_time

	# team aggregates
	var team := {
		0: {"kills": 0, "deaths": 0, "damage_dealt": 0, "damage_taken": 0},
		1: {"kills": 0, "deaths": 0, "damage_dealt": 0, "damage_taken": 0},
	}

	for aid in per_agent.keys():
		var s: Dictionary = per_agent[aid]
		var tid: int = s.get("team_id", -1)
		if not team.has(tid):
			continue
		team[tid]["kills"] += s["kills"]
		team[tid]["deaths"] += s["deaths"]
		team[tid]["damage_dealt"] += s["damage_dealt"]
		team[tid]["damage_taken"] += s["damage_taken"]

	var comms_stats := {}
	if commsA != null:
		comms_stats["teamA"] = commsA.get_statistics()
	if commsB != null:
		comms_stats["teamB"] = commsB.get_statistics()

	return {
		"winning_team": winning_team,
		"scoreA": score_a,
		"scoreB": score_b,
		"duration_sec": duration,
		"per_agent": per_agent,
		"per_team": team,
		"comms": comms_stats
	}
