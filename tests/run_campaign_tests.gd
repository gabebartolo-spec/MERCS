extends "res://tests/lib/runner.gd"
## Campaign suite (the Phase 2 gate's gaps 1 to 4): one scripted
## campaign (tests/lib/campaign_kit.gd:
## a walk, a party fight with its triage and a death, wages, a contract, a hire, the prisoner,
## a rest at the hub and the storylet) played twice from one seed ends in the same save, byte
## for byte, and from another seed does not; every stage of it really happened; the final save
## reads back and writes the same; the version 2 fixture (fixtures/save/v2.json) loads with its
## company, wounds and story; a memory sentence names a comrade who died by name, never by id.
## Seeded by design: campaign seeds 424308 and 424316 (each has a death in its fight).
##   godot --headless --path . --script tests/run_campaign_tests.gd

const Campaign := preload("res://tests/lib/campaign_kit.gd")
const Fixture := preload("res://tests/lib/company_fixture.gd")
const World := preload("res://tests/lib/world_fixture.gd")
const SEED := 424308
const OTHER_SEED := 424316
const V2_FIXTURE := "res://tests/fixtures/save/v2.json"
const MERC_ID_PREFIX := "merc_"
## Any internal id (a lower-case word with an underscore) in a sentence a player reads.
const ID_PATTERN := "\b[a-z]+_[a-z0-9_]+\b"
const STAGES: Array[String] = [
	"met", "fought", "triage", "won", "contract", "hired", "prisoner", "paid", "storylet"
]


func suite_name() -> String:
	return "Campaign"


func run_checks() -> void:
	var first := Campaign.run(SEED)
	_check_replay(first)
	_check_other_seed(first)
	_check_stages(first)
	_check_reload(first)
	_check_v2_fixture()
	_check_memory_names(first)
	await process_frame


func _check_replay(first: Dictionary) -> void:
	var again := Campaign.run(SEED)
	var text: String = first["save"]
	check(
		text == str(again["save"]) and text.length() > 0,
		(
			"the same campaign on seed %d twice ends in the same save, byte for byte (%d bytes)"
			% [SEED, text.length()]
		)
	)


func _check_other_seed(first: Dictionary) -> void:
	var other := Campaign.run(OTHER_SEED)
	check(
		str(first["save"]) != str(other["save"]),
		"the same campaign on seed %d ends in a different save" % OTHER_SEED
	)


func _check_stages(first: Dictionary) -> void:
	var stages: Dictionary = first["stages"]
	var missing: Array[String] = []
	for stage: String in STAGES:
		if stages.get(stage, false) != true:
			missing.append(stage)
	check(missing.is_empty(), "the campaign really walked every stage; missing: %s" % [missing])


## A save's text read and written again, so ints and floats of one number compare equal.
func _canon(text: String) -> String:
	return JSON.stringify(JSON.parse_string(text))


## The final save, through JSON text, reads back as a model that writes the same save.
func _check_reload(first: Dictionary) -> void:
	var parsed: Variant = JSON.parse_string(str(first["save"]))
	var saved: Dictionary = parsed if parsed is Dictionary else {}
	var model := SaveModel.from_dict(saved, World.data(), Fixture.defs())
	var again := SaveModel.to_dict(model.world, model.rng, model.company, model.wounds)
	again = SaveModel.with_story(again, model.story)
	check(
		model.ok and _canon(JSON.stringify(again)) == _canon(str(first["save"])),
		"the campaign's final save reads back through JSON and writes the same save"
	)


## A real version 2 file (written by this build before the next format) loads whole.
func _check_v2_fixture() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(V2_FIXTURE))
	var saved: Dictionary = parsed if parsed is Dictionary else {}
	var model := SaveModel.from_dict(saved, World.data(), Fixture.defs())
	var after := SaveModel.to_dict(model.world, model.rng, model.company, model.wounds)
	after = SaveModel.with_story(after, model.story)
	var version: int = saved.get("version", -1)
	check(
		(
			version == 2
			and model.ok
			and model.company != null
			and not model.company.fallen.is_empty()
			and not model.wounds.is_empty()
			and not model.story.is_empty()
			and _canon(JSON.stringify(after)) == _canon(JSON.stringify(saved))
		),
		"the version 2 fixture loads with its company, wounds and story and writes the same file"
	)


## No memory sentence of a living merc shows a merc id: the dead are named from the data.
func _check_memory_names(first: Dictionary) -> void:
	var company: Company = first["company"]
	var memory: Memory = first["memory"]
	var shown: Array[String] = []
	var named := 0
	for merc: Merc in company.roster:
		for entry: Dictionary in memory.of(merc.id):
			var line := MemoryWords.line(entry, company)
			shown.append(line)
			var about := str(entry.get("about", ""))
			if about != "" and company.member(about) == null:
				named += 1 if line.contains(company.name_of(about)) else 0
	var id_regex := RegEx.create_from_string(ID_PATTERN)
	var ids := shown.filter(
		func(line: String) -> bool:
			return line.contains(MERC_ID_PREFIX) or id_regex.search(line) != null
	)
	var recruit := company.name_of("recruit_1")
	check(
		named > 0 and ids.is_empty() and recruit != "recruit_1" and recruit != "",
		(
			"a fallen comrade is named in %d memory lines, no id shows (%s), a lost recruit has a name"
			% [named, ids]
		)
	)
