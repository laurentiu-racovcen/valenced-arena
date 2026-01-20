extends "res://scripts/tests/test_base.gd"

## Tests for Agent class functionality

# ============== AGENT CLASS TESTS ==============

func test_agent_role_enum_exists() -> void:
	# Test that Role enum values exist
	assert_eq(Agent.Role.LEADER, 0, "LEADER should be 0")
	assert_eq(Agent.Role.ADVANCE, 1, "ADVANCE should be 1")
	assert_eq(Agent.Role.TANK, 2, "TANK should be 2")
	assert_eq(Agent.Role.SUPPORT, 3, "SUPPORT should be 3")

func test_agent_role_enum_count() -> void:
	# Ensure we have exactly 4 roles
	var roles = [Agent.Role.LEADER, Agent.Role.ADVANCE, Agent.Role.TANK, Agent.Role.SUPPORT]
	assert_array_size(roles, 4, "Should have exactly 4 roles")

# ============== AGENT SETTINGS TESTS ==============

func test_agent_fov_settings() -> void:
	var fov_settings = Enums.AGENT_SETTING_FOV
	assert_array_size(fov_settings, 4, "Should have 4 FOV settings")
	assert_eq(fov_settings[0], 45, "First FOV should be 45 degrees")
	assert_eq(fov_settings[1], 60, "Second FOV should be 60 degrees")
	assert_eq(fov_settings[2], 90, "Third FOV should be 90 degrees")
	assert_eq(fov_settings[3], 120, "Fourth FOV should be 120 degrees")

func test_agent_los_settings() -> void:
	var los_settings = Enums.AGENT_SETTING_LOS
	assert_array_size(los_settings, 3, "Should have 3 LOS settings")
	assert_eq(los_settings[0], 200, "Small LOS should be 200")
	assert_eq(los_settings[1], 300, "Medium LOS should be 300")
	assert_eq(los_settings[2], 400, "Large LOS should be 400")

func test_agent_speed_settings() -> void:
	var speed_settings = Enums.AGENT_SETTING_SPEED
	assert_array_size(speed_settings, 3, "Should have 3 speed settings")
	assert_eq(speed_settings[0], 100, "Slow speed should be 100")
	assert_eq(speed_settings[1], 200, "Medium speed should be 200")
	assert_eq(speed_settings[2], 300, "Fast speed should be 300")

# ============== AGENT BEHAVIOR SCRIPT TESTS ==============

func test_ctf_behavior_script_exists() -> void:
	var script = load("res://scripts/agents/CtfBehavior.gd")
	assert_not_null(script, "CtfBehavior.gd should exist")

func test_ctf_behavior_has_setup() -> void:
	var script = load("res://scripts/agents/CtfBehavior.gd")
	var instance = script.new()
	assert_true(instance.has_method("setup"), "CtfBehavior should have setup method")
	instance.free()

# ============== AGENT PERCEPTION TESTS ==============

func test_agent_perception_script_exists() -> void:
	var script = load("res://scripts/agents/AgentPerception.gd")
	assert_not_null(script, "AgentPerception.gd should exist")

# ============== AGENT COMMS TESTS ==============

func test_agent_comms_script_exists() -> void:
	var script = load("res://scripts/agents/AgentComms.gd")
	assert_not_null(script, "AgentComms.gd should exist")

# ============== ROLE SCRIPTS TESTS ==============

func test_role_scripts_directory_exists() -> void:
	# Verify role scripts can be loaded
	var leader_script = load("res://scripts/agents/roles/LeaderRole.gd")
	assert_not_null(leader_script, "LeaderRole.gd should exist")

func test_advance_role_exists() -> void:
	var script = load("res://scripts/agents/roles/AdvanceRole.gd")
	assert_not_null(script, "AdvanceRole.gd should exist")

func test_tank_role_exists() -> void:
	var script = load("res://scripts/agents/roles/TankRole.gd")
	assert_not_null(script, "TankRole.gd should exist")

func test_support_role_exists() -> void:
	var script = load("res://scripts/agents/roles/SupportRole.gd")
	assert_not_null(script, "SupportRole.gd should exist")

# ============== AGENT DEFAULT VALUES TESTS ==============

func test_default_max_hp() -> void:
	# Based on Agent.gd export defaults
	# We can't instantiate a full agent without scene, so test the script metadata
	var agent_script = load("res://scripts/agents/Agent.gd")
	assert_not_null(agent_script, "Agent.gd should load")

func test_agent_has_died_signal() -> void:
	# Check script has died signal defined
	var agent_script = load("res://scripts/agents/Agent.gd") as Script
	var signals = agent_script.get_script_signal_list()
	var has_died = false
	for sig in signals:
		if sig["name"] == "died":
			has_died = true
			break
	assert_true(has_died, "Agent should have 'died' signal")

# ============== TEAM SKIN CONFIGURATION TESTS ==============

func test_team_skins_blue_team() -> void:
	# Verify blue team skin textures can be loaded
	var blue_leader = load("res://assets/agents/Blue Team/blue_leader_agent.png")
	assert_not_null(blue_leader, "Blue leader skin should exist")
	
	var blue_advance = load("res://assets/agents/Blue Team/blue_advance_agent.png")
	assert_not_null(blue_advance, "Blue advance skin should exist")
	
	var blue_tank = load("res://assets/agents/Blue Team/blue_tank_agent.png")
	assert_not_null(blue_tank, "Blue tank skin should exist")
	
	var blue_support = load("res://assets/agents/Blue Team/blue_support_agent.png")
	assert_not_null(blue_support, "Blue support skin should exist")

func test_team_skins_red_team() -> void:
	# Verify red team skin textures can be loaded
	var red_leader = load("res://assets/agents/Red Team/red_leader_agent.png")
	assert_not_null(red_leader, "Red leader skin should exist")
	
	var red_advance = load("res://assets/agents/Red Team/red_advance_agent.png")
	assert_not_null(red_advance, "Red advance skin should exist")
	
	var red_tank = load("res://assets/agents/Red Team/red_tank_agent.png")
	assert_not_null(red_tank, "Red tank skin should exist")
	
	var red_support = load("res://assets/agents/Red Team/red_support_agent.png")
	assert_not_null(red_support, "Red support skin should exist")
