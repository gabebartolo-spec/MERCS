class_name StoryDirector
extends Node
## The storylet on screen (Phase 2 M7), a helper SliceGame attaches once. It holds the run's
## memories and the storylets fired (read from the save on disk at the start, handed back to
## SaveSystem whenever the game saves), links itself to the F2 overworld map once that exists
## and, when the company rests, asks the sim (StoryBook) whether a storylet is eligible. If
## one is, a LoopPanel over the map shows the scene with the cast named and one choice per
## way to attempt the visible check, each with its odds; after the pick it shows the roll
## and the outcome line. It also gives the loop example the memories to write to, and the
## F4 inspect screen the memories to show. The sim decides everything; this words and shows
## it. Words: data/text/en.json (the storylet's are placeholders, the director's to write).

const STORYLETS_DATA := "res://data/storylets.json"
const WORLD_DATA := "res://data/balance/world.json"
const NODE_NAME := &"StoryDirector"
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")
const SAVE_SYSTEM_PATH := ^"/root/SaveSystem"
const CLOSE := "close"
const ATTEMPT_PREFIX := "attempt:"
const HOOK_REST := "rest"
## A prisoner's fate in the chronicle; the prefix of every other chronicle line's memory.
const PRISONER_PREFIX := "prisoner."
const MEMORY_PREFIX := "memory."
const HUB_PREFIX := "hub."
## Above the overworld's layer, so the scene covers its choices while it is up.
const LAYER := 2

var memory := Memory.new()
var state := StoryletState.new()
var book: StoryBook = null
var panel: LoopPanel = null
## The scene on screen ({} when none), and the last check's result ({} before one).
var offer := {}
var result := {}

var _game: SliceGame = null
var _layer: CanvasLayer = null
var _linked: OverworldDirector = null
var _open := false
## An offer the save held, shown once the map is linked.
var _resumed := {}
## How many of the economy's decision lines are already in the memories.
var _decisions_seen := 0


## Attaches a director to the game and reads the save on disk, if there is one.
static func attach(game: SliceGame) -> StoryDirector:
	var director := StoryDirector.new()
	director.name = NODE_NAME
	game.add_child(director)
	director.begin()
	return director


## The memories of the game this node belongs to (null when it has no story director).
static func memory_of(from: Node) -> Memory:
	var parent := from.get_parent()
	var found := parent.get_node_or_null(NodePath(NODE_NAME)) if parent != null else null
	return (found as StoryDirector).memory if found is StoryDirector else null


func begin() -> void:
	_game = get_parent() as SliceGame
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	_layer.visible = false
	add_child(_layer)
	panel = LoopPanel.new()
	_layer.add_child(panel)
	panel.chosen.connect(_on_story_choice)
	var saves := get_node_or_null(SAVE_SYSTEM_PATH) as SAVE_SYSTEM
	if saves == null:
		return
	saves.extras = _extras
	if saves.has_save():
		var model := saves.load_game(_json(WORLD_DATA))
		if model.ok:
			var kept: Variant = model.wounds.get("memories", {})
			memory = Memory.restore(_dict(kept))
			state = StoryletState.restore(model.story)
			var held: Variant = model.story.get("offer", {})
			_resumed = _dict(held)


## Whether the storylet's scene is on screen.
func is_open() -> bool:
	return _open


## Asks the sim for an eligible storylet in this context ({"hook", "day", "site",
## "site_kind"}; see StoryBook) and shows it. False, and nothing shown, when none is eligible,
## one is already up or the map is not linked yet. Called on a rest, and open to other hooks.
func try_fire(context: Dictionary) -> bool:
	if book == null or _open or _linked.in_fight():
		return false
	var made := book.offer(context)
	if made.is_empty():
		return false
	_show_offer(made)
	_linked.autosave()
	return true


func _show_offer(made: Dictionary) -> void:
	offer = made
	result = {}
	_open = true
	_linked.panel.visible = false
	_show_scene()


## The context a rest or an arrival gives, from the world as it stands.
static func context_for(world: WorldSim, hook: String) -> Dictionary:
	var here := world.site(world.at)
	var kinds: Array = WorldSite.Kind.keys()
	var kind := str(kinds[here.kind]).to_lower() if here != null else ""
	return {"hook": hook, "day": world.day, "site": world.at, "site_kind": kind}


func _process(_delta: float) -> void:
	var overworld := _game.overworld_director() if _game != null else null
	if overworld != null and overworld != _linked and overworld.panel != null:
		_link(overworld)
	var loop_director := _game.loop_director() if _game != null else null
	if loop_director != null:
		loop_director.loop.memory = memory
		loop_director.loop.day = overworld.world.day if overworld != null else 0
	_layer.visible = _open and overworld != null and overworld.is_open()
	_remember_decisions()


func _link(overworld: OverworldDirector) -> void:
	_linked = overworld
	book = StoryBook.new()
	book.company = overworld.company
	book.memory = memory
	book.state = state
	book.rng = overworld.rng
	book.load_defs(_json(STORYLETS_DATA))
	overworld.panel.chosen.connect(_on_overworld_choice)
	if not _resumed.is_empty() and not _open:
		if _resumable(_resumed):
			_show_offer(_resumed)
		else:
			push_warning(
				"StoryDirector: dropped a saved offer for an unknown storylet or no options"
			)
	_resumed = {}
	_decisions_seen = book.company.economy.chronicle.size() if book.company != null else 0


## Whether a saved offer can still be played: its storylet exists and it lists an attempt.
func _resumable(held: Dictionary) -> bool:
	var raw: Variant = held.get("attempts", [])
	var attempts: Array = raw if raw is Array else []
	return not attempts.is_empty() and not book.definition(str(held.get("id", ""))).is_empty()


## The hub's decisions (the economy's chronicle lines, {"day", "merc", "key"}) become a memory
## sentence on the merc who remembers them, once each.
func _remember_decisions() -> void:
	if book == null or book.company == null:
		return
	var lines := book.company.economy.chronicle
	while _decisions_seen < lines.size():
		var line := lines[_decisions_seen]
		var key := memory_key(str(line.get("key", "")))
		memory.record(str(line.get("merc", "")), key, {}, Injury.num(line, "day"))
		_decisions_seen += 1


## The memory key of a chronicle line's key: a prisoner's fate ("prisoner.<choice>") is
## "memory.fate_<choice>"; any other is "memory." + it without a leading "hub."
## ("standing.grudge" -> "memory.standing.grudge", "hub.terms.step_in_won" ->
## "memory.terms.step_in_won").
static func memory_key(chronicle_key: String) -> String:
	if chronicle_key.begins_with(PRISONER_PREFIX):
		return Memory.KEY_FATE_PREFIX + chronicle_key.trim_prefix(PRISONER_PREFIX)
	return MEMORY_PREFIX + chronicle_key.trim_prefix(HUB_PREFIX)


func _on_overworld_choice(choice_id: String) -> void:
	if choice_id == OverworldDirector.REST:
		try_fire(context_for(_linked.world, HOOK_REST))


func _on_story_choice(choice_id: String) -> void:
	if choice_id == CLOSE:
		_close()
	elif choice_id.begins_with(ATTEMPT_PREFIX):
		result = book.choose(offer, choice_id.trim_prefix(ATTEMPT_PREFIX))
		if not result.is_empty():
			_linked.autosave()
			_show_outcome()


func _show_scene() -> void:
	var def := book.definition(str(offer.get("id", "")))
	var choices: Array[Dictionary] = []
	var options := _options()
	for option: Dictionary in options:
		var params := _names(_dict(offer.get("cast", {})))
		params.merge(
			{
				"name": _name(str(option.get("merc", ""))),
				"skill": Injury.num(option, "skill"),
				"odds": Injury.num(option, "odds"),
				"need": Injury.num(option, "need")
			}
		)
		choices.append(
			{
				"id": ATTEMPT_PREFIX + str(option.get("role", "")),
				"label": Text.t(_label_key(def, str(option.get("role", ""))), params)
			}
		)
	var scene := Text.t(str(def.get("scene_key", "")), _names(_dict(offer.get("cast", {}))))
	panel.present(Text.t(str(def.get("title_key", ""))), scene, choices)


func _show_outcome() -> void:
	var def := book.definition(str(result.get("id", "")))
	var roll_params := {
		"roll": result.get("roll", 0), "need": result.get("need", 0), "sides": _sides(def)
	}
	var lines: Array[String] = [
		Text.t(str(result.get("line_key", "")), _names(_dict(offer.get("cast", {})))),
		Text.t("storylet.roll", roll_params),
		Text.t("storylet.result.%s" % str(result.get("branch", "")))
	]
	var again: Array[Dictionary] = [{"id": CLOSE, "label": Text.t("storylet.continue")}]
	panel.present(Text.t(str(def.get("title_key", ""))), "\n".join(lines), again)


func _close() -> void:
	_open = false
	offer = {}
	panel.visible = false
	_layer.visible = false
	if _linked != null:
		_linked.panel.visible = true


## The save's optional blocks. With Ironman On an offer still up (cast drawn, no attempt yet) is
## kept in the story block, so a quit can't have the next rest draw a different cast.
func _extras() -> Dictionary:
	var story := state.state()
	var saves := get_node_or_null(SAVE_SYSTEM_PATH) as SAVE_SYSTEM
	if _open and result.is_empty() and not offer.is_empty() and saves != null and saves.ironman:
		story["offer"] = offer.duplicate(true)
	return {"wounds": {"memories": memory.state()}, "story": story}


func _options() -> Array[Dictionary]:
	var listed: Variant = offer.get("attempts", [])
	var out: Array[Dictionary] = []
	for raw: Variant in listed if listed is Array else []:
		if raw is Dictionary:
			var option: Dictionary = raw
			out.append(option)
	return out


func _label_key(def: Dictionary, role: String) -> String:
	var attempts: Variant = _dict(def.get("check", {})).get("attempts", [])
	for raw: Variant in attempts if attempts is Array else []:
		var option := _dict(raw)
		if option.get("role", "") == role:
			return str(option.get("label_key", ""))
	return ""


func _sides(def: Dictionary) -> int:
	return Injury.num(_dict(def.get("check", {})), "die_sides")


## {role: the merc's name} for every role in the cast, to fill the storylet's words.
func _names(cast: Dictionary) -> Dictionary:
	var out := {}
	for role: Variant in cast:
		out[str(role)] = _name(str(cast[role]))
	return out


func _name(merc_id: String) -> String:
	return book.company.name_of(merc_id)


static func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
