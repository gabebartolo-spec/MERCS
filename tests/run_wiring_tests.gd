extends "res://tests/lib/runner.gd"
## Wiring suite (Phase 2: the company fights the road, hits wound, triage and the chronicle
## after). Sim: a fight fields the living roster with the captain leading and never a dead
## merc; the hit hook notes exactly the company mercs a blow puts down, rolls nothing on the
## battle stream and leaves the injury stream to the triage; Aftermath is applied to the
## Company (the dead leave it, the chronicle and the comrades' memories are written, the
## captain's office is handed on with one dissenting voice); a permanent injury takes its
## stat change into the next fight and a temporary one heals on its day; company and wounds
## survive a save through JSON with the dead still dead, and no older save brings one back.
## GUI: real clicks and letter keys at 1920x1080: Fight on the road, the triage panel with
## the chronicle line and the succession and no key help, Continue back to the map, the C
## screen marking the fallen as gone, Save, and a fresh session that never fields the dead.
## Seeded by design: sim fights use MercPlay on seeds 424246 and 424247 (a permanent injury
## and the captain's death); the GUI fight is the ambush on the road of the world seed 424260.
##   godot --headless --path . --script tests/run_wiring_tests.gd

const Kit := preload("res://tests/lib/wiring_kit.gd")
const Fixture := preload("res://tests/lib/company_fixture.gd")
const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")
const WINDOW_SIZE := Vector2i(1920, 1080)
const LAYOUT_FRAMES := 3
const FIGHT_FRAMES := 6000
const DEATH_SEED := 424247
const SCAR_SEED := 424246
const GUI_SEED := 424260
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
	_clear_save()
	await _check_gui_fight_and_triage()
	_clear_save()


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
			and after.size() == _cells().size()
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
	var bystander := {"type": "hit", "unit": "bandit_0", "target": "merc_6", "down": true}
	var quiet := (
		made.hit_hook(graze).is_empty()
		and made.hit_hook(foe).is_empty()
		and made.hit_hook(bystander).is_empty()
		and not made.is_noted("orc")
		and not made.is_noted("merc_6")
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
		var made := Kit.wounds(rng)
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
	var made := Kit.wounds(rng)
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
	check(
		(
			dead_id == "orc"
			and made.company.member("orc") == null
			and made.company.fallen == ["orc"]
			and entries.size() == 1
			and str(entries[0].get("cause", "")) != ""
			and mourned
			and heir != "orc"
			and heir == str(succession.get("captain", ""))
			and made.company.member(heir) != null
			and dissent != ""
			and dissent != heir
			and made.memories_of(dissent).any(
				func(m: Dictionary) -> bool: return m.get("key") == Memory.KEY_DISSENT
			)
		),
		"the captain's death leaves the roster, enters the chronicle, is mourned by every comrade and hands the office to %s over %s's dissent" % [heir, dissent]
	)
	var plain_rng := Rng.from_seed(DEATH_SEED)
	var plain := Kit.wounds(plain_rng)
	Kit.fight(plain, plain_rng, false)
	check(
		(
			plain.company.roster.size() == _cast()
			and plain.company.captain_id == "orc"
			and plain.chronicle().entries.is_empty()
		),
		"the same fight without the hook leaves the company as it was"
	)


func _check_permanent_injury_fielded() -> void:
	var rng := Rng.from_seed(SCAR_SEED)
	var made := Kit.wounds(rng)
	var base := made.company.member("vampyr").stat("attack")
	Kit.fight(made, rng, true)
	var scars := made.injuries_of("vampyr")
	var next := made.units(_cells(), BattleUnit.COMPANY)
	var attack := -1
	for unit: BattleUnit in next:
		if unit.id == "vampyr":
			attack = unit.attack
	check(
		(
			scars.size() == 1
			and str(scars[0].get("kind")) == "permanent"
			and made.layers_of("vampyr") == ["injury_lost_eye"]
			and attack == base + SCAR_ATTACK
			and made.company.member("vampyr").stat("attack") == base
		),
		"a permanent injury is in the next fight's numbers (attack %d from %d) and has its sprite layer" % [attack, base]
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
		"a temporary injury cuts the next fight's attack (%d from %d) and heals on its day" % [now, base]
	)


func _attack_of(made: CompanyWounds, merc_id: String) -> int:
	for unit: BattleUnit in made.units(_cells(), BattleUnit.COMPANY):
		if unit.id == merc_id:
			return unit.attack
	return -1


func _check_save_round_trip() -> void:
	var rng := Rng.from_seed(DEATH_SEED)
	var made := Kit.wounds(rng)
	Kit.fight(made, rng, true)
	var model := Kit.reloaded(made, rng)
	var back := Kit.wounds(model.rng, "", model.wounds, model.company)
	var units := back.units(_cells(), BattleUnit.COMPANY)
	check(
		(
			model.ok
			and model.company.member("orc") == null
			and model.company.roster.size() == made.company.roster.size()
			and model.company.captain_id == made.company.captain_id
			and back.chronicle().is_dead("orc")
			and back.chronicle().entries == made.chronicle().entries
			and back.memories_of(made.company.captain_id) == made.memories_of(made.company.captain_id)
			and not _ids(units).has("orc")
			and units[0].id == made.company.captain_id
		),
		"save, reload, continue: the dead stay dead, the new captain leads, the chronicle and memories are back"
	)


func _check_no_save_revives() -> void:
	var rng := Rng.from_seed(DEATH_SEED)
	var made := Kit.wounds(rng)
	Kit.fight(made, rng, true)
	var block := made.state()
	var old_company := Company.start(Fixture.defs())
	var old := Kit.wounds(Rng.from_seed(1), "", block, old_company)
	var everyone_gone := Company.restore({"roster": [], "fallen": ["orc", "vampyr"]}, Fixture.defs())
	check(
		(
			old.company.member("orc") == null
			and old.company.fallen.has("orc")
			and not old.company.add("orc")
			and everyone_gone.member("orc") == null
			and everyone_gone.member("vampyr") == null
		),
		"an older company block that still lists the dead is buried by the chronicle; an emptied company is not restarted"
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


# --- GUI: real clicks and letter keys -----------------------------------------------------


func _check_gui_fight_and_triage() -> void:
	var rng := Rng.from_seed(GUI_SEED)
	var world := WorldSim.new()
	world.start(Kit.json("res://data/balance/world.json"), rng)
	_saves().save_game(world, rng)
	var road := world.destinations()[0]
	var game := await _spawn()
	var screen := game.company_director()
	screen.wounds = Kit.wounds(Rng.from_seed(0), "dead", {}, screen.company)
	await _tap(KEY_M)
	var director := game.overworld_director()
	await _click_button(director.panel.button_for(road))
	await _click_button(director.panel.button_for(OverworldDirector.FIGHT))
	await _frames(LAYOUT_FRAMES)
	var fielded: Array[String] = director.wounds.fielded.duplicate()
	var fought := director.in_fight() and fielded.size() == _cells().size()
	check(
		fought and fielded[0] == "orc" and director.view.battle.unit("orc").is_leader,
		"Fight on the road fields the company, the orc captain first: %s" % [fielded]
	)
	await _finish_fight(director)
	await _frames(LAYOUT_FRAMES)
	await _check_triage_panel(game, director)
	await _click_button(director.panel.button_for(OverworldDirector.CONTINUE))
	await _frames(LAYOUT_FRAMES)
	check(
		(
			director.panel.button_for(OverworldDirector.CONTINUE) == null
			and director.panel.button_for(OverworldDirector.SAVE) != null
			and director.map.visible
		),
		"Continue returns to the map with its choices"
	)
	await _click_button(director.panel.button_for(OverworldDirector.SAVE))
	await _tap(KEY_M)
	await _check_company_screen(game)
	game.queue_free()
	await process_frame
	await _check_fresh_session()


func _check_triage_panel(game: SliceGame, director: OverworldDirector) -> void:
	var body := director.panel.shown_body()
	var entries := director.wounds.chronicle().entries
	var cause := ""
	var died_on := -1
	if not entries.is_empty():
		cause = TriageText.name_of(str(entries[0].get("cause", "")), director.company)
		died_on = Merc.whole(entries[0].get("day", -1))
	var line := Text.t(
		"chronicle.death", {"name": "The Orc", "day": died_on, "cause": cause}
	)
	var captain := director.company.name_of(director.company.captain_id)
	var heir := Text.t("succession.new_captain", {"name": captain})
	var dissent := ""
	for merc: Merc in director.company.roster:
		for memory: Dictionary in director.wounds.memories_of(merc.id):
			if memory.get("key") == Memory.KEY_DISSENT:
				dissent = merc.display_name
	var hud: CanvasLayer = game.get(&"_hud")
	check(
		(
			director.panel.button_for(OverworldDirector.CONTINUE) != null
			and director.panel.button_for(OverworldDirector.SAVE) == null
			and not entries.is_empty()
			and body.contains(line)
			and body.contains(heir)
			and dissent != ""
			and body.contains(Text.t("succession.dissent", {"name": dissent}))
			and hud != null
			and not hud.visible
		),
		"after the fight the triage panel words the death and the chronicle line, the succession, Continue only, and the key help is hidden: %s" % body.replace("\n", " | ")
	)


func _check_company_screen(game: SliceGame) -> void:
	await _tap(KEY_C)
	await _frames(LAYOUT_FRAMES)
	var screen := game.company_director()
	var panel := screen.panel
	var rows := panel.row_for("orc")
	var gone := rows != null and rows.text == Text.t("company.fallen.row", {"name": "The Orc"})
	await _click_button(rows)
	await _frames(LAYOUT_FRAMES)
	var shown := panel.header_text() == Text.t("company.fallen.title", {"name": "The Orc"})
	check(
		(
			gone
			and shown
			and screen.company.member("orc") == null
			and screen.company.roster.size() == _cast() - 1
			and panel.lines_text().contains(Text.t("company.fallen.gone"))
			and panel.row_for(screen.company.captain_id).text.contains(
				Text.t("company.mark.captain")
			)
		),
		"the C screen marks the orc as fallen and gone, shows his chronicle line, and marks the new captain"
	)
	await _tap(KEY_C)


func _check_fresh_session() -> void:
	var game := await _spawn()
	var screen := game.company_director()
	var units := screen.wounds.units(_cells(), BattleUnit.COMPANY)
	check(
		(
			screen.company.member("orc") == null
			and screen.company.fallen.has("orc")
			and screen.wounds.chronicle().is_dead("orc")
			and not _ids(units).has("orc")
			and units[0].id == screen.company.captain_id
			and not screen.wounds.memories_of(screen.company.captain_id).is_empty()
		),
		"a new session reads the save: the orc is dead and never fielded, his chronicle and memories are back"
	)
	game.queue_free()
	await process_frame


func _saves() -> SAVE_SYSTEM:
	return root.get_node(^"SaveSystem") as SAVE_SYSTEM


func _clear_save() -> void:
	if FileAccess.file_exists(SAVE_SYSTEM.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_SYSTEM.SAVE_PATH))


func _spawn() -> SliceGame:
	var packed: PackedScene = load(SLICE_SCENE) as PackedScene
	var game: SliceGame = packed.instantiate() as SliceGame
	root.add_child(game)
	await process_frame
	return game


## Plays the company's turns by clicks and waits out the enemy's, until the battle is over.
func _finish_fight(director: OverworldDirector) -> void:
	var battle := director.view.battle
	var rules: Dictionary = Kit.json(Fixture.BATTLE).get("rules", {})
	var sight: int = rules.get("sight_cells", 0)
	for _frame: int in FIGHT_FRAMES:
		if battle.is_over():
			break
		var actor := battle.current()
		if actor.side == BattleUnit.COMPANY:
			await _company_turn(director, BattleAi.choose(battle, actor, sight))
		else:
			await process_frame


func _company_turn(director: OverworldDirector, action: Dictionary) -> void:
	var kind := str(action.get("type", ""))
	if kind == Battle.ACTION_MOVE:
		var to: Vector2i = action.get("to", Vector2i.ZERO)
		director.view.click_cell(director.origin + to)
		await process_frame
		return
	var choice_id := Battle.ACTION_WAIT
	if kind == Battle.ACTION_ATTACK:
		choice_id = "%s:%s" % [Battle.ACTION_ATTACK, action.get("target")]
	await _click_button(director.panel.button_for(choice_id))


func _frames(count: int) -> void:
	for _frame: int in count:
		await process_frame


func _click_button(button: Button) -> void:
	# A freshly shown panel lays its buttons out over the next frames.
	await _frames(LAYOUT_FRAMES)
	if button == null or not is_instance_valid(button):
		return
	var at := button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = at
		click.global_position = at
		click.pressed = pressed
		Input.parse_input_event(click)
		Input.flush_buffered_events()
		await process_frame


func _tap(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
