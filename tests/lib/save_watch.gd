extends RefCounted
## The runtime guard of the Ironman save order (CampaignSaves "Save order"; tools/lint/save_order.py
## is only its tripwire). A scripted campaign calls settle() after every input it makes, naming
## what the input was:
##   DECISION  the save on disk must equal what an autosave would write now: a change the input
##             made after its save (later in the call, a deferred call, a timer, a later frame's
##             poll) shows up as a difference;
##   VIEW      opening, closing or reading a screen (Continue, B, M, Close): the run must not
##             change at all, so a change parked for that input (main's loot-at-Continue bug) shows;
##   WALK      a step on the map: saved only when it met an encounter or ended a day (lead ruling
##             under D-087), so only those steps are held to the DECISION rule.
## Problems collect in `problems`, one line each. Settling waits SETTLE frames first, so a poll or a
## short timer has run; a timer longer than that is not seen.

const Probe := preload("res://tests/ironman_resume/reload_probe.gd")
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")
const InputKit := preload("res://tests/lib/input_kit.gd")
const DECISION := "decision"
const VIEW := "view"
const WALK := "walk"
const SETTLE := 12
const SHOWN := 3

var problems: Array[String] = []
var inputs := 0

var _tree: SceneTree = null
var _game: SliceGame = null
var _before := ""
var _day := -1


func watch(tree: SceneTree, game: SliceGame) -> void:
	_tree = tree
	_game = game
	_before = Probe.snapshot(game)
	_day = _world_day()


## After one input of `kind` (DECISION, VIEW or WALK), labelled for the report.
func settle(label: String, kind: String) -> void:
	await InputKit.frames(_tree, SETTLE)
	inputs += 1
	var now := Probe.snapshot(_game)
	var day := _world_day()
	var map := _game.overworld_director()
	var met := map != null and not map.world.encounter.is_empty()
	if kind == VIEW and now != _before:
		_report(label, "a view input changed the run", _before, now)
	elif kind == DECISION or (kind == WALK and (day != _day or met)):
		var disk := _disk()
		var would := _would_write()
		if disk != would:
			_report(label, "the save on disk is not the run as it stands", disk, would)
	_before = now
	_day = day


func _world_day() -> int:
	var map := _game.overworld_director()
	return map.world.day if map != null else -1


## What an autosave would write now (the fight's record during a fight), as sorted JSON.
func _would_write() -> String:
	var map := _game.overworld_director()
	if map == null:
		return ""
	var saves := _tree.root.get_node(^"SaveSystem") as SAVE_SYSTEM
	var store: CampaignSaves = map._store
	var saved: Dictionary
	if store._fight != null:
		saved = store._fight.saved()
	else:
		saved = saves.to_save(map.world, map.rng, map.company, map.wounds.state())
	return _canon(JSON.stringify(saved))


func _disk() -> String:
	if not FileAccess.file_exists(SAVE_SYSTEM.SAVE_PATH):
		return ""
	return _canon(FileAccess.get_file_as_string(SAVE_SYSTEM.SAVE_PATH))


## JSON text with sorted keys and every number as JSON reads it back, so equal runs compare equal.
static func _canon(text: String) -> String:
	return JSON.stringify(JSON.parse_string(text), "", true)


func _report(label: String, what: String, was: String, now: String) -> void:
	problems.append("%s: %s (%s)" % [label, what, _first_difference(was, now)])


## Where two JSON texts first differ, a few characters either side.
static func _first_difference(was: String, now: String) -> String:
	var at := 0
	var shortest := mini(was.length(), now.length())
	while at < shortest and was[at] == now[at]:
		at += 1
	var from := maxi(0, at - 40)
	return "%s | %s" % [was.substr(from, 80), now.substr(from, 80)]


## The first `SHOWN` problems on one line each, for the suite's log.
func summary() -> String:
	return "\n".join(problems.slice(0, SHOWN))
