#!/usr/bin/env -S godot -s

# Min2Phase Godot Plugin Test Suite
# Run with: godot -s test.gd

extends SceneTree
# extends RefCounted

# Import the plugin components
var min2phase = preload("res://addons/min2phase/min2phase.gd")

# Test statistics
var tests_run: int = 0
var tests_passed: int = 0
var tests_failed: int = 0
var failed_tests: Array = []

# Test configuration
var run_performance_tests = true

func _init():
	print("=== Min2Phase Godot Plugin Test Suite ===")
	print("Godot version: ", Engine.get_version_info())
	print("Testing on: ", OS.get_name(), " ", OS.get_version())
	print()

	# Run all test suites
	test_basic_functionality()
	test_move_operations()
	test_solve_function()
	test_error_handling()
	test_edge_cases()
	test_real_world_scenarios()

	if run_performance_tests:
		test_performance()

	# Print final results
	print_summary()

	# Exit with appropriate code - store in a way that works across Godot versions
	if tests_failed > 0:
		print("\n❌ TESTS FAILED - Exit code: 1")
		quit(1)
	else:
		print("\n✅ ALL TESTS PASSED - Exit code: 0")
		quit(0)

func print_summary():
	print("\n" + "=".repeat(50))
	print("TEST RESULTS SUMMARY")
	print("=".repeat(50))
	print("Tests run: ", tests_run)
	print("Passed: ", tests_passed, " (", "%.1f" % (tests_passed * 100.0 / tests_run if tests_run > 0 else 0.0), "%)")
	print("Failed: ", tests_failed, " (", "%.1f" % (tests_failed * 100.0 / tests_run if tests_run > 0 else 0.0), "%)")

	if tests_failed > 0:
		print("\nFAILED TESTS:")
		for test_name in failed_tests:
			print("  - ", test_name)
		print("\n❌ OVERALL: FAILED")
	else:
		print("\n✅ OVERALL: ALL TESTS PASSED")

func assert_true(condition: bool, test_name: String, message: String = ""):
	tests_run += 1
	if condition:
		tests_passed += 1
		print("✅ ", test_name, " - PASSED")
	else:
		tests_failed += 1
		failed_tests.append(test_name)
		print("❌ ", test_name, " - FAILED")
		if message != "":
			print("   ", message)

func assert_equal(actual, expected, test_name: String, message: String = ""):
	var condition = (actual == expected)
	var full_message = message
	if not condition and full_message == "":
		full_message = "Expected: %s, Got: %s" % [str(expected), str(actual)]
	elif not condition:
		full_message += " (Expected: %s, Got: %s)" % [str(expected), str(actual)]
	assert_true(condition, test_name, full_message)

func assert_not_equal(actual, expected, test_name: String, message: String = ""):
	var condition = (actual != expected)
	var full_message = message
	if not condition and full_message == "":
		full_message = "Values should not be equal: %s" % [str(actual)]
	assert_true(condition, test_name, full_message)

# ======================== BASIC FUNCTIONALITY TESTS ========================

func test_basic_functionality():
	print("\n--- Testing new Functionality ---")

	var m2p = min2phase.new()
	# Test that the plugin loads correctly
	assert_true(m2p != null, "Min2Phase.plugin_loads")
	# Test that we can create multiple instances
	var min2phase2 = min2phase.new()
	assert_true(min2phase2 != null, "Min2Phase.multiple_instances")

# ======================== MOVE OPERATIONS TESTS ========================

func test_move_operations():
	print("\n--- Testing Move Operations ---")

	var m2p = min2phase.new()
	m2p._ready()

	# Test from_moves function
	test_from_moves(m2p)

	# Test apply_moves function
	test_apply_moves(m2p)

	# Test random_moves function
	test_random_moves(m2p)

func test_from_moves(m2p: Min2Phase):

	# Test empty moves
	var result = m2p.from_moves("")
	assert_equal(result, Min2Phase.SOLVED_CUBE, "Min2Phase.from_moves_empty")

	# Test single move
	result = m2p.from_moves("U")
	assert_equal(result, "UUUUUUUUUBBBRRRRRRRRRFFFFFFDDDDDDDDDFFFLLLLLLLLLBBBBBB", "Min2Phase.from_moves_single_move")

	result = m2p.from_moves("R R")
	assert_equal(result, "UUDUUDUUDRRRRRRRRRFFBFFBFFBDDUDDUDDULLLLLLLLLFBBFBBFBB", "Min2Phase.from_moves_two_right")

	# Test multiple moves
	result = m2p.from_moves("U R U' R'")
	assert_equal(result, "RFUUUUUURDBBRRRRRRFFFFFUFFUDDFDDDDDDULLLLLLLLLRBBBBBBB", "Min2Phase.from_moves_multiple_moves")

	# Test moves with extra spaces
	result = m2p.from_moves("  U   R   ")
	assert_equal(result, "UURUUFUUFRRBRRBRRBRRDFFDFFDDDBDDBDDLFFFLLLLLLULLUBBUBB", "Min2Phase.from_moves_multiple_moves")

func test_apply_moves(m2p: Min2Phase):

	# Test applying moves to solved cube
	var result = m2p.apply_moves(Min2Phase.SOLVED_CUBE, "U")
	assert_equal(result, "UUUUUUUUUBBBRRRRRRRRRFFFFFFDDDDDDDDDFFFLLLLLLLLLBBBBBB", "Min2Phase.apply_moves_to_solved")

	# Test applying moves to scrambled cube
	var result2 = m2p.apply_moves(Min2Phase.SOLVED_CUBE, "U' R'")
	var expected = "UUBUUBUURFRRFRRFRRLLUFFUFFUDDLDDFDDFBBBLLLLLLDRRDBBDBB"
	assert_equal(result2, expected, "Min2Phase.apply_moves_inverse")
	var result3 = m2p.apply_moves(result2, "R U")
	assert_equal(result3, Min2Phase.SOLVED_CUBE, "Min2Phase.reapply_moves_inverse")

	# Test consistency between from_moves and apply_moves
	var moves = "U R U' R'"
	var from_result = m2p.from_moves(moves)
	var apply_result = m2p.apply_moves(Min2Phase.SOLVED_CUBE, moves)
	assert_equal(from_result, apply_result, "Min2Phase.from_moves_apply_moves_consistency")

func test_random_moves(m2p: Min2Phase):
	# Test that random moves generates correct length
	var moves_5 = m2p.random_moves(5)
	var tokens_5 = moves_5.split(" ", false)
	assert_equal(tokens_5.size(), 5, "Min2Phase.random_moves_count_5")

	var moves_10 = m2p.random_moves(10)
	var tokens_10 = moves_10.split(" ", false)
	assert_equal(tokens_10.size(), 10, "Min2Phase.random_moves_count_10")

	# Test no consecutive moves on same face
	var moves_20 = m2p.random_moves(20)
	var tokens_20 = moves_20.split(" ", false)
	var has_consecutive = false
	for i in range(tokens_20.size() - 1):
		if tokens_20[i][0] == tokens_20[i+1][0]:
			has_consecutive = true
			break
	assert_true(not has_consecutive, "Min2Phase.random_moves_no_consecutive_same_face")

	# Test that random moves actually scramble the cube
	var scrambled = m2p.from_moves(moves_10)
	assert_not_equal(scrambled, Min2Phase.SOLVED_CUBE, "Min2Phase.random_moves_actually_scrambles")

# ======================== SOLVE FUNCTION TESTS ========================

func test_solve_function():
	print("\n--- Testing Solve Function ---")

	var m2p: Min2Phase = min2phase.new()
	m2p._ready()
	# Test solving already solved cube
	test_solve_solved_cube(m2p)

	# Test solving simple scrambles
	test_solve_simple_scrambles(m2p)

	# Test solving with different max lengths
	test_solve_with_max_length(m2p)

func test_solve_solved_cube(m2p: Min2Phase):
	var solution = m2p.solve(m2p.SOLVED_CUBE)
	assert_true(solution.length() == 0, "Min2Phase.solve_already_solved", "Solution: '" + solution + "'")

func test_solve_simple_scrambles(m2p: Min2Phase):
	# Test solving after single move
	var scrambled = m2p.from_moves("U")
	var solution = m2p.solve(scrambled, 10)
	assert_true(solution.length() > 0 and not solution.begins_with("Error"),
		"Min2Phase.solve_after_U_move", "Solution: " + solution)

	var solved_cube = m2p.apply_moves(scrambled, solution)
	assert_equal(solved_cube, m2p.SOLVED_CUBE, "Min2Phase.solution_actually_solves")

	# Test solving after multiple moves
	scrambled = m2p.from_moves("U R U' R'")
	solution = m2p.solve(scrambled, 15)
	assert_true(solution.length() > 0 and not solution.begins_with("Error"),
		"Min2Phase.solve_after_multiple_moves", "Solution: " + solution)

func test_solve_with_max_length(m2p: Min2Phase):	
	var scrambled = m2p.from_moves("U R U' R' D B D")
		# Test with max length
	var solution = m2p.solve(scrambled, 7)

	assert_equal(solution, "D' B' D' R U R' U'", "Min2Phase.solve_max_length_7", "Solutsion: \"" + solution + "\"")

	# Test with max length of 20 (should succeed)
	solution = m2p.solve(scrambled, 20)
	assert_true(not solution.begins_with("Error"), "Min2Phase.solve_max_length_20_succeeds")

# ======================== ERROR HANDLING TESTS ========================

func test_error_handling():
	print("\n--- Testing Error Handling ---")

	var m2p = min2phase.new()
	m2p._ready()

	# Test invalid facelet length
	var result = m2p.solve("INVALID")
	assert_equal(result, "Error 1", "Min2Phase.invalid_length_error")

	# Test invalid facelet content
	result = m2p.solve("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
	assert_equal(result, "Error 1", "Min2Phase.invalid_content_error")

	# Test invalid moves in from_moves
	result = m2p.from_moves("U X R")
	assert_equal(result, "", "Min2Phase.invalid_moves_returns_empty")

	# Test invalid moves in apply_moves
	result = m2p.apply_moves(Min2Phase.SOLVED_CUBE, "U X R")
	assert_equal(result, "", "Min2Phase.apply_invalid_moves_returns_empty")

# ======================== EDGE CASES TESTS ========================

func test_edge_cases():
	print("\n--- Testing Edge Cases ---")

	var m2p = min2phase.new()
	m2p._ready()

	# Test maximum depth
	# test_maximum_depth(m2p)

	# Test random cube generation
	test_random_cube_generation(m2p)

func test_maximum_depth(m2p: Min2Phase):
	# Test with maximum depth of 1
	var scrambled = m2p.from_moves("U R")  # 2 moves, can't solve in 1
	var solution = m2p.solve(scrambled, 1)

	# Should fail to solve in 1 move
	assert_true(solution.begins_with("Error"), "Min2Phase.max_depth_1_fails")

func test_random_cube_generation(m2p: Min2Phase):
	# Test random cube generation
	var random_cube = m2p.random_cube()
	assert_equal(random_cube.length(), 54, "Min2Phase.random_cube_length")

	# Test that random cubes are different
	var random_cube2 = m2p.random_cube()
	# Very unlikely to be the same (but theoretically possible)
	assert_not_equal(random_cube, random_cube2, "Min2Phase.random_cubes_different")

	# Test that random cubes are solvable
	var solution = m2p.solve(random_cube, 25)
	assert_true(not solution.begins_with("Error"), "Min2Phase.random_cube_solvable")

# ======================== REAL WORLD SCENARIOS ========================

func test_real_world_scenarios():
	print("\n--- Testing Real World Scenarios ---")

	var m2p = min2phase.new()
	m2p._ready()

	# Test known solvable scrambles
	test_known_scrambles(m2p)

	# Test challenging scrambles
	test_challenging_scrambles(m2p)

	# Test systematic testing
	test_systematic_scrambles(m2p)

func test_known_scrambles(m2p: Min2Phase):
	# Test some simple known scrambles
	var simple_scrambles = [
		"U",
		"U R",
		"U R U' R'",
		"R U R' U R U2 R'",  # Sune algorithm
	]

	for i in range(simple_scrambles.size()):
		var scramble = simple_scrambles[i]
		var scrambled_cube = m2p.from_moves(scramble)
		assert_true(scrambled_cube.length() == 54, "Real.known_scramble_%d_valid" % i)
		assert_not_equal(scrambled_cube, Min2Phase.SOLVED_CUBE,
			"Real.known_scramble_%d_moves_correct" % i)

		var solution = m2p.solve(scrambled_cube, 20)
		assert_true(not solution.begins_with("Error"),
			"Real.known_scramble_%d_solvable" % i,
			"Scramble: %s, Solution: %s" % [scramble, solution])

		# Test that solution actually works
		if not solution.begins_with("Error") and solution.length() > 0:
			var solved_cube = m2p.apply_moves(scrambled_cube, solution)
			assert_equal(solved_cube, Min2Phase.SOLVED_CUBE,
				"Real.known_scramble_%d_solution_correct" % i)

func test_challenging_scrambles(m2p: Min2Phase):
	# Test a challenging scramble that should still be solvable
	var challenging_scramble = "R U R' F' R U R' U' R' F R2 U' R'"
	var scrambled_cube = m2p.from_moves(challenging_scramble)

	var solution = m2p.solve(scrambled_cube, 25)  # Give it more moves
	assert_true(not solution.begins_with("Error"),
		"Real.challenging_scramble_solvable",
		"Scramble: %s, Solution: %s" % [challenging_scramble, solution])

	# Test that solution actually works
	if not solution.begins_with("Error") and solution.length() > 0:
		var solved_cube = m2p.apply_moves(scrambled_cube, solution)
		assert_equal(solved_cube, Min2Phase.SOLVED_CUBE,
			"Real.challenging_scramble_solution_correct")

func test_systematic_scrambles(m2p: Min2Phase):
	# Test multiple random scrambles to see if the solver works reliably
	var successful_solves = 0
	var total_tests = 5  # Keep small for CLI testing

	for i in range(total_tests):
		var random_scramble = m2p.random_moves(8)  # Moderate scramble
		var scrambled_cube = m2p.from_moves(random_scramble)
		assert_not_equal(scrambled_cube, Min2Phase.SOLVED_CUBE,
			"Real.systematic_test_%d_moves_correct" % i)

		var solution = m2p.solve(scrambled_cube, 22)
		if not solution.begins_with("Error"):
			successful_solves += 1

			# Verify the solution works
			var solved_cube = m2p.apply_moves(scrambled_cube, solution)
			assert_equal(solved_cube, Min2Phase.SOLVED_CUBE,
				"Real.systematic_test_%d_solution_correct" % i)

	# We should solve at least some of them
	assert_true(successful_solves > 0,
		"Real.systematic_some_success",
		"Solved %d out of %d random scrambles" % [successful_solves, total_tests])

# ======================== PERFORMANCE TESTS ========================

func test_performance():
	print("\n--- Testing Performance ---")

	var m2p = min2phase.new()	
	m2p._ready()
	# Time how long simple solves take
	var start_time = Time.get_ticks_msec()
	var solution = m2p.solve(Min2Phase.SOLVED_CUBE)
	var solve_time = Time.get_ticks_msec() - start_time

	print("   Solved cube solve time: ", solve_time, "ms")
	assert_true(solve_time < 1000, "Performance.solved_cube_fast")  # Should be very fast
	var solved_cube = m2p.apply_moves(Min2Phase.SOLVED_CUBE, solution)
	assert_equal(solved_cube, Min2Phase.SOLVED_CUBE, "Performance.solved_cube_fast")
	
	# Time a simple scramble
	var scrambled = m2p.from_moves("U R U' R'")
	start_time = Time.get_ticks_msec()
	solution = m2p.solve(scrambled, 15)
	solve_time = Time.get_ticks_msec() - start_time

	print("   Simple scramble solve time: ", solve_time, "ms")
	assert_true(solve_time < 1000, "Performance.simple_scramble_reasonable")  # Should be reasonable
	solved_cube = m2p.apply_moves(scrambled, solution)
	assert_equal(solved_cube, Min2Phase.SOLVED_CUBE, "Performance.simple_scramble_reasonable")

	# Time a moderate scramble
	scrambled = m2p.from_moves("U R U' R' F R F'")
	start_time = Time.get_ticks_msec()
	solution = m2p.solve(scrambled, 20)
	solve_time = Time.get_ticks_msec() - start_time

	print("   Moderate scramble solve time: ", solve_time, "ms")
	assert_true(solve_time < 1000, "Performance.moderate_scramble_reasonable")  # Should be reasonable
	solved_cube = m2p.apply_moves(scrambled, solution)
	assert_equal(solved_cube, Min2Phase.SOLVED_CUBE, "Performance.moderate_scramble_reasonable")
