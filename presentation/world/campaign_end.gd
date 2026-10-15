class_name CampaignEnd
extends Node
## The last screen of a campaign (director, 2026-10-15: "If every merc in the company dies:
## Campaign ends"): the company's dead, each with the day, the cause and what they
## remembered, in the words of data/text/en.json, and one button that closes the record and
## begins again on the street (there is no title screen yet). It opens after a wipe
## (OverworldDirector) and whenever the game starts on a save whose campaign is over; the
## save is never played on (SaveModel.ended). Presentation only: the sim decided the wipe.

signal finished

const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")
const SAVE_SYSTEM_PATH := ^"/root/SaveSystem"
const COMPANY_DATA := "res://data/balance/company.json"
const WORLD_DATA := "res://data/balance/world.json"
const BEGIN := "begin"
const LAYER := 5

var panel: LoopPanel = null

var _layer: CanvasLayer = null
var _open := false


## The screen over `game`, shown, for the dead of `chronicle` (names from `company`, what they
## remembered from `memory`).
static func open_for(
	game: Node, company: Company, chronicle: Chronicle, memory: Memory
) -> CampaignEnd:
	var screen := CampaignEnd.new()
	game.add_child(screen)
	screen.show_record(company, chronicle, memory)
	return screen


## The screen for the save on disk when its campaign is over, else null (nothing is added).
static func from_save(game: Node, defs: Dictionary) -> CampaignEnd:
	var saves := game.get_node_or_null(SAVE_SYSTEM_PATH) as SAVE_SYSTEM
	if saves == null or not saves.has_save():
		return null
	var model := saves.load_game(_json(WORLD_DATA), defs)
	if not model.ended or model.company == null:
		return null
	var chronicle := Chronicle.restore(_dict(model.wounds, "chronicle"))
	var memory := Memory.restore(_dict(model.wounds, "memories"))
	return open_for(game, model.company, chronicle, memory)


func is_open() -> bool:
	return _open


## The record in words: one block per fallen merc, in the order they died.
static func record_lines(company: Company, chronicle: Chronicle, memory: Memory) -> Array[String]:
	var shown := Merc.whole(_dict(_json(COMPANY_DATA), "campaign_end").get("memories_shown", 0))
	var lines: Array[String] = []
	for entry: Dictionary in chronicle.entries:
		var merc_id := str(entry.get("merc", ""))
		lines.append(
			Text.t(
				"chronicle.death",
				{
					"name": company.name_of(merc_id),
					"day": Injury.num(entry, "day"),
					"cause": TriageText.name_of(str(entry.get("cause", "")), company)
				}
			)
		)
		var said := MemoryWords.lines(memory.of(merc_id), company)
		for i: int in mini(shown, said.size()):
			lines.append(Text.t("end.memory", {"line": said[i]}))
	return lines


func show_record(company: Company, chronicle: Chronicle, memory: Memory) -> void:
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)
	panel = LoopPanel.new()
	_layer.add_child(panel)
	panel.chosen.connect(_on_choice)
	var body := Text.t("end.intro") + "\n\n" + "\n".join(record_lines(company, chronicle, memory))
	var choices: Array[Dictionary] = [{"id": BEGIN, "label": Text.t("end.begin")}]
	panel.present(Text.t("end.title"), body, choices)
	_open = true


## Begin again: the ended save is removed (the record has been read), the screen closes and,
## in the running game, the scene starts over on a new company.
func _on_choice(choice_id: String) -> void:
	if choice_id != BEGIN or not _open:
		return
	_open = false
	var saves := get_node_or_null(SAVE_SYSTEM_PATH) as SAVE_SYSTEM
	if saves != null:
		saves.close_ended(_json(WORLD_DATA), CompanyDirector.defs())
	_layer.visible = false
	finished.emit()
	var tree := get_tree()
	if tree.current_scene != null:
		tree.reload_current_scene.call_deferred()


static func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func _dict(block: Dictionary, key: String) -> Dictionary:
	var value: Variant = block.get(key, {})
	return value if value is Dictionary else {}
