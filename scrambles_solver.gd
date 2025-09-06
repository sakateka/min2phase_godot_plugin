#!/usr/bin/env -S godot -s

# Min2Phase Scrambles Solver
# Headless script that mimics the functionality of scrambles_solver.rs
# Usage: godot -s scrambles_solver.gd <filename>
#
# The script reads scramble sequences from a file, converts them to facelet
# representation, solves them, and outputs results with timing information.

extends SceneTree

# Import the plugin components
var min2phase: Script

# ANSI color codes for terminal output
const RED = "\u001b[31m"
const YELLOW = "\u001b[33m"
const BRIGHT_YELLOW = "\u001b[93m"
const GREEN = "\u001b[32m"
const RESET = "\u001b[0m"

func _init():
	min2phase = preload("res://addons/min2phase/min2phase.gd")
	print("Scrambles solver ready")
	# Get command line arguments
	var args = OS.get_cmdline_args()
	
	# Check if filename is provided
	if args.size() < 3:
		print("Usage: godot -s scrambles_solver.gd <filename>")
		print("You can download files with scrambles from this page: https://kociemba.org/cube.htm")
		quit(1)
		return

	var filename = args[2]
	
	print("Processing file: ", filename)

	# Check if file exists
	if not FileAccess.file_exists(filename):
		print("Error: File '", filename, "' not found")
		quit(1)
		return
	
	# Initialize the min2phase solver
	var m2p = min2phase.new()
	m2p._ready()
	
	# Process the file
	process_scrambles_file(m2p, filename)
	
	# Exit when done
	quit(0)

func process_scrambles_file(m2p: Min2Phase, filename: String):
	var file = FileAccess.open(filename, FileAccess.READ)
	if file == null:
		print("Error: Could not open file '", filename, "'")
		quit(1)
		return
	
	var line_num = 0
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		line_num += 1
		
		if line.is_empty():
			continue
		
		var facelet = m2p.from_moves(line)
		
		if facelet.is_empty():
			print("L=", line_num, ": ", RED, "Error", RESET)
			file.close()
			quit(1)
			return
		
		# Solve the cube and measure time
		var start_time = Time.get_ticks_msec()
		var solution = m2p.solve(facelet, 21)
		var duration_ms = Time.get_ticks_msec() - start_time
		
		var timing_str = format_timing(duration_ms)
		
		var solved_cube = m2p.apply_moves(facelet, solution)
		var result = GREEN + "OK" + RESET
		if solved_cube != Min2Phase.SOLVED_CUBE:
			result = RED + "ERR" + RESET

		print(line_num, ": took=", timing_str, " facelet=", facelet, " ", result, " Solution=", solution)
	
	file.close()

func format_timing(duration_ms: int) -> String:
	if duration_ms > 10000:
		return RED + str(duration_ms as float/1000.0) + "s" + RESET
	elif duration_ms > 3000:
		return RED + str(duration_ms) + "ms" + RESET
	elif duration_ms > 1000:
		return YELLOW + str(duration_ms) + "ms" + RESET
	elif duration_ms > 100:
		return BRIGHT_YELLOW + str(duration_ms) + "ms" + RESET
	else:
		return str(duration_ms) + "ms"
