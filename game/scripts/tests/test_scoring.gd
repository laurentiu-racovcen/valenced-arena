extends "res://scripts/tests/test_base.gd"

## Tests for scoring and match flow

# ============== ROUNDS SETTINGS TESTS ==============

func test_rounds_duration_settings() -> void:
	var durations = Enums.ROUNDS_SETTING_DURATION
	assert_array_size(durations, 3, "Should have 3 duration settings")
	assert_eq(durations[0], 30, "First duration should be 30 seconds")
	assert_eq(durations[1], 60, "Second duration should be 60 seconds")
	assert_eq(durations[2], 90, "Third duration should be 90 seconds")

func test_rounds_number_settings() -> void:
	var numbers = Enums.ROUNDS_SETTING_NUMBER
	assert_array_size(numbers, 5, "Should have 5 number of rounds settings")
	assert_eq(numbers[0], 1, "First should be 1 round")
	assert_eq(numbers[1], 2, "Second should be 2 rounds")
	assert_eq(numbers[2], 3, "Third should be 3 rounds")
	assert_eq(numbers[3], 4, "Fourth should be 4 rounds")
	assert_eq(numbers[4], 5, "Fifth should be 5 rounds")

# ============== MATCH CONFIG TESTS ==============

func test_match_config_exists() -> void:
	var script = load("res://scripts/core/MatchConfig.gd")
	assert_not_null(script, "MatchConfig.gd should exist")

func test_match_config_has_game_mode() -> void:
	var script = load("res://scripts/core/MatchConfig.gd")
	var instance = script.new()
	assert_true("game_mode" in instance, "MatchConfig should have game_mode property")
	instance.free()

# ============== GAME MANAGER TESTS ==============

func test_game_manager_script_exists() -> void:
	var script = load("res://scripts/core/GameManager.gd")
	assert_not_null(script, "GameManager.gd should exist")

func test_game_manager_has_score_variables() -> void:
	var script = load("res://scripts/core/GameManager.gd")
	# Check script source contains score variables
	var source = script.source_code
	assert_true(source.contains("scoreA"), "GameManager should have scoreA")
	assert_true(source.contains("scoreB"), "GameManager should have scoreB")

func test_game_manager_has_round_ended_signal() -> void:
	var script = load("res://scripts/core/GameManager.gd")
	var source = script.source_code
	assert_true(source.contains("signal round_ended"), "GameManager should have round_ended signal")

func test_game_manager_has_match_ended_signal() -> void:
	var script = load("res://scripts/core/GameManager.gd")
	var source = script.source_code
	assert_true(source.contains("signal match_ended"), "GameManager should have match_ended signal")

func test_game_manager_has_score_changed_signal() -> void:
	var script = load("res://scripts/core/GameManager.gd")
	var source = script.source_code
	assert_true(source.contains("signal score_changed"), "GameManager should have score_changed signal")

func test_game_manager_has_on_round_ended() -> void:
	var script = load("res://scripts/core/GameManager.gd")
	var source = script.source_code
	assert_true(source.contains("func on_round_ended"), "GameManager should have on_round_ended method")

func test_game_manager_has_on_match_ended() -> void:
	var script = load("res://scripts/core/GameManager.gd")
	var source = script.source_code
	assert_true(source.contains("func on_match_ended"), "GameManager should have on_match_ended method")

func test_game_manager_has_time_left() -> void:
	var script = load("res://scripts/core/GameManager.gd")
	var source = script.source_code
	assert_true(source.contains("time_left"), "GameManager should have time_left variable")

func test_game_manager_has_rounds_played() -> void:
	var script = load("res://scripts/core/GameManager.gd")
	var source = script.source_code
	assert_true(source.contains("rounds_played"), "GameManager should have rounds_played variable")

func test_game_manager_has_round_over() -> void:
	var script = load("res://scripts/core/GameManager.gd")
	var source = script.source_code
	assert_true(source.contains("round_over"), "GameManager should have round_over variable")

func test_game_manager_has_match_over() -> void:
	var script = load("res://scripts/core/GameManager.gd")
	var source = script.source_code
	assert_true(source.contains("match_over"), "GameManager should have match_over variable")

# ============== WIN CONDITION LOGIC TESTS ==============

func test_game_manager_has_check_win_condition() -> void:
	var script = load("res://scripts/core/GameManager.gd")
	var source = script.source_code
	assert_true(source.contains("check_win_condition"), "GameManager should handle win conditions")

func test_game_manager_has_respawn_logic() -> void:
	var script = load("res://scripts/core/GameManager.gd")
	var source = script.source_code
	assert_true(source.contains("respawn"), "GameManager should have respawn logic")

func test_game_manager_handles_agents_per_team() -> void:
	var script = load("res://scripts/core/GameManager.gd")
	var source = script.source_code
	assert_true(source.contains("agents_per_team"), "GameManager should have agents_per_team")

# ============== TEAM TESTS ==============

func test_team_script_exists() -> void:
	var script = load("res://scripts/team/Team.gd")
	assert_not_null(script, "Team.gd should exist")

func test_team_has_members() -> void:
	var script = load("res://scripts/team/Team.gd")
	var source = script.source_code
	assert_true(source.contains("members"), "Team should have members property")

func test_team_has_get_team_id() -> void:
	var script = load("res://scripts/team/Team.gd")
	var source = script.source_code
	assert_true(source.contains("get_team_id"), "Team should have get_team_id method")

func test_team_has_add_member() -> void:
	var script = load("res://scripts/team/Team.gd")
	var source = script.source_code
	assert_true(source.contains("add_member"), "Team should have add_member method")

# ============== COMMS MANAGER TESTS ==============

func test_comms_manager_exists() -> void:
	var script = load("res://scripts/comms/CommsManager.gd")
	assert_not_null(script, "CommsManager.gd should exist")

func test_comms_manager_has_statistics() -> void:
	var script = load("res://scripts/comms/CommsManager.gd")
	var source = script.source_code
	assert_true(source.contains("get_statistics"), "CommsManager should have get_statistics method")

func test_message_script_exists() -> void:
	var script = load("res://scripts/comms/Message.gd")
	assert_not_null(script, "Message.gd should exist")

func test_communication_mode_exists() -> void:
	var script = load("res://scripts/comms/CommunicationMode.gd")
	assert_not_null(script, "CommunicationMode.gd should exist")

# ============== SCENE TESTS ==============

func test_match_scene_exists() -> void:
	var scene = load("res://scenes/Match.tscn")
	assert_not_null(scene, "Match.tscn should exist")

func test_agent_scene_exists() -> void:
	var scene = load("res://scenes/agents/Agent.tscn")
	assert_not_null(scene, "Agent.tscn should exist")

func test_team_scene_exists() -> void:
	var scene = load("res://scenes/Team.tscn")
	assert_not_null(scene, "Team.tscn should exist")

func test_menu_scene_exists() -> void:
	var scene = load("res://scenes/Menu.tscn")
	assert_not_null(scene, "Menu.tscn should exist")

func test_end_round_menu_scene_exists() -> void:
	var scene = load("res://scenes/EndRoundMenu.tscn")
	assert_not_null(scene, "EndRoundMenu.tscn should exist")

func test_score_hud_scene_exists() -> void:
	var scene = load("res://scenes/ScoreHUD.tscn")
	assert_not_null(scene, "ScoreHUD.tscn should exist")

func test_ctf_hud_scene_exists() -> void:
	var scene = load("res://scenes/CtfHUD.tscn")
	assert_not_null(scene, "CtfHUD.tscn should exist")

func test_flag_scene_exists() -> void:
	var scene = load("res://scenes/modes/Flag.tscn")
	assert_not_null(scene, "Flag.tscn should exist")
