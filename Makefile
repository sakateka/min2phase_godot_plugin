.PHONY: test solve help

help:
	@echo "Available targets:"
	@echo "  test     - Run the test script"
	@echo "  solve    - Solve scrambles from a file (usage: make solve scrambles=filename.txt)"
	@echo "  help     - Show this help message"
	@echo ""
	@echo "Example usage:"
	@echo "  make test"
	@echo "  make solve scrambles=my_scrambles.txt"

test:
	godot --headless --script ./test.gd

solve:
	@if [ -z "$(scrambles)" ]; then \
		echo "Error: 'scrambles' variable is required"; \
		echo "Usage: make solve scrambles=filename.txt"; \
		exit 1; \
	fi
	godot --headless --script ./scrambles_solver.gd $(scrambles)
