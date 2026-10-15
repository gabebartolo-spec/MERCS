extends RefCounted
## The campaign_end suite's GUI checks, run by tests/run_campaign_end_tests.gd: real clicks and
## letter keys at 1920x1080. A saved company of the orc alone (five already in the chronicle)
## walks into an ambush and loses the fight: the triage panel, Continue, the last screen with
## every fallen merc's name, day, cause and memories, the keys dead behind it, Begin again,
## and a new campaign of the starting six. Then a game started on an ended save opens on the
## same screen and plays nothing on from it. Seeded by design: the ambush is met by walking
## on world seed 424273 (re-picked when the orc's plate, Phase 4 P1b, let him win at 424270),
## played by BattleAi.

const End := preload("res://tests/lib/end_kit.gd")
const Kit := preload("res://tests/lib/wiring_kit.gd")
const Fixture := preload("res://tests/lib/company_fixture.gd")
const Real := preload("res://tests/lib/input_kit.gd")
const World := preload("res://tests/lib/world_fixture.gd")
const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")
const GUI_SEED := 424273
const NEAR := 3
const TAP_LIMIT := 8
const LAYOUT_FRAMES := 3

var _tree: SceneTree = null
var _check: Callable


func setup(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check


func run() -> void:
	_clear_save()
	_save_lone_orc_ambush(false)
	var game := await _spawn()
	await Real.tap(_tree, KEY_M)
	var director := game.overworld_director()
	# The data's triage may spare a downed merc; here a downed merc dies.
	director.wounds = Kit.wounds(director.rng, "dead", director.wounds.state(), director.company)
	director.wounds.adopt_memory(StoryDirector.memory_of(director))
	await _walk_into(director)
	await Real.click(_tree, director.panel.button_for(OverworldDirector.FIGHT))
	await Real.frames(_tree, LAYOUT_FRAMES)
	await Real.finish_fight(_tree, director)
	await Real.frames(_tree, LAYOUT_FRAMES)
	await _check_triage_then_end(game, director)
	await _check_begin_again(game)
	await _check_start_on_ended_save()
	_clear_save()


## A saved world with the band near a lone ambush, the company the orc alone with the other
## five in the chronicle; `ended` marks the campaign over (the orc dead too).
func _save_lone_orc_ambush(ended: bool) -> void:
	var rng := Rng.from_seed(GUI_SEED)
	var world := WorldSim.new()
	world.start(World.data(), rng)
	world.parties.clear()
	World.out_of_town(world, NEAR)
	World.lone_party(world, "ambush", NEAR)
	var made := End.lone_orc(rng, "")
	if ended:
		made.company.bury(End.LAST)
		made.chronicle().record_death(End.LAST, End.EARLIER_DAY, End.EARLIER_CAUSE)
	_saves().save_game(world, rng, made.company, made.state())


func _walk_into(director: OverworldDirector) -> void:
	var world := director.world
	var keys := {
		Vector2i(0, -1): KEY_W, Vector2i(0, 1): KEY_S, Vector2i(-1, 0): KEY_A, Vector2i(1, 0): KEY_D
	}
	for _tap_count: int in TAP_LIMIT:
		if not world.encounter.is_empty() or world.parties.is_empty():
			return
		var to := world.parties[0].tile - world.band
		var step := Vector2i(signi(to.x), 0) if to.x != 0 else Vector2i(0, signi(to.y))
		var code: Key = keys.get(step, KEY_NONE)
		await Real.tap(_tree, code)


func _cast() -> int:
	return Fixture.rows(Fixture.json(Fixture.MERCS), "mercs").size()


func _check_triage_then_end(game: SliceGame, director: OverworldDirector) -> void:
	var triage := director.panel.shown_body()
	_check.call(
		(
			director.wounds.ended()
			and director.panel.button_for(OverworldDirector.CONTINUE) != null
			and triage.contains(director.company.name_of(End.LAST))
			and _saved_text().contains('"ended": true')
			and not game.end_open()
		),
		(
			"the last merc dies: the triage panel first with Continue, the save already ended: %s"
			% triage.replace("\n", " | ")
		)
	)
	await Real.click(_tree, director.panel.button_for(OverworldDirector.CONTINUE))
	await Real.frames(_tree, LAYOUT_FRAMES)
	_check_last_screen(game, director)
	await _check_keys_dead(game, director)


func _check_keys_dead(game: SliceGame, director: OverworldDirector) -> void:
	var band := director.world.band
	await Real.tap(_tree, KEY_S)
	await Real.tap(_tree, KEY_C)
	await Real.tap(_tree, KEY_M)
	await Real.frames(_tree, LAYOUT_FRAMES)
	_check.call(
		director.world.band == band and not game.company_open() and game.end_open(),
		"behind the last screen the walking, company and map letters do nothing"
	)


func _check_last_screen(game: SliceGame, director: OverworldDirector) -> void:
	var screen := game.campaign_end()
	var body := screen.panel.shown_body() if screen != null else ""
	var lines_ok := screen != null
	var chronicle := director.wounds.chronicle()
	for entry: Dictionary in chronicle.entries:
		var merc_id := str(entry.get("merc", ""))
		var line := Text.t(
			"chronicle.death",
			{
				"name": director.company.name_of(merc_id),
				"day": Merc.whole(entry.get("day", -1)),
				"cause": TriageText.name_of(str(entry.get("cause", "")), director.company)
			}
		)
		lines_ok = lines_ok and body.contains(line)
	_check.call(
		(
			game.end_open()
			and lines_ok
			and chronicle.entries.size() == _cast()
			and body.contains(Text.t("end.intro"))
			and body.contains(Text.t("memory.fight_fell", {"day": End.EARLIER_DAY}))
			and screen.panel.button_for(CampaignEnd.BEGIN) != null
			and not director.panel.visible
		),
		(
			"Continue opens the last screen: every fallen merc with day, cause and memories: %s"
			% body.replace("\n", " | ")
		)
	)


func _check_begin_again(game: SliceGame) -> void:
	var screen := game.campaign_end()
	await Real.click(_tree, screen.panel.button_for(CampaignEnd.BEGIN))
	await Real.frames(_tree, LAYOUT_FRAMES)
	var closed := not game.end_open() and not _saves().has_save()
	game.queue_free()
	await _tree.process_frame
	var fresh := await _spawn()
	var held := fresh.company_director()
	_check.call(
		(
			closed
			and not fresh.end_open()
			and held.company.roster.size() == _cast()
			and held.company.fallen.is_empty()
			and held.wounds.chronicle().entries.is_empty()
		),
		"Begin again closes the record and the next campaign is the starting six, nobody fallen"
	)
	fresh.queue_free()
	await _tree.process_frame


func _check_start_on_ended_save() -> void:
	_clear_save()
	_save_lone_orc_ambush(true)
	var game := await _spawn()
	var opened := game.end_open()
	var body := game.campaign_end().panel.shown_body() if opened else ""
	var held := game.company_director()
	(
		_check
		. call(
			(
				opened
				and body.contains(held.company.name_of(End.LAST))
				and held.company.fallen.is_empty()
				and held.company.roster.size() == _cast()
				and _saved_text().contains('"ended": true')
			),
			"a game started on an ended save opens the last screen and holds a new company, never that one"
		)
	)
	await Real.click(_tree, game.campaign_end().panel.button_for(CampaignEnd.BEGIN))
	await Real.frames(_tree, LAYOUT_FRAMES)
	_check.call(
		not _saves().has_save() and not game.end_open(), "Begin again on an ended save removes it"
	)
	game.queue_free()
	await _tree.process_frame


func _saved_text() -> String:
	if not FileAccess.file_exists(SAVE_SYSTEM.SAVE_PATH):
		return ""
	return FileAccess.get_file_as_string(SAVE_SYSTEM.SAVE_PATH)


func _saves() -> SAVE_SYSTEM:
	return _tree.root.get_node(^"SaveSystem") as SAVE_SYSTEM


func _clear_save() -> void:
	if FileAccess.file_exists(SAVE_SYSTEM.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_SYSTEM.SAVE_PATH))


func _spawn() -> SliceGame:
	var packed: PackedScene = load(SLICE_SCENE) as PackedScene
	var game: SliceGame = packed.instantiate() as SliceGame
	_tree.root.add_child(game)
	await _tree.process_frame
	return game
