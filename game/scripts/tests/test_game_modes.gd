extends "res://scripts/tests/test_base.gd"

## Tests for game mode logic (Survival, KOTH, CTF)

# ============== SURVIVAL MODE TESTS ==============

func test_survival_mode_class_exists() -> void:
	var mode = SurvivalMode.new()
	assert_not_null(mode, "SurvivalMode should instantiate")
	mode.free()

func test_survival_mode_extends_base() -> void:
	var mode = SurvivalMode.new()
	assert_true(mode is GameModeBase, "SurvivalMode should extend GameModeBase")
	mode.free()

func test_survival_has_check_win_condition() -> void:
	var mode = SurvivalMode.new()
	assert_true(mode.has_method("check_win_condition"), "SurvivalMode should have check_win_condition method")
	mode.free()

func test_survival_has_time_expired_handler() -> void:
	var mode = SurvivalMode.new()
	assert_true(mode.has_method("on_time_expired"), "SurvivalMode should have on_time_expired method")
	mode.free()

func test_survival_has_agent_killed_handler() -> void:
	var mode = SurvivalMode.new()
	assert_true(mode.has_method("on_agent_killed"), "SurvivalMode should have on_agent_killed method")
	mode.free()

# ============== KOTH MODE TESTS ==============

func test_koth_mode_class_exists() -> void:
	var mode = KothMode.new()
	assert_not_null(mode, "KothMode should instantiate")
	mode.free()

func test_koth_mode_extends_base() -> void:
	var mode = KothMode.new()
	assert_true(mode is GameModeBase, "KothMode should extend GameModeBase")
	mode.free()

func test_koth_has_hill_position() -> void:
	var mode = KothMode.new()
	assert_true("hill_pos" in mode, "KothMode should have hill_pos property")
	mode.free()

func test_koth_has_hill_radius() -> void:
	var mode = KothMode.new()
	assert_true("hill_radius" in mode, "KothMode should have hill_radius property")
	mode.free()

func test_koth_default_hill_radius() -> void:
	var mode = KothMode.new()
	assert_eq(mode.hill_radius, 200.0, "Default hill radius should be 200.0")
	mode.free()

func test_koth_has_score_accumulators() -> void:
	var mode = KothMode.new()
	assert_true("blue_accumulator" in mode, "KothMode should have blue_accumulator")
	assert_true("red_accumulator" in mode, "KothMode should have red_accumulator")
	mode.free()

func test_koth_initial_accumulators_zero() -> void:
	var mode = KothMode.new()
	assert_eq(mode.blue_accumulator, 0.0, "Blue accumulator should start at 0")
	assert_eq(mode.red_accumulator, 0.0, "Red accumulator should start at 0")
	mode.free()

# ============== CTF MODE TESTS ==============

func test_ctf_mode_class_exists() -> void:
	var mode = CtfMode.new()
	assert_not_null(mode, "CtfMode should instantiate")
	mode.free()

func test_ctf_mode_extends_base() -> void:
	var mode = CtfMode.new()
	assert_true(mode is GameModeBase, "CtfMode should extend GameModeBase")
	mode.free()

func test_ctf_has_score_dictionary() -> void:
	var mode = CtfMode.new()
	assert_true("score" in mode, "CtfMode should have score property")
	assert_true(mode.score is Dictionary, "Score should be a Dictionary")
	mode.free()

func test_ctf_initial_score_zero() -> void:
	var mode = CtfMode.new()
	assert_eq(mode.score[0], 0, "Blue team score should start at 0")
	assert_eq(mode.score[1], 0, "Red team score should start at 0")
	mode.free()

func test_ctf_has_score_to_win() -> void:
	var mode = CtfMode.new()
	assert_true("score_to_win" in mode, "CtfMode should have score_to_win property")
	assert_eq(mode.score_to_win, 3, "Default score_to_win should be 3")
	mode.free()

func test_ctf_has_flag_references() -> void:
	var mode = CtfMode.new()
	assert_true("blue_flag" in mode, "CtfMode should have blue_flag property")
	assert_true("red_flag" in mode, "CtfMode should have red_flag property")
	mode.free()

func test_ctf_has_flag_spawn_positions() -> void:
	var mode = CtfMode.new()
	assert_true("blue_flag_spawn" in mode, "CtfMode should have blue_flag_spawn")
	assert_true("red_flag_spawn" in mode, "CtfMode should have red_flag_spawn")
	mode.free()

func test_ctf_get_flag_method() -> void:
	var mode = CtfMode.new()
	assert_true(mode.has_method("get_flag"), "CtfMode should have get_flag method")
	mode.free()

func test_ctf_get_enemy_flag_method() -> void:
	var mode = CtfMode.new()
	assert_true(mode.has_method("get_enemy_flag"), "CtfMode should have get_enemy_flag method")
	mode.free()

func test_ctf_is_flag_safe_method() -> void:
	var mode = CtfMode.new()
	assert_true(mode.has_method("is_flag_safe"), "CtfMode should have is_flag_safe method")
	mode.free()

func test_ctf_cleanup_method() -> void:
	var mode = CtfMode.new()
	assert_true(mode.has_method("cleanup_ctf"), "CtfMode should have cleanup_ctf method")
	mode.free()

# ============== GAME MODE BASE TESTS ==============

func test_game_mode_base_class_exists() -> void:
	var mode = GameModeBase.new()
	assert_not_null(mode, "GameModeBase should instantiate")
	mode.free()

func test_game_mode_base_has_context() -> void:
	var mode = GameModeBase.new()
	assert_true("context" in mode, "GameModeBase should have context property")
	mode.free()

# ============== ENUMS TESTS ==============

func test_game_mode_enum_survival() -> void:
	assert_eq(Enums.GameMode.SURVIVAL, 0, "SURVIVAL should be 0")

func test_game_mode_enum_koth() -> void:
	assert_eq(Enums.GameMode.KOTH, 1, "KOTH should be 1")

func test_game_mode_enum_ctf() -> void:
	assert_eq(Enums.GameMode.CTF, 2, "CTF should be 2")
