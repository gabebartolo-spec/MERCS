extends SceneTree
## A fresh Godot process on a save file (tests/economy/walkout_checks.gd), as a closed game
## reopens: Company.restore on the JSON at the first user argument, then one line (`LINE` and
## JSON) with the debt, who is owed, and the factions closed to advances. Not a suite.
##   godot --headless --path . --script tests/economy/restore_probe.gd -- <save.json>

const Fixture := preload("res://tests/lib/company_fixture.gd")
const LINE := "RESTORE_STATE "


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var saved: Dictionary = parsed if parsed is Dictionary else {}
	var company := Company.restore(saved, Fixture.defs())
	var economy := company.economy
	var whole := {
		"owed": economy.owed,
		"dues": economy.payroll.dues,
		"no_advance": economy.standing.no_advance,
		"fallen": company.fallen,
	}
	print(LINE + JSON.stringify(whole))
	quit(0)
