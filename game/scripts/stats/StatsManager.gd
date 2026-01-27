extends Node
class_name StatsManager

var round_start_time: float = 0.0

# agent_id -> stats
var per_agent := {} # Enhanced stats per agent
var damage_events := [] # Log of all damage events for assist calculation
var recent_damage := {} # For assist tracking: victim_id -> [{attacker_id, time, amount}]

const ASSIST_WINDOW := 5.0 # Seconds within which damage counts as assist

func start_round(agents: Array) -> void:
	per_agent.clear()
	damage_events.clear()
	recent_damage.clear()
	round_start_time = Time.get_ticks_msec() / 1000.0

	for a in agents:
		var ag := a as Agent
		if ag == null:
			continue

		# Initialize comprehensive stats
		per_agent[ag.id] = {
			"team_id": ag.team.get_team_id() if ag.team else -1,
			"kills": 0,
			"deaths": 0,
			"assists": 0,
			"damage_dealt": 0,
			"damage_taken": 0,
			"overkill": 0,
			"bullets_fired": 0,
			"bullets_hit": 0,
			"distance_traveled": 0.0,
			"time_alive": 0.0,
			"death_time": -1.0,
			"hp_at_death": 0,
			"last_position": ag.global_position,
			"alive": true,
		}
		recent_damage[ag.id] = []

		# Connect death signal
		if not ag.died.is_connected(_on_agent_died):
			ag.died.connect(_on_agent_died)

func record_damage(victim: Agent, amount: int, attacker: Agent) -> void:
	if victim == null or amount <= 0:
		return

	var current_time := Time.get_ticks_msec() / 1000.0
	var vid := victim.id
	
	if per_agent.has(vid):
		per_agent[vid]["damage_taken"] += amount

	if attacker != null:
		var aid := attacker.id
		if per_agent.has(aid):
			per_agent[aid]["damage_dealt"] += amount
			per_agent[aid]["bullets_hit"] += 1
		
		# Track for assist calculation
		if recent_damage.has(vid):
			recent_damage[vid].append({
				"attacker_id": aid,
				"time": current_time,
				"amount": amount
			})
			# Clean old entries
			recent_damage[vid] = recent_damage[vid].filter(
				func(e): return current_time - e.time < ASSIST_WINDOW
			)

func record_shot(agent: Agent) -> void:
	if agent == null:
		return
	var aid := agent.id
	if per_agent.has(aid):
		per_agent[aid]["bullets_fired"] += 1

func record_overkill(victim: Agent, overkill_amount: int, attacker: Agent) -> void:
	if attacker == null or overkill_amount <= 0:
		return
	var aid := attacker.id
	if per_agent.has(aid):
		per_agent[aid]["overkill"] += overkill_amount

func update_agent_position(agent: Agent) -> void:
	if agent == null or not per_agent.has(agent.id):
		return
	var stats: Dictionary = per_agent[agent.id]
	if not stats.get("alive", false):
		return
	
	var last_pos: Vector2 = stats.get("last_position", agent.global_position)
	var distance := agent.global_position.distance_to(last_pos)
	stats["distance_traveled"] += distance
	stats["last_position"] = agent.global_position

func _on_agent_died(agent: Agent, killer: Agent) -> void:
	var current_time := Time.get_ticks_msec() / 1000.0
	
	if agent != null and per_agent.has(agent.id):
		var stats: Dictionary = per_agent[agent.id]
		stats["deaths"] += 1
		stats["alive"] = false
		stats["death_time"] = current_time
		stats["time_alive"] = current_time - round_start_time
		
		# Calculate assists - anyone who damaged victim recently (except killer)
		if recent_damage.has(agent.id):
			var assisters := {}
			for event in recent_damage[agent.id]:
				var attacker_id: String = event.attacker_id
				if killer != null and attacker_id == killer.id:
					continue
				if not assisters.has(attacker_id):
					assisters[attacker_id] = true
					if per_agent.has(attacker_id):
						per_agent[attacker_id]["assists"] += 1

	if killer != null and per_agent.has(killer.id):
		per_agent[killer.id]["kills"] += 1

func build_round_result(winning_team: int, score_a: int, score_b: int, commsA: CommsManager = null, commsB: CommsManager = null) -> Dictionary:
	var end_time := Time.get_ticks_msec() / 1000.0
	var duration := end_time - round_start_time

	# Update time_alive for survivors
	for aid in per_agent.keys():
		var s: Dictionary = per_agent[aid]
		if s.get("alive", false):
			s["time_alive"] = duration

	# Team aggregates with extended stats
	var team := {
		0: _create_team_stats(),
		1: _create_team_stats(),
	}

	for aid in per_agent.keys():
		var s: Dictionary = per_agent[aid]
		var tid: int = s.get("team_id", -1)
		if not team.has(tid):
			continue
		
		var t: Dictionary = team[tid]
		t["kills"] += s.get("kills", 0)
		t["deaths"] += s.get("deaths", 0)
		t["assists"] += s.get("assists", 0)
		t["damage_dealt"] += s.get("damage_dealt", 0)
		t["damage_taken"] += s.get("damage_taken", 0)
		t["overkill"] += s.get("overkill", 0)
		t["bullets_fired"] += s.get("bullets_fired", 0)
		t["bullets_hit"] += s.get("bullets_hit", 0)
		t["distance_traveled"] += s.get("distance_traveled", 0.0)
		t["total_time_alive"] += s.get("time_alive", 0.0)
		t["agent_count"] += 1
		if s.get("alive", false):
			t["agents_alive"] += 1

	# Calculate derived stats
	for tid in team.keys():
		var t: Dictionary = team[tid]
		var agent_count: int = t.get("agent_count", 1)
		var total_time: float = t.get("total_time_alive", 1.0)
		
		# DPS = total damage dealt / total time alive
		t["dps"] = t["damage_dealt"] / max(total_time, 0.1)
		# DTPS = total damage taken / total time alive
		t["dtps"] = t["damage_taken"] / max(total_time, 0.1)
		# Average survival time
		t["avg_survival_time"] = total_time / max(agent_count, 1)
		# Accuracy
		var bullets_fired: int = t.get("bullets_fired", 0)
		t["accuracy"] = (float(t["bullets_hit"]) / max(bullets_fired, 1)) * 100.0
		# Average distance
		t["avg_distance"] = t["distance_traveled"] / max(agent_count, 1)

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

func _create_team_stats() -> Dictionary:
	return {
		"kills": 0,
		"deaths": 0,
		"assists": 0,
		"damage_dealt": 0,
		"damage_taken": 0,
		"overkill": 0,
		"bullets_fired": 0,
		"bullets_hit": 0,
		"distance_traveled": 0.0,
		"total_time_alive": 0.0,
		"agent_count": 0,
		"agents_alive": 0,
		"dps": 0.0,
		"dtps": 0.0,
		"avg_survival_time": 0.0,
		"accuracy": 0.0,
		"avg_distance": 0.0,
	}

## Returns current team statistics for real-time display
func get_team_stats() -> Dictionary:
	var current_time := Time.get_ticks_msec() / 1000.0
	var duration := current_time - round_start_time
	
	var team := {
		0: _create_team_stats(),
		1: _create_team_stats(),
	}
	
	for aid in per_agent.keys():
		var s: Dictionary = per_agent[aid]
		var tid: int = s.get("team_id", -1)
		if not team.has(tid):
			continue
		
		var t: Dictionary = team[tid]
		t["kills"] += s.get("kills", 0)
		t["deaths"] += s.get("deaths", 0)
		t["assists"] += s.get("assists", 0)
		t["damage_dealt"] += s.get("damage_dealt", 0)
		t["damage_taken"] += s.get("damage_taken", 0)
		t["overkill"] += s.get("overkill", 0)
		t["bullets_fired"] += s.get("bullets_fired", 0)
		t["bullets_hit"] += s.get("bullets_hit", 0)
		t["distance_traveled"] += s.get("distance_traveled", 0.0)
		
		# For alive agents, calculate current time alive
		if s.get("alive", false):
			t["total_time_alive"] += duration
			t["agents_alive"] += 1
		else:
			t["total_time_alive"] += s.get("time_alive", 0.0)
		
		t["agent_count"] += 1
	
	# Calculate derived stats
	for tid in team.keys():
		var t: Dictionary = team[tid]
		var agent_count: int = t.get("agent_count", 1)
		var total_time: float = t.get("total_time_alive", 1.0)
		
		t["dps"] = t["damage_dealt"] / max(total_time, 0.1)
		t["dtps"] = t["damage_taken"] / max(total_time, 0.1)
		t["avg_survival_time"] = total_time / max(agent_count, 1)
		var bullets_fired: int = t.get("bullets_fired", 0)
		t["accuracy"] = (float(t["bullets_hit"]) / max(bullets_fired, 1)) * 100.0
		t["avg_distance"] = t["distance_traveled"] / max(agent_count, 1)
		t["alive"] = t["agents_alive"]
	
	return team
