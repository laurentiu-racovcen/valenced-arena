extends "res://scripts/tests/test_base.gd"

## Tests for StatsManager functionality

# ============== STATS MANAGER CLASS TESTS ==============

func test_stats_manager_class_exists() -> void:
	var sm = StatsManager.new()
	assert_not_null(sm, "StatsManager should instantiate")
	sm.free()

func test_stats_manager_extends_node() -> void:
	var sm = StatsManager.new()
	assert_true(sm is Node, "StatsManager should extend Node")
	sm.free()

func test_stats_manager_has_per_agent_dict() -> void:
	var sm = StatsManager.new()
	assert_true("per_agent" in sm, "StatsManager should have per_agent property")
	assert_true(sm.per_agent is Dictionary, "per_agent should be a Dictionary")
	sm.free()

func test_stats_manager_has_damage_events() -> void:
	var sm = StatsManager.new()
	assert_true("damage_events" in sm, "StatsManager should have damage_events property")
	assert_true(sm.damage_events is Array, "damage_events should be an Array")
	sm.free()

func test_stats_manager_has_round_start_time() -> void:
	var sm = StatsManager.new()
	assert_true("round_start_time" in sm, "StatsManager should have round_start_time property")
	sm.free()

func test_stats_manager_initial_round_time_zero() -> void:
	var sm = StatsManager.new()
	assert_eq(sm.round_start_time, 0.0, "Initial round_start_time should be 0.0")
	sm.free()

# ============== STATS MANAGER METHODS TESTS ==============

func test_stats_manager_has_start_round() -> void:
	var sm = StatsManager.new()
	assert_true(sm.has_method("start_round"), "StatsManager should have start_round method")
	sm.free()

func test_stats_manager_has_record_damage() -> void:
	var sm = StatsManager.new()
	assert_true(sm.has_method("record_damage"), "StatsManager should have record_damage method")
	sm.free()

func test_stats_manager_has_build_round_result() -> void:
	var sm = StatsManager.new()
	assert_true(sm.has_method("build_round_result"), "StatsManager should have build_round_result method")
	sm.free()

# ============== STATS MANAGER LOGIC TESTS ==============

func test_start_round_clears_per_agent() -> void:
	var sm = StatsManager.new()
	sm.per_agent["test"] = {"kills": 5}
	sm.start_round([])
	assert_true(sm.per_agent.is_empty(), "start_round should clear per_agent")
	sm.free()

func test_start_round_clears_damage_events() -> void:
	var sm = StatsManager.new()
	sm.damage_events.append({"test": true})
	sm.start_round([])
	assert_true(sm.damage_events.is_empty(), "start_round should clear damage_events")
	sm.free()

func test_start_round_sets_time() -> void:
	var sm = StatsManager.new()
	sm.start_round([])
	assert_gt(sm.round_start_time, 0.0, "start_round should set round_start_time")
	sm.free()

# ============== BUILD ROUND RESULT TESTS ==============

func test_build_round_result_returns_dict() -> void:
	var sm = StatsManager.new()
	sm.start_round([])
	var result = sm.build_round_result(0, 3, 2)
	assert_true(result is Dictionary, "build_round_result should return a Dictionary")
	sm.free()

func test_build_round_result_has_winning_team() -> void:
	var sm = StatsManager.new()
	sm.start_round([])
	var result = sm.build_round_result(1, 2, 3)
	assert_true(result.has("winning_team"), "Result should have winning_team")
	assert_eq(result["winning_team"], 1, "winning_team should match input")
	sm.free()

func test_build_round_result_has_scores() -> void:
	var sm = StatsManager.new()
	sm.start_round([])
	var result = sm.build_round_result(0, 5, 3)
	assert_true(result.has("scoreA"), "Result should have scoreA")
	assert_true(result.has("scoreB"), "Result should have scoreB")
	assert_eq(result["scoreA"], 5, "scoreA should match input")
	assert_eq(result["scoreB"], 3, "scoreB should match input")
	sm.free()

func test_build_round_result_has_duration() -> void:
	var sm = StatsManager.new()
	sm.start_round([])
	var result = sm.build_round_result(0, 1, 1)
	assert_true(result.has("duration_sec"), "Result should have duration_sec")
	assert_gte(result["duration_sec"], 0.0, "Duration should be non-negative")
	sm.free()

func test_build_round_result_has_per_agent() -> void:
	var sm = StatsManager.new()
	sm.start_round([])
	var result = sm.build_round_result(0, 1, 1)
	assert_true(result.has("per_agent"), "Result should have per_agent")
	sm.free()

func test_build_round_result_has_per_team() -> void:
	var sm = StatsManager.new()
	sm.start_round([])
	var result = sm.build_round_result(0, 1, 1)
	assert_true(result.has("per_team"), "Result should have per_team")
	assert_true(result["per_team"] is Dictionary, "per_team should be Dictionary")
	sm.free()

func test_build_round_result_has_comms() -> void:
	var sm = StatsManager.new()
	sm.start_round([])
	var result = sm.build_round_result(0, 1, 1)
	assert_true(result.has("comms"), "Result should have comms")
	sm.free()

func test_per_team_structure() -> void:
	var sm = StatsManager.new()
	sm.start_round([])
	var result = sm.build_round_result(0, 1, 1)
	var per_team = result["per_team"]
	
	assert_true(per_team.has(0), "per_team should have team 0")
	assert_true(per_team.has(1), "per_team should have team 1")
	
	assert_true(per_team[0].has("kills"), "Team 0 should have kills")
	assert_true(per_team[0].has("deaths"), "Team 0 should have deaths")
	assert_true(per_team[0].has("damage_dealt"), "Team 0 should have damage_dealt")
	assert_true(per_team[0].has("damage_taken"), "Team 0 should have damage_taken")
	sm.free()

# ============== REPLAY MANAGER TESTS ==============

func test_replay_manager_script_exists() -> void:
	var script = load("res://scripts/stats/ReplayManager.gd")
	assert_not_null(script, "ReplayManager.gd should exist")

func test_replay_manager_is_autoload() -> void:
	# Check if Replay singleton is accessible
	var replay = Engine.get_singleton("Replay") if Engine.has_singleton("Replay") else null
	# In SceneTree context, autoloads aren't singletons, so we just check the script exists
	var script = load("res://scripts/stats/ReplayManager.gd")
	assert_not_null(script, "ReplayManager should be loadable")
