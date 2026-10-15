extends "res://tests/lib/runner.gd"
## Campaign end suite (director, 2026-10-15: when every merc in the company dies the campaign
## ends). Sim: the same seed and fight with a triage that kills the last merc against one that
## spares him gives an ended campaign against a continuing one; the wipe is reported after the
## triage and only when nobody is left; the save marks it ended (optional key, default not
## ended), an ended save reads as not ok with the chronicle intact and never fields anyone, a
## company with every merc dead reads as ended even without the key; closing an ended save
## removes it and never touches one that can be played. GUI (tests/campaign_end/gui_checks.gd):
## real clicks and letter keys at 1920x1080 through a lost fight, the final screen and a new
## campaign.
## Seeded by design: the fights use MercPlay on seed 424271; the GUI fight is an ambush met by
## walking on world seed 424273.
##   godot --headless --path . --script tests/run_campaign_end_tests.gd

const End := preload("res://tests/lib/end_kit.gd")
const Kit := preload("res://tests/lib/wiring_kit.gd")
const Fixture := preload("res://tests/lib/company_fixture.gd")
const GuiChecks := preload("res://tests/campaign_end/gui_checks.gd")
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")
const WINDOW_SIZE := Vector2i(1920, 1080)
const SEED := 424271


func suite_name() -> String:
	return "CampaignEnd"


func run_checks() -> void:
	root.size = WINDOW_SIZE
	_check_wipe_against_survivor()
	_check_wipe_needs_everyone()
	_check_save_marks_ended()
	_check_ended_never_plays()
	_check_close_ended()
	var gui := GuiChecks.new()
	gui.setup(self, check)
	await gui.run()


func _check_wipe_against_survivor() -> void:
	var dead := End.fight(SEED, "dead")
	var spared := End.fight(SEED, "wound")
	var dead_events: Array[Dictionary] = dead["events"]
	var spared_events: Array[Dictionary] = spared["events"]
	var last: Dictionary = dead_events[dead_events.size() - 1]
	var gone: CompanyWounds = dead["wounds"]
	var kept: CompanyWounds = spared["wounds"]
	check(
		(
			End.has_event(dead_events, "campaign_end")
			and str(last.get("type")) == "campaign_end"
			and gone.ended()
			and gone.company.roster.is_empty()
			and gone.company.fallen.has(End.LAST)
			and gone.chronicle().is_dead(End.LAST)
			and not End.has_event(spared_events, "campaign_end")
			and not kept.ended()
			and kept.company.member(End.LAST) != null
		),
		"same seed, same fight: the triage that kills the last merc ends the campaign, the other does not"
	)


func _check_wipe_needs_everyone() -> void:
	var fresh := Company.start(Fixture.defs())
	var one_down := Company.start(Fixture.defs())
	one_down.bury("vampyr")
	var all_down := Company.start(Fixture.defs())
	for id: String in all_down.fighting_order():
		all_down.bury(id)
	var never_had := Company.restore({"roster": [], "fallen": []}, Fixture.defs())
	check(
		(
			not fresh.is_wiped()
			and not one_down.is_wiped()
			and all_down.is_wiped()
			and not never_had.is_wiped()
		),
		"a company is wiped only when it had mercs and every one is buried"
	)


func _ended_model(with_key: bool) -> SaveModel:
	var fought := End.fight(SEED, "dead")
	var rng: Rng = fought["rng"]
	var made: CompanyWounds = fought["wounds"]
	var balance := Kit.json("res://data/balance/world.json")
	var world := WorldSim.new()
	world.start(balance, rng)
	var saved := SaveModel.to_dict(world, rng, made.company, made.state(), with_key)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(saved))
	return SaveModel.from_dict(parsed, balance, Fixture.defs())


func _check_save_marks_ended() -> void:
	var rng := Rng.from_seed(SEED)
	var world := WorldSim.new()
	world.start(Kit.json("res://data/balance/world.json"), rng)
	var plain := SaveModel.to_dict(world, rng, Company.start(Fixture.defs()))
	var back := SaveModel.from_dict(
		plain, Kit.json("res://data/balance/world.json"), Fixture.defs()
	)
	var keyed := _ended_model(true)
	var unkeyed := _ended_model(false)
	var block: Variant = keyed.wounds.get("chronicle", {})
	var held: Dictionary = block if block is Dictionary else {}
	var chronicle := Chronicle.restore(held)
	check(
		(
			not plain.has("ended")
			and back.ok
			and not back.ended
			and keyed.ended
			and not keyed.ok
			and keyed.error == SaveModel.ERROR_ENDED
			and chronicle.is_dead(End.LAST)
			and (
				chronicle.entries.size()
				== Fixture.rows(Fixture.json(Fixture.MERCS), "mercs").size()
			)
			and unkeyed.ended
			and not unkeyed.ok
		),
		"the save marks the end (optional key, default not ended); all dead reads as ended without it"
	)


func _check_ended_never_plays() -> void:
	var model := _ended_model(true)
	var again := Kit.wounds(Rng.from_seed(1), "", model.wounds, model.company)
	var cells := EncounterBattle.company_cells(Kit.scenario())
	var tried := model.company.add(End.LAST) or model.company.add("vampyr")
	check(
		(
			model.company.roster.is_empty()
			and not tried
			and again.units(cells, BattleUnit.COMPANY).is_empty()
			and again.ended()
		),
		"an ended save never puts anyone back: no hire, nobody fielded"
	)


func _check_close_ended() -> void:
	var saves := root.get_node(^"SaveSystem") as SAVE_SYSTEM
	var balance := Kit.json("res://data/balance/world.json")
	var rng := Rng.from_seed(SEED)
	var world := WorldSim.new()
	world.start(balance, rng)
	saves.save_game(world, rng, Company.start(Fixture.defs()))
	var kept_playable := not saves.close_ended(balance, Fixture.defs()) and saves.has_save()
	var fought := End.fight(SEED, "dead")
	var made: CompanyWounds = fought["wounds"]
	saves.save_game(world, rng, made.company, made.state())
	var shown := saves.load_game(balance, Fixture.defs())
	var removed := saves.close_ended(balance, Fixture.defs()) and not saves.has_save()
	check(
		kept_playable and shown.ended and not shown.ok and removed,
		"closing the record removes an ended save and never one that can be played"
	)
