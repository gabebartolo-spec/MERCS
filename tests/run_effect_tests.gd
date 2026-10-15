extends "res://tests/lib/runner.gd"
## Effect suite (04_GUARDRAILS.md A1, the player-effect fixture): every case in tests/effect/
## runs the same seed with its system on and off and the two outcomes must differ. Each case
## prints "EFFECT <id>: <on> vs <off>". One check per case (a case is a fixture, so adding
## one raises the floor), one that every script there is a case, and one that the systems
## this phase expects are covered.
## Seeded by design: each case pins its own seeds (424242 and 424243).
##   godot --headless --path . --script tests/run_effect_tests.gd

const EffectCase := preload("res://tests/lib/effect_case.gd")
const CASE_DIR := "res://tests/effect"
const EXPECTED_IDS: Array[String] = [
	"world_tick",
	"world_map",
	"encounter_road",
	"encounter_toll",
	"company_merc",
	"party_sight",
	"walk_drain",
	"permanent_injury",
	"death_memory",
	"battle_blocking",
	"battle_rout",
	"battle_delegate",
	"battle_captain",
	"battle_surrender",
	"battle_ai_knowledge",
	"wiring_hook",
	"wiring_death_reload",
	"hub_wages",
	"hub_prisoner",
	"storylet_memory",
	"campaign_end",
	"captain_office",
	"turn_order",
	"battle_sight",
	"intent_marker",
	"temporary_injury",
	"contracts_pressure",
	"loot_gear",
	"hiring",
	"battle_kit",
	"levels",
	"xp_from_fights",
	"contract_grudge",
	"contract_jobs",
]


func suite_name() -> String:
	return "Effect"


func run_checks() -> void:
	var not_cases: Array[String] = []
	var seen: Dictionary = {}
	for file: String in DirAccess.get_files_at(CASE_DIR):
		if not file.ends_with(".gd"):
			continue
		var path := CASE_DIR.path_join(file)
		var case := _load_case(path)
		if case == null or case.id() == "" or seen.has(case.id()):
			not_cases.append(path)
			continue
		seen[case.id()] = path
		_run_case(case)
	check(
		not_cases.is_empty(),
		"every script in %s is a case with its own id: %s" % [CASE_DIR, not_cases]
	)
	var missing := EXPECTED_IDS.filter(func(id: String) -> bool: return not seen.has(id))
	check(missing.is_empty(), "the expected systems have a case: missing %s" % [missing])
	await process_frame


func _load_case(path: String) -> EffectCase:
	var script: Variant = load(path)
	if not script is GDScript:
		return null
	var loaded: GDScript = script
	var instance: Variant = loaded.new()
	return instance if instance is EffectCase else null


func _run_case(case: EffectCase) -> void:
	var result := case.run()
	var on := str(result.get("on", ""))
	var off := str(result.get("off", ""))
	print("EFFECT %s: %s vs %s" % [case.id(), on, off])
	check(
		on != "" and on != off,
		"%s: the system on shows a different outcome from off (%s vs %s)" % [case.id(), on, off]
	)
