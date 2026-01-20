extends Node
class_name TestBase

## Base class for all test suites - provides assertion helpers and test discovery

signal test_passed(test_name: String)
signal test_failed(test_name: String, message: String)
signal test_skipped(test_name: String)

var _current_test: String = ""
var _assertion_failed: bool = false
var _failure_message: String = ""

## Override in subclass for setup before each test
func setup() -> void:
	pass

## Override in subclass for cleanup after each test
func teardown() -> void:
	pass

## Override in subclass for one-time setup before all tests
func setup_suite() -> void:
	pass

## Override in subclass for one-time cleanup after all tests
func teardown_suite() -> void:
	pass

## Returns array of test method names (methods starting with "test_")
func get_test_methods() -> Array[String]:
	var methods: Array[String] = []
	for method in get_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("test_"):
			methods.append(method_name)
	return methods

## Run a single test method
func run_test(method_name: String) -> Dictionary:
	_current_test = method_name
	_assertion_failed = false
	_failure_message = ""
	
	# Setup
	setup()
	
	# Execute test
	if has_method(method_name):
		call(method_name)
	else:
		_assertion_failed = true
		_failure_message = "Method not found: " + method_name
	
	# Teardown
	teardown()
	
	return {
		"name": method_name,
		"passed": not _assertion_failed,
		"message": _failure_message
	}

# ============== ASSERTION HELPERS ==============

func assert_true(condition: bool, message: String = "") -> void:
	if _assertion_failed:
		return
	if not condition:
		_assertion_failed = true
		_failure_message = message if message != "" else "Expected true, got false"
		test_failed.emit(_current_test, _failure_message)

func assert_false(condition: bool, message: String = "") -> void:
	if _assertion_failed:
		return
	if condition:
		_assertion_failed = true
		_failure_message = message if message != "" else "Expected false, got true"
		test_failed.emit(_current_test, _failure_message)

func assert_eq(actual, expected, message: String = "") -> void:
	if _assertion_failed:
		return
	if actual != expected:
		_assertion_failed = true
		_failure_message = message if message != "" else "Expected %s, got %s" % [str(expected), str(actual)]
		test_failed.emit(_current_test, _failure_message)

func assert_ne(actual, not_expected, message: String = "") -> void:
	if _assertion_failed:
		return
	if actual == not_expected:
		_assertion_failed = true
		_failure_message = message if message != "" else "Expected value to not equal %s" % [str(not_expected)]
		test_failed.emit(_current_test, _failure_message)

func assert_null(value, message: String = "") -> void:
	if _assertion_failed:
		return
	if value != null:
		_assertion_failed = true
		_failure_message = message if message != "" else "Expected null, got %s" % [str(value)]
		test_failed.emit(_current_test, _failure_message)

func assert_not_null(value, message: String = "") -> void:
	if _assertion_failed:
		return
	if value == null:
		_assertion_failed = true
		_failure_message = message if message != "" else "Expected non-null value"
		test_failed.emit(_current_test, _failure_message)

func assert_gt(actual: float, expected: float, message: String = "") -> void:
	if _assertion_failed:
		return
	if actual <= expected:
		_assertion_failed = true
		_failure_message = message if message != "" else "Expected %s > %s" % [str(actual), str(expected)]
		test_failed.emit(_current_test, _failure_message)

func assert_gte(actual: float, expected: float, message: String = "") -> void:
	if _assertion_failed:
		return
	if actual < expected:
		_assertion_failed = true
		_failure_message = message if message != "" else "Expected %s >= %s" % [str(actual), str(expected)]
		test_failed.emit(_current_test, _failure_message)

func assert_lt(actual: float, expected: float, message: String = "") -> void:
	if _assertion_failed:
		return
	if actual >= expected:
		_assertion_failed = true
		_failure_message = message if message != "" else "Expected %s < %s" % [str(actual), str(expected)]
		test_failed.emit(_current_test, _failure_message)

func assert_lte(actual: float, expected: float, message: String = "") -> void:
	if _assertion_failed:
		return
	if actual > expected:
		_assertion_failed = true
		_failure_message = message if message != "" else "Expected %s <= %s" % [str(actual), str(expected)]
		test_failed.emit(_current_test, _failure_message)

func assert_in_range(value: float, min_val: float, max_val: float, message: String = "") -> void:
	if _assertion_failed:
		return
	if value < min_val or value > max_val:
		_assertion_failed = true
		_failure_message = message if message != "" else "Expected %s to be in range [%s, %s]" % [str(value), str(min_val), str(max_val)]
		test_failed.emit(_current_test, _failure_message)

func assert_array_has(arr: Array, item, message: String = "") -> void:
	if _assertion_failed:
		return
	if not arr.has(item):
		_assertion_failed = true
		_failure_message = message if message != "" else "Expected array to contain %s" % [str(item)]
		test_failed.emit(_current_test, _failure_message)

func assert_array_size(arr: Array, expected_size: int, message: String = "") -> void:
	if _assertion_failed:
		return
	if arr.size() != expected_size:
		_assertion_failed = true
		_failure_message = message if message != "" else "Expected array size %d, got %d" % [expected_size, arr.size()]
		test_failed.emit(_current_test, _failure_message)

func skip_test(reason: String = "Skipped") -> void:
	_assertion_failed = true
	_failure_message = "SKIP: " + reason
	test_skipped.emit(_current_test)
