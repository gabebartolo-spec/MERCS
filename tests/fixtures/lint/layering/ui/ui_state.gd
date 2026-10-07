extends Node
# Deliberately misplaced autoload: project.godot registers this ui script as UiState,
# so presentation and sim scripts that reference it reach upwards.

var open_screens: int = 0


func reset() -> void:
	open_screens = 0
