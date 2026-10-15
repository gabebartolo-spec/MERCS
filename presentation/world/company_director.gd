class_name CompanyDirector
extends Node
## The thin inspect screen on screen (Phase 2 milestone 3): the company's roster with the
## captain marked, and for the merc you click their name, role in words, stats, the moves
## they have at their level, the stage-1 gear line, the three generic-gear slots and the
## experience bar, plus a button to give them the captain's office. The Company is the sim's
## and is shared with the rest of the game (the overworld saves it); this only words and
## shows it. Hiding the screen (set_open) keeps it as it is. Words: data/text/en.json;
## names, roles and gear lines are the director's content in data/mercs.json.

const MERCS_DATA := "res://data/mercs.json"
const BATTLE_DATA := "res://data/balance/battle.json"
const COMPANY_DATA := "res://data/balance/company.json"
const ECONOMY_DATA := "res://data/balance/economy.json"
const FACTIONS_DATA := "res://data/factions.json"
const EQUIPMENT_DATA := "res://data/equipment.json"
const RECRUITS_DATA := "res://data/recruits.json"
const WORLD_DATA := "res://data/balance/world.json"
const INJURY_RULES := "res://data/balance/injury.json"
const INJURY_DATA := "res://data/injuries.json"
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")
const SAVE_SYSTEM_PATH := ^"/root/SaveSystem"
const STAT_KEYS: Array[String] = [
	"hp", "attack", "defense", "damage", "initiative", "presence", "resolve"
]

var company: Company = null
## What the company has suffered: injuries, the chronicle, the memories (the game's one).
var wounds: CompanyWounds = null
var panel: CompanyPanel = null
## The overworld's autosave (writes only under Ironman), called after the captain is appointed.
var autosave := Callable()

var _layer: CanvasLayer = null
var _selected := ""


## What a Company is made from, read from the data files.
static func defs() -> Dictionary:
	var fighters: Variant = _json(BATTLE_DATA).get("fighters", {})
	return {
		"mercs": _json(MERCS_DATA),
		"fighters": fighters if fighters is Dictionary else {},
		"company": _json(COMPANY_DATA),
		"economy": _json(ECONOMY_DATA),
		"factions": _json(FACTIONS_DATA),
		"equipment": _json(EQUIPMENT_DATA),
		"recruits": _json(RECRUITS_DATA),
	}


## The company the game plays with: the one in the save on disk when there is one (a save
## from before the company reads as the starting six), else a new one. `from` is any node
## in the tree (the SaveSystem autoload is found from it).
static func load_company(from: Node) -> Company:
	var saves := from.get_node_or_null(SAVE_SYSTEM_PATH) as SAVE_SYSTEM
	if saves != null and saves.has_save():
		var model := saves.load_game(_json(WORLD_DATA), defs())
		if model.ok and model.company != null:
			return model.company
	return Company.start(defs())


## The wounds of `held`, from the "wounds" block of the save on disk when there is one. The
## Rng is a stand-in until the overworld binds the world's own (CompanyWounds.bind).
static func load_wounds(from: Node, held: Company) -> CompanyWounds:
	var saved := {}
	var saves := from.get_node_or_null(SAVE_SYSTEM_PATH) as SAVE_SYSTEM
	if saves != null and saves.has_save():
		var model := saves.load_game(_json(WORLD_DATA), defs())
		saved = model.wounds if model.ok else {}
	var injuries: Variant = _json(INJURY_DATA).get("injuries", [])
	var list: Array = injuries if injuries is Array else []
	return CompanyWounds.make(held, saved, Rng.from_seed(0), _json(INJURY_RULES), list)


## Builds the screen, hidden, for the company and wounds the save on disk holds (or new).
func begin_from_save(from: Node) -> void:
	var held := load_company(from)
	begin(held, load_wounds(from, held))


## Builds the screen, hidden, for `shared`, the company the game holds, and its wounds.
func begin(shared: Company, suffered: CompanyWounds = null) -> void:
	company = shared
	wounds = suffered if suffered != null else load_wounds(self, shared)
	_layer = CanvasLayer.new()
	add_child(_layer)
	panel = CompanyPanel.new()
	_layer.add_child(panel)
	panel.picked.connect(_pick)
	panel.appoint_requested.connect(_appoint)
	_selected = company.captain_id
	set_open(false)


func is_open() -> bool:
	return _layer != null and _layer.visible


## Shows the screen (redrawn) or hides it; nothing is lost either way.
func set_open(open: bool) -> void:
	if _layer == null:
		return
	_layer.visible = open
	if open:
		_show()


func _pick(merc_id: String) -> void:
	_selected = merc_id
	_show()


func _appoint(merc_id: String) -> void:
	company.appoint(merc_id)
	if autosave.is_valid():
		autosave.call()
	_show()


func _show() -> void:
	var rows: Array[Dictionary] = []
	for merc: Merc in company.roster:
		var mark := Text.t("company.mark.captain") if merc.id == company.captain_id else ""
		rows.append(
			{
				"id": merc.id,
				"label": Text.t("company.row", {"name": merc.display_name, "mark": mark})
			}
		)
	for entry: Dictionary in wounds.chronicle().entries:
		var gone := str(entry.get("merc", ""))
		var fallen_name := company.name_of(gone)
		rows.append({"id": gone, "label": Text.t("company.fallen.row", {"name": fallen_name})})
	var params := {"count": company.roster.size(), "cap": company.cap()}
	panel.show_roster(Text.t("company.panel.title", params), rows)
	var merc := company.member(_selected)
	if merc == null:
		panel.show_detail(_fallen_detail(_selected))
		return
	panel.show_detail(_detail(merc))


## The merc's details, in words.
func _detail(merc: Merc) -> Dictionary:
	var bar := merc.bar()
	var span: int = bar["span"]
	var earned: int = bar["xp"]
	var bar_key := "company.xp" if span > 0 else "company.xp_top"
	var params := {"xp": merc.xp, "into": earned, "span": span}
	var is_captain := merc.id == company.captain_id
	return {
		"id": merc.id,
		"header": Text.t("company.header", {"name": merc.display_name, "level": merc.level()}),
		"lines": _with_memories(merc),
		"bar_value": earned if span > 0 else 1,
		"bar_max": span if span > 0 else 1,
		"bar_text": Text.t(bar_key, params),
		"appoint_label":
		"" if is_captain else Text.t("company.appoint", {"name": merc.display_name}),
	}


## The detail of a dead merc: his chronicle line and that he is gone. Anyone else (or
## nobody) reads as the prompt to pick.
func _fallen_detail(merc_id: String) -> Dictionary:
	for entry: Dictionary in wounds.chronicle().entries:
		if entry.get("merc", "") == merc_id:
			var line := Text.t(
				"chronicle.death",
				{
					"name": company.name_of(merc_id),
					"day": Merc.whole(entry.get("day", 0)),
					"cause": TriageText.name_of(str(entry.get("cause", "")), company)
				}
			)
			return {
				"header": Text.t("company.fallen.title", {"name": company.name_of(merc_id)}),
				"lines": [line, Text.t("company.fallen.gone")]
			}
	return {"header": Text.t("company.panel.pick")}


## The merc's injuries in words (empty when there are none), then what a permanent one
## changes about the role.
func _injury_lines(merc: Merc) -> Array[String]:
	var lines: Array[String] = []
	var names: Array[String] = []
	for row: Dictionary in wounds.injuries_of(merc.id):
		var kind := str(row.get("kind", ""))
		var params := {
			"name": Text.t(str(row.get("name_key", ""))), "day": Merc.whole(row.get("until_day", 0))
		}
		names.append(Text.t("company.injury.%s" % kind, params))
		if str(row.get("role_key", "")) != "":
			lines.append(Text.t(str(row.get("role_key", ""))))
	if not names.is_empty():
		lines.insert(0, Text.t("company.injuries", {"list": ", ".join(names)}))
	return lines


## The merc's details as lines of words (also the hub's recruit inspection).
static func lines(merc: Merc) -> Array[String]:
	var lines: Array[String] = []
	if merc.placeholder:
		lines.append(Text.t("company.placeholder"))
	if merc.species != "":
		lines.append(Text.t("company.species", {"species": merc.species}))
	lines.append(merc.role)
	var stats: Array[String] = []
	for key: String in STAT_KEYS:
		stats.append(Text.t("company.stat." + key, {"value": shown_stat(merc, key)}))
	lines.append("   ".join(stats))
	var moves: Array[String] = []
	for move: String in merc.moves():
		moves.append(Text.t("company.move." + move))
	lines.append(Text.t("company.moves", {"moves": ", ".join(moves)}))
	lines.append(_next_line(merc))
	lines.append(_gear_line(merc))
	var slots: Array[String] = []
	for slot: String in Merc.SLOTS:
		var worn := str(merc.gear.get(slot, ""))
		var held := worn if worn != "" else Text.t("company.slot.empty")
		slots.append(Text.t("company.slot." + slot, {"gear": held}))
	lines.append("   ".join(slots))
	return lines


## A stat as the screen shows it: initiative is the one he acts at in a fight, his armour's
## slowness counted (Merc.fighting_initiative, the same rule the battle applies).
static func shown_stat(merc: Merc, key: String) -> int:
	if key == "initiative":
		var rules: Variant = _json(BATTLE_DATA).get("rules", {})
		return merc.fighting_initiative(rules if rules is Dictionary else {})
	return merc.stat(key)


## What the merc remembers, one sentence a line (the story director holds the memories).
func _with_memories(merc: Merc) -> Array[String]:
	var all := lines(merc) + _injury_lines(merc)
	all.append_array(_memory_lines(merc))
	return all


func _memory_lines(merc: Merc) -> Array[String]:
	var memory := StoryDirector.memory_of(self)
	var entries: Array[Dictionary] = memory.of(merc.id) if memory != null else []
	if entries.is_empty():
		return [Text.t("company.memories_none")]
	var lines: Array[String] = [Text.t("company.memories")]
	lines.append_array(MemoryWords.lines(entries, company))
	return lines


## One line of what the next level brings, from the merc's data (growth and new moves).
static func _next_line(merc: Merc) -> String:
	var next := merc.next_level()
	if next.is_empty():
		return Text.t("company.next_none")
	var parts: Array[String] = []
	var gains: Dictionary = next["growth"]
	for key: String in STAT_KEYS:
		if gains.has(key):
			var stat := Text.t("company.stat." + key, {"value": ""}).strip_edges()
			parts.append(Text.t("company.next.gain", {"value": gains[key], "stat": stat}))
	var fresh: Array = next["moves"]
	for move: Variant in fresh:
		parts.append(Text.t("company.next.move", {"move": Text.t("company.move." + str(move))}))
	return Text.t("company.next", {"level": next["level"], "gains": ", ".join(parts)})


static func _gear_line(merc: Merc) -> String:
	if merc.stage_1_gear.is_empty():
		return Text.t("company.gear_none")
	return Text.t("company.gear", {"gear": ", ".join(merc.stage_1_gear)})


static func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
