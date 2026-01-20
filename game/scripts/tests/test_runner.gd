extends SceneTree

## Unit Test Runner for 2VALenced Arena
## Runs all test suites and reports results in real-time
##
## Usage:
##   godot --headless --path ./game -s res://scripts/tests/test_runner.gd
##
## Or run the TestRunner.tscn scene from the editor

# Test suite classes to run
const TEST_SUITES := [
	preload("res://scripts/tests/test_game_modes.gd"),
	preload("res://scripts/tests/test_agent.gd"),
	preload("res://scripts/tests/test_stats.gd"),
	preload("res://scripts/tests/test_scoring.gd"),
]

# Statistics
var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var skipped_tests: int = 0
var start_time: float = 0.0

# Detailed results
var results: Array[Dictionary] = []
var failed_details: Array[Dictionary] = []

func _init() -> void:
	print("")
	print("╔══════════════════════════════════════════════════════════════╗")
	print("║       2VALenced Arena - Unit Test Runner                     ║")
	print("╚══════════════════════════════════════════════════════════════╝")
	print("")
	
	start_time = Time.get_ticks_msec() / 1000.0
	
	run_all_tests()
	
	print_summary()
	
	# Exit with appropriate code
	if failed_tests > 0:
		quit(1)
	else:
		quit(0)

func run_all_tests() -> void:
	for suite_script in TEST_SUITES:
		run_test_suite(suite_script)

func run_test_suite(suite_script: Script) -> void:
	var suite = suite_script.new()
	var suite_name = suite_script.resource_path.get_file().replace(".gd", "")
	
	print("┌─────────────────────────────────────────────────────────────┐")
	print("│ Running: %-50s │" % suite_name)
	print("└─────────────────────────────────────────────────────────────┘")
	
	# Setup suite
	suite.setup_suite()
	
	var test_methods = suite.get_test_methods()
	var suite_passed = 0
	var suite_failed = 0
	var suite_skipped = 0
	
	for method_name in test_methods:
		total_tests += 1
		
		var result = suite.run_test(method_name)
		
		# Real-time output
		if result["message"].begins_with("SKIP:"):
			skipped_tests += 1
			suite_skipped += 1
			print("  ⊘ %s - %s" % [method_name, result["message"]])
		elif result["passed"]:
			passed_tests += 1
			suite_passed += 1
			print("  ✓ %s" % method_name)
		else:
			failed_tests += 1
			suite_failed += 1
			print("  ✗ %s" % method_name)
			print("    └─ %s" % result["message"])
			failed_details.append({
				"suite": suite_name,
				"test": method_name,
				"message": result["message"]
			})
		
		results.append({
			"suite": suite_name,
			"test": method_name,
			"passed": result["passed"],
			"message": result["message"]
		})
	
	# Suite summary line
	var status_line = "  Suite: %d passed" % suite_passed
	if suite_failed > 0:
		status_line += ", %d failed" % suite_failed
	if suite_skipped > 0:
		status_line += ", %d skipped" % suite_skipped
	print(status_line)
	print("")
	
	# Teardown suite
	suite.teardown_suite()
	
	# Free the suite
	if suite is Node:
		suite.queue_free()

func print_summary() -> void:
	var elapsed = (Time.get_ticks_msec() / 1000.0) - start_time
	
	print("")
	print("╔══════════════════════════════════════════════════════════════╗")
	print("║                      TEST SUMMARY                            ║")
	print("╠══════════════════════════════════════════════════════════════╣")
	
	# Statistics
	print("║  Total Tests:    %-43d ║" % total_tests)
	print("║  ✓ Passed:       %-43d ║" % passed_tests)
	print("║  ✗ Failed:       %-43d ║" % failed_tests)
	print("║  ⊘ Skipped:      %-43d ║" % skipped_tests)
	print("║  Duration:       %-40s    ║" % ("%.3f seconds" % elapsed))
	
	# Pass rate
	var pass_rate = 0.0
	if total_tests > 0:
		pass_rate = (float(passed_tests) / float(total_tests)) * 100.0
	print("║  Pass Rate:      %-40s    ║" % ("%.1f%%" % pass_rate))
	
	print("╠══════════════════════════════════════════════════════════════╣")
	
	# Overall result
	if failed_tests == 0:
		print("║                    ✓ ALL TESTS PASSED                        ║")
	else:
		print("║                    ✗ SOME TESTS FAILED                       ║")
		print("╠══════════════════════════════════════════════════════════════╣")
		print("║ Failed Tests:                                                ║")
		for failure in failed_details:
			var line = "║   %s.%s" % [failure["suite"], failure["test"]]
			line = line.substr(0, 62).rpad(63) + "║"
			print(line)
	
	print("╚══════════════════════════════════════════════════════════════╝")
	print("")
