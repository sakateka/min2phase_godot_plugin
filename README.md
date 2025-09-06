# Min2Phase Rubik's Cube Solver - Godot Plugin

A GDScript port of the min2phase algorithm for solving Rubik's cubes in Godot. This plugin provides optimal solutions using the two-phase algorithm.

## Installation

1. Download or clone this plugin
2. Copy the `addons/min2phase` folder to your Godot project's `addons/` directory
3. Enable the plugin in Project Settings → Plugins
4. The `Min2PhaseInstance` autoload will be automatically available in your project

## Quick Start

```gdscript
extends Node

func _ready():
	# Generate a random scrambled cube
	var scrambled_cube = Min2PhaseInstance.random_cube()
	print("Scrambled: ", scrambled_cube)
	
	# Solve the cube
	var solution = Min2PhaseInstance.solve(scrambled_cube, 21)
	print("Solution: ", solution)
	
	# Generate random moves
	var moves = Min2PhaseInstance.random_moves(20)
	print("Random moves: ", moves)
	
	# Apply moves to a cube
	var cube_after_moves = Min2PhaseInstance.from_moves(moves)
	print("Result: ", cube_after_moves)
```

## Scrambles Solver

A high-performance scrambles solver is [available here](https://github.com/sakateka/scrambles_solver)

The project includes a command-line tool `scrambles_solver.gd` for batch processing scramble files. This tool can solve multiple scrambles from a text file and output the solutions.

### Usage

```bash
# Using the Makefile (recommended)
make solve scrambles=your_scrambles.txt

# Or directly with Godot
godot --headless --script ./scrambles_solver.gd your_scrambles.txt
```

### Scrambles Format

The scrambles file should contain one scramble per line in standard notation (e.g., `R U R' U' F2 D L2`). Empty lines are ignored.

### Getting Scrambles

You can download official WCA scrambles from:
- **[Cube20 Distance-20 Positions](https://cube20.org/distance20s/)** - Known distance-20 positions in half-turn metric
- **[WCA Scrambles](https://www.worldcubeassociation.org/export/results)** - Official competition scrambles

### Example

```bash
# Create a scrambles file
echo "R U R' U' F2 D L2" > my_scrambles.txt
echo "F R U R' U' F'" >> my_scrambles.txt

# Solve them
make solve scrambles=my_scrambles.txt
```

## Facelet Format

The cube is represented as a 54-character string following this layout:

```
         +--------+
         |U1 U2 U3|
         |U4 U5 U6|
         |U7 U8 U9|
+--------+--------+--------+--------+
|L1 L2 L3|F1 F2 F3|R1 R2 R3|B1 B2 B3|
|L4 L5 L6|F4 F5 F6|R4 R5 R6|B4 B5 B6|
|L7 L8 L9|F7 F8 F9|R7 R8 R9|B7 B8 B9|
+--------+--------+--------+--------+
         |D1 D2 D3|
         |D4 D5 D6|
         |D7 D8 D9|
         +--------+
```

The string format is: `U1U2...U9R1R2...R9F1...F9D1...D9L1...L9B1...B9`

**Solved cube:** `UUUUUUUUURRRRRRRRRFFFFFFFFFDDDDDDDDDLLLLLLLLLBBBBBBBBB`

## Move Notation

Moves follow standard Rubik's cube notation:

- **U, R, F, D, L, B**: 90° clockwise turns
- **U', R', F', D', L', B'**: 90° counterclockwise turns  
- **U2, R2, F2, D2, L2, B2**: 180° turns

**Examples:**
- `R U R' U'` - Right, Up, Right counter-clockwise, Up counter-clockwise
- `F2 R U' D2` - Front 180°, Right, Up counter-clockwise, Down 180°

## Error Codes

When solving fails, the function returns "Error X" where X is:

- **1**: Invalid facelet string format
- **2**: Invalid edge configuration
- **3**: Edge orientation parity error
- **4**: Invalid corner configuration  
- **5**: Corner orientation parity error
- **6**: Permutation parity error between corners and edges
- **8**: No solution found within move limit

## Performance Notes

- The solver typically finds solutions in 0.01-3.0 seconds for most cubes
- Some very rare hard cases can take up to 30 minutes
- Solutions are usually 15-25 moves in length
- The algorithm is deterministic - same input always gives same output
- For real-time applications, consider solving on a background thread

## Technical Details

This plugin implements a simplified version of the two-phase algorithm:

1. **Phase 1**: Reduce the cube to a subgroup where only certain moves are needed
2. **Phase 2**: Solve the cube within that restricted subgroup

## License

This plugin is released under the MIT License.
