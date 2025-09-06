extends Control

# Interactive UI for testing the Min2Phase plugin

@onready var output_text: TextEdit = $VBox/OutputText
@onready var facelet_input: LineEdit = $VBox/InputSection/FaceletInput
@onready var moves_input: LineEdit = $VBox/InputSection/MovesInput
@onready var solve_button: Button = $VBox/ButtonSection/SolveButton
@onready var random_button: Button = $VBox/ButtonSection/RandomButton
@onready var scramble_button: Button = $VBox/ButtonSection/ScrambleButton
@onready var apply_moves_button: Button = $VBox/ButtonSection/ApplyMovesButton
@onready var clear_button: Button = $VBox/ButtonSection/ClearButton
@onready var reset_cube: Button = $VBox/ButtonSection/ResetCube

const solved_cube = "UUUUUUUUURRRRRRRRRFFFFFFFFFDDDDDDDDDLLLLLLLLLBBBBBBBBB"
var current_cube: String = ""

func _ready():
	display_output("Min2Phase Test UI loaded")
	display_output("=== Min2Phase Rubik's Cube Solver Test UI ===")
	display_output("Use the buttons below to test different functions")
	display_output("")
	
	# Connect button signals
	solve_button.pressed.connect(_on_solve_pressed)
	random_button.pressed.connect(_on_random_pressed)
	scramble_button.pressed.connect(_on_scramble_pressed)
	apply_moves_button.pressed.connect(_on_apply_moves_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	reset_cube.pressed.connect(_on_reset_pressed)


	# Set default solved cube
	current_cube = solved_cube
	facelet_input.text = current_cube

# Helper function to display text in both console and UI
func display_output(text: String):
	print(text)
	output_text.text += text + "\n"
	output_text.scroll_vertical = output_text.get_line_count() + 10


func _on_solve_pressed():
	var facelet = facelet_input.text.strip_edges()
	if facelet.length() != 54:
		display_output("ERROR: Facelet must be exactly 54 characters")
		return
	
	display_output("--- Solving Cube ---")
	display_output("Input: " + facelet)
	
	var start_time = Time.get_unix_time_from_system()
	var solution = Min2PhaseInstance.solve(facelet, 21)
	var end_time = Time.get_unix_time_from_system()
	
	var solve_time = end_time - start_time
	
	if solution.begins_with("Error"):
		display_output("FAILED: " + solution)
	else:
		var move_count = solution.split(" ").size()
		display_output("SUCCESS: " + solution)
		display_output("Moves: " + str(move_count) + ", Time: " + "%.3f" % solve_time + "s")
		moves_input.text = solution
	display_output("")

func _on_random_pressed():
	display_output("--- Generating Random Cube ---")
	current_cube = Min2PhaseInstance.random_cube()
	facelet_input.text = current_cube
	display_output("Generated: " + current_cube)
	display_output("")

func _on_scramble_pressed():
	var n_moves = 20
	display_output("--- Generating " + str(n_moves) + " Random Moves ---")
	var moves = Min2PhaseInstance.random_moves(n_moves)
	moves_input.text = moves
	display_output("Moves: " + moves)
	
	current_cube = Min2PhaseInstance.from_moves(moves)
	if current_cube != "":
		facelet_input.text = current_cube
		display_output("Scrambled cube: " + current_cube)
	else:
		display_output("ERROR: Failed to apply moves")
	display_output("")
	
func _on_reset_pressed():
	display_output("--- Reset cube ---")
	moves_input.text = ""
	facelet_input.text = solved_cube

func _on_apply_moves_pressed():
	var moves = moves_input.text.strip_edges()
	var facelet = facelet_input.text.strip_edges()
	
	if moves == "":
		display_output("ERROR: Enter moves to apply")
		return
		
	if facelet.length() != 54:
		display_output("ERROR: Invalid facelet string")
		return
	
	display_output("--- Applying Moves ---")
	display_output("Cube: " + facelet)
	display_output("Moves: " + moves)
	
	var result = Min2PhaseInstance.apply_moves(facelet, moves)
	if result != "":
		current_cube = result
		facelet_input.text = result
		display_output("Result: " + result)
	else:
		display_output("ERROR: Failed to apply moves")
	display_output("")

func _on_clear_pressed():
	output_text.text = ""
	display_output("=== Output Cleared ===")
