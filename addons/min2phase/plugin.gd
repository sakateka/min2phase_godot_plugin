@tool
extends EditorPlugin

func _enter_tree():
	# Add the Min2Phase autoload when plugin is enabled
	add_autoload_singleton("Min2PhaseInstance", "res://addons/min2phase/min2phase.gd")

func _exit_tree():
	# Remove the autoload when plugin is disabled
	remove_autoload_singleton("Min2PhaseInstance")
