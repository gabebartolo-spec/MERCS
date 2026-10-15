extends Node
## SaveSystem autoload: the one save on disk, user://save_v1.json, written and read as the
## JSON of SaveModel (sim/core/save_model.gd), which owns the version, the migrations and
## the defaults (04_GUARDRAILS.md B7). This file only moves bytes: it never reads a save's
## contents itself. No save-scum helpers: one slot, overwritten on every save.

const SAVE_PATH := "user://save_v1.json"
## The error load_game() leaves in a model when there is no save on disk.
const ERROR_NO_FILE := "save_file_missing"

## Set by whoever holds the optional blocks of the save (the story director: memories and
## the storylets fired). Called at save time; returns {"wounds": {...}, "story": {...}}.
var extras: Callable = Callable()
## The campaign's mode (SaveModel "ironman"), set by whoever plays the campaign before it saves.
var ironman := false


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Writes the run as it stands (to_save()). False when the file could not be written.
func save_game(world: WorldSim, rng: Rng, company: Company = null, wounds: Dictionary = {}) -> bool:
	return write(to_save(world, rng, company, wounds))


## The run as it stands as a save, with the company and its wounds block
## (CompanyWounds.state()) when there are some and the story block (extras). A company with
## every merc dead marks the save ended (SaveModel), after which it only ever shows the
## chronicle. Made with `ironman` as the caller set it.
func to_save(
	world: WorldSim, rng: Rng, company: Company = null, wounds: Dictionary = {}
) -> Dictionary:
	var saved := SaveModel.to_dict(
		world, rng, company, wounds, company != null and company.is_wiped(), ironman
	)
	if extras.is_valid():
		var more: Dictionary = extras.call()
		var story: Variant = more.get("story", {})
		var block: Dictionary = story if story is Dictionary else {}
		saved = SaveModel.with_story(saved, block)
	return saved


## Writes a save made by to_save() (or an Ironman fight's, FightRecord.saved()) to the one slot.
## False when the file could not be written.
func write(saved: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning(
			"save failed: %s (%s)" % [SAVE_PATH, error_string(FileAccess.get_open_error())]
		)
		return false
	file.store_string(JSON.stringify(saved, "\t"))
	var error := file.get_error()
	file.close()
	return error == OK


## Removes the save on disk only when its campaign is over: the chronicle has been read and a
## new campaign may begin. A save that can still be played is never touched (one slot, no
## save-scum helper). True when an ended save was removed.
func close_ended(balance: Dictionary, company_defs: Dictionary = {}) -> bool:
	if not has_save() or not load_game(balance, company_defs).ended:
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH)) == OK


## Reads the save back; balance is data/balance/world.json (the defaults for what the save
## does not hold); company_defs is what a Company is made from (see SaveModel.from_dict). A
## model with ok false and ERROR_NO_FILE when there is no save; with ok false, `ended` true and
## ERROR_ENDED (SaveModel) when the campaign is over: nothing plays on from it.
func load_game(balance: Dictionary, company_defs: Dictionary = {}) -> SaveModel:
	if not has_save():
		var missing := SaveModel.new()
		missing.error = ERROR_NO_FILE
		return missing
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	var saved: Dictionary = parsed if parsed is Dictionary else {}
	return SaveModel.from_dict(saved, balance, company_defs)
