extends Node
## Planted save-order cases for tools/lint/save_order.py (never loaded by Godot: .gdignore).
## Lines named in expected.txt are errors; every other function here must pass.

var autosave := Callable()
var memory: Memory = null
var world: WorldSim = null
var economy: Economy = null
var _after := Callable()
var panel: Control = null


# SAVE-LATE: the purse changes after the save was written.
func late_pay() -> void:
	autosave.call()
	economy.purse -= 1
	_show()


# Passes: everything first, the save, then only redraws and a return.
func pay_then_save() -> void:
	economy.purse -= 1
	autosave.call()
	_show()
	panel.visible = true
	return


# Passes: the other match arms and else branches cannot run after this arm's save.
func on_choice(choice: String) -> void:
	match choice:
		"rest":
			world.rest()
			autosave()
			_show()
		"toll":
			world.pay_toll()
			autosave()
		_:
			economy.purse += 1


# SAVE-LATE, once: either branch of an if after the save runs after it (a second save is fine).
func late_branches(choice: String) -> void:
	autosave()
	if choice == "x":
		autosave()
	else:
		economy.purse += 2


# SAVE-LATE: a statement after the enclosing if still runs after the save.
func late_after_block(choice: String) -> void:
	if choice == "pay":
		economy.purse -= 1
		autosave()
	economy.owed = 0


# SAVE-PARKED, twice: a hook kept for a later input, directly and through a local.
func park() -> void:
	_after = world.result_hook.bind("ambush", {})
	var hook := world.result_hook
	_after = hook.bind("ambush", {})


# SAVE-POLL: _process writes memories through a function no save waits for.
func _process(_delta: float) -> void:
	_catch_up()
	_observed()


func _catch_up() -> void:
	memory.record("m", "k", {}, 1)


func _observed() -> void:
	memory.on_choice(["m"], "k", 1)


func _ready() -> void:
	before_save(_observed)


func before_save(_observer: Callable) -> void:
	pass


func panel_redraw() -> void:
	pass


func _show() -> void:
	pass
