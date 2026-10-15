extends Node
## SaveSystem autoload: the one save on disk, user://save_v1.json, written and read as the
## JSON of SaveModel (sim/core/save_model.gd), which owns the version, the migrations and
## the defaults (04_GUARDRAILS.md B7). This file only moves bytes: it never reads a save's
## contents itself. No save-scum helpers: one slot, overwritten on every save.

const SAVE_PATH := "user://save_v1.json"
## The error load_game() leaves in a model when there is no save on disk.
const ERROR_NO_FILE := "save_file_missing"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Writes the run as it stands, with the company when there is one. False when the file
## could not be written.
func save_game(world: WorldSim, rng: Rng, company: Company = null) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning(
			"save failed: %s (%s)" % [SAVE_PATH, error_string(FileAccess.get_open_error())]
		)
		return false
	file.store_string(JSON.stringify(SaveModel.to_dict(world, rng, company), "\t"))
	var error := file.get_error()
	file.close()
	return error == OK


## Reads the save back; balance is data/balance/world.json (the defaults for what the save
## does not hold); company_defs is what a Company is made from (see SaveModel.from_dict). A
## model with ok false and ERROR_NO_FILE when there is no save.
func load_game(balance: Dictionary, company_defs: Dictionary = {}) -> SaveModel:
	if not has_save():
		var missing := SaveModel.new()
		missing.error = ERROR_NO_FILE
		return missing
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	var saved: Dictionary = parsed if parsed is Dictionary else {}
	return SaveModel.from_dict(saved, balance, company_defs)
