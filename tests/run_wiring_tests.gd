extends "res://tests/lib/runner.gd"
## Wiring suite (Phase 2: the company fights the road, hits wound, triage and the chronicle
## after). Sim: a fight fields the living roster with the captain leading and never a dead
## merc; the hit hook notes exactly the company mercs a blow puts down, rolls nothing on the
## battle stream and leaves the injury stream to the triage; Aftermath is applied to the
## Company (the dead leave it, the chronicle and the comrades' memories are written, the
## captain's office is handed on with one dissenting voice); a permanent injury takes its
## stat change into the next fight and a temporary one heals on its day; company and wounds
## survive a save through JSON with the dead still dead, and no older save brings one back.
## GUI (tests/wiring/gui_checks.gd): real clicks and letter keys at 1920x1080: Fight on the
## road, the triage panel, Continue, the C screen marking the fallen as gone, Save, a fresh
## session that never fields the dead.
## Seeded by design: sim fights use MercPlay on seeds 424251 (a permanent injury) and 424333
## (the captain's death; was 424264 until Phase 4 P2: the captain's fall now breaks the shaky
## recruits and that fight ended in the company's surrender); the GUI fight is an ambush met
## by walking, world seed 424270.
##   godot --headless --path . --script tests/run_wiring_tests.gd

const Kit := preload("res://tests/lib/wiring_kit.gd")
const Fixture := preload("res://tests/lib/company_fixture.gd")
const GuiChecks := preload("res://tests/wiring/gui_checks.gd")
const WINDOW_SIZE := Vector2i(1920, 1080)
const DEATH_SEED := 424333
const SCAR_SEED := 424251
const SCAR_ATTACK := -3
const TEMPORARY_DAYS := 5


func suite_name() -> String:
	return "Wiring"


func run_checks() -> void:
	root.size = WINDOW_SIZE
	_check_fielding()
	_check_hook()
	_check_hook_leaves_battle_stream()
	_check_aftermath_applied()
	_check_permanent_injury_fielded()
	_check_temporary_injury_heals()
	_check_save_round_trip()
	_check_no_save_revives()
	var gui := GuiChecks.new()
	gui.setup(self, check)
	await gui.run()


func _cells() -> Array[Vector2i]:
	return EncounterBattle.company_cells(Kit.scenario())


func _ids(units: Array[BattleUnit]) -> Array[String]:
	var ids: Array[String] = []
	for unit: BattleUnit in units:
		ids.append(unit.id)
	return ids


func _check_fielding() -> void:
	var made := Kit.wounds(Rng.from_seed(1))
	var units := made.units(_cells(), BattleUnit.COMPANY)
	var captain_leads := not units.is_empty() and units[0].id == "orc" and units[0].is_leader
	var one_leader := units.filter(func(u: BattleUnit) -> bool: return u.is_leader).size() == 1
	check(
		(
			units.size() == _cells().size()
			and captain_leads
			and one_leader
			and made.fielded == _ids(units)
			and units.all(func(u: BattleUnit) -> bool: return made.company.member(u.id) != null)
		),
		"a road fight fields the roster, one merc per cell, the captain leading: %s" % [_ids(units)]
	)
	made.company.bury("orc")
	var after := made.units(_cells(), BattleUnit.COMPANY)
	check(
		(
			not _ids(after).has("orc")
			and after.size() == made.company.roster.size()
			and not made.company.add("orc")
			and made.company.member("orc") == null
		),
		"a buried merc is never fielded again and cannot be hired back: %s" % [_ids(after)]
	)


func _check_hook() -> void:
	var made := Kit.wounds(Rng.from_seed(1))
	made.units(_cells(), BattleUnit.COMPANY)
	var graze := {"type": "hit", "unit": "bandit_0", "target": "orc", "down": false}
	var foe := {"type": "hit", "unit": "orc", "target": "bandit_0", "down": true}
	var bystander := {"type": "hit", "unit": "bandit_0", "target": "stranger", "down": true}
	var quiet := (
		made.hit_hook(graze).is_empty()
		and made.hit_hook(foe).is_empty()
		and made.hit_hook(bystander).is_empty()
		and not made.is_noted("orc")
		and not made.is_noted("stranger")
	)
	var fall := {"type": "hit", "unit": "bandit_0", "target": "orc", "down": true}
	var events := made.hit_hook(fall)
	var noted := (
		events.size() == 1
		and str(events[0].get("type")) == "injury"
		and str(events[0].get("unit")) == "orc"
		and made.is_noted("orc")
		and made.hit_hook(fall).is_empty()
	)
	check(
		quiet and noted,
		"the hit hook notes a blow that puts a fielded merc down, once, and nothing else"
	)


func _check_hook_leaves_battle_stream() -> void:
	var streams: Array[Dictionary] = []
	for hooked: bool in [true, false]:
		var rng := Rng.from_seed(DEATH_SEED)
		var made := Kit.wounds(rng, "", {}, Kit.led_by("vampyr"))
		Kit.fight(made, rng, hooked)
		var held: Dictionary = rng.state()["streams"]
		streams.append(held)
	check(
		(
			_same(streams[0].get("battle"), streams[1].get("battle"))
			and streams[0].has("injury")
			and not streams[1].has("injury")
		),
		"the hook leaves the battle stream where it was; only the triage draws the injury stream"
	)


func _check_aftermath_applied() -> void:
	var rng := Rng.from_seed(DEATH_SEED)
	var made := Kit.wounds(rng, "", {}, Kit.led_by("vampyr"))
	var result := Kit.fight(made, rng, true)
	var events: Array[Dictionary] = result["events"]
	var succession := _first(events, "succession")
	var death := _first(events, "death")
	var heir := made.company.captain_id
	var dissent := str(succession.get("dissent", ""))
	var dead_id := str(death.get("merc", ""))
	var entries := made.chronicle().entries
	var mourned := made.company.roster.all(
		func(merc: Merc) -> bool: return not made.memories_of(merc.id).is_empty()
	)
	var dissent_kept := made.memories_of(dissent).any(
		func(m: Dictionary) -> bool: return m.get("key") == Memory.KEY_DISSENT
	)
	check(
		(
			dead_id == "vampyr"
			and made.company.member("vampyr") == null
			and made.company.fallen == ["vampyr"]
			and entries.size() == 1
			and str(entries[0].get("cause", "")) != ""
			and mourned
			and heir != "vampyr"
			and heir == str(succession.get("captain", ""))
			and made.company.member(heir) != null
			and dissent != ""
			and dissent != heir
			and dissent_kept
		),
		(
			"the captain's death: off the roster, in the chronicle, mourned, office to %s over %s"
			% [heir, dissent]
		)
	)
	_check_hook_off_changes_nothing()


func _check_hook_off_changes_nothing() -> void:
	var plain_rng := Rng.from_seed(DEATH_SEED)
	var plain := Kit.wounds(plain_rng, "", {}, Kit.led_by("vampyr"))
	Kit.fight(plain, plain_rng, false)
	check(
		(
			plain.company.roster.size() == _cast()
			and plain.company.captain_id == "vampyr"
			and plain.chronicle().entries.is_empty()
		),
		"the same fight without the hook leaves the company as it was"
	)


func _check_permanent_injury_fielded() -> void:
	var rng := Rng.from_seed(SCAR_SEED)
	var made := Kit.wounds(rng)
	var base := made.company.member("merc_3").stat("attack")
	Kit.fight(made, rng, true)
	var scars := made.injuries_of("merc_3")
	var next := made.units(_cells(), BattleUnit.COMPANY)
	var attack := -1
	for unit: BattleUnit in next:
		if unit.id == "merc_3":
			attack = unit.attack
	check(
		(
			scars.size() == 1
			and str(scars[0].get("kind")) == "permanent"
			and made.layers_of("merc_3") == ["injury_lost_eye"]
			and attack == base + SCAR_ATTACK
			and made.company.member("merc_3").stat("attack") == base
		),
		(
			"a permanent injury is in the next fight's numbers (attack %d from %d) and has its sprite layer"
			% [attack, base]
		)
	)


func _check_temporary_injury_heals() -> void:
	var rng := Rng.from_seed(SCAR_SEED)
	var made := Kit.wounds(rng, "temporary")
	var base := made.company.member("vampyr").stat("attack")
	Kit.fight(made, rng, true)
	var hurt := made.injuries_of("vampyr").size()
	var now := _attack_of(made, "vampyr")
	made.day += TEMPORARY_DAYS
	var healed := _attack_of(made, "vampyr")
	check(
		hurt == 1 and now < base and healed == base and made.injuries_of("vampyr").is_empty(),
		(
			"a temporary injury cuts the next fight's attack (%d from %d) and heals on its day"
			% [now, base]
		)
	)


func _attack_of(made: CompanyWounds, merc_id: String) -> int:
	for unit: BattleUnit in made.units(_cells(), BattleUnit.COMPANY):
		if unit.id == merc_id:
			return unit.attack
	return -1


func _check_save_round_trip() -> void:
	var rng := Rng.from_seed(DEATH_SEED)
	var made := Kit.wounds(rng, "", {}, Kit.led_by("vampyr"))
	Kit.fight(made, rng, true)
	var model := Kit.reloaded(made, rng)
	var back := Kit.wounds(model.rng, "", model.wounds, model.company)
	var units := back.units(_cells(), BattleUnit.COMPANY)
	check(
		(
			model.ok
			and model.company.member("vampyr") == null
			and model.company.roster.size() == made.company.roster.size()
			and model.company.captain_id == made.company.captain_id
			and back.chronicle().is_dead("vampyr")
			and back.chronicle().entries == made.chronicle().entries
			and (
				back.memories_of(made.company.captain_id)
				== made.memories_of(made.company.captain_id)
			)
			and not _ids(units).has("vampyr")
			and units[0].id == made.company.captain_id
		),
		"save, reload, continue: the dead stay dead, the heir leads, chronicle and memories back"
	)


func _check_no_save_revives() -> void:
	var rng := Rng.from_seed(DEATH_SEED)
	var made := Kit.wounds(rng, "", {}, Kit.led_by("vampyr"))
	Kit.fight(made, rng, true)
	var block := made.state()
	var old_company := Company.start(Fixture.defs())
	var old := Kit.wounds(Rng.from_seed(1), "", block, old_company)
	var everyone_gone := Company.restore(
		{"roster": [], "fallen": ["orc", "vampyr"]}, Fixture.defs()
	)
	check(
		(
			old.company.member("vampyr") == null
			and old.company.fallen.has("vampyr")
			and not old.company.add("vampyr")
			and everyone_gone.member("vampyr") == null
			and everyone_gone.member("vampyr") == null
		),
		"an older company block listing the dead is buried by the chronicle; none restarts empty"
	)


func _same(a: Variant, b: Variant) -> bool:
	return a == b


func _cast() -> int:
	return Fixture.rows(Fixture.json(Fixture.MERCS), "mercs").size()


func _first(events: Array[Dictionary], type: String) -> Dictionary:
	for event: Dictionary in events:
		if event.get("type") == type:
			return event
	return {}
