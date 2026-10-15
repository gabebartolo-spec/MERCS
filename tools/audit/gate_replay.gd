extends SceneTree
## Evidence for the Phase 2 gate's structural audit (docs/audits/phase2_gate/
## structural_evidence.md): one scripted campaign, the campaign suite's
## (tests/lib/campaign_kit.gd) grown by a short epilogue, played in steps with a save after
## each milestone's step. Three modes, each its own Godot process:
##   full <seed> <ironman 0|1> <out_dir>
##       the campaign uninterrupted; writes <out_dir>/final.json.
##   split <seed> <ironman 0|1> <checkpoint> <out_dir> [fight_action]
##       plays up to the checkpoint and writes <out_dir>/cp_<checkpoint>.json, then quits.
##       Checkpoint m4_fight (Ironman only) stops inside the fight after fight_action actions
##       and writes the Ironman fight save (the fight's start plus its actions, FightRecord).
##   resume <checkpoint> <in_file> <out_dir>
##       a fresh process reads the save (SaveModel.from_dict, as the game does), carries on
##       from the step after the checkpoint and writes <out_dir>/resumed_<checkpoint>.json.
## Every line it prints starts "AUDIT ". Compare the files' md5: a resumed run must end in the
## uninterrupted run's save. Tooling only: nothing in the game loads this script.
##   godot --headless --path . --script tools/audit/gate_replay.gd -- full 424310 0 <dir>

const World := preload("res://tests/lib/world_fixture.gd")
const Fixture := preload("res://tests/lib/company_fixture.gd")
const Kit := preload("res://tests/lib/wiring_kit.gd")
const STORYLETS := "res://data/storylets.json"
const OUT := 3
const NEAR := 3
const WALK_LIMIT := 40
const HOME_LIMIT := 60
const REST_DAYS := 2
const EPILOGUE_DAYS := 3
const SPARE := "release"
const FATE := "dead"
## M3, the captain's office: the office handed to the Vampyr after the hub (as the C screen does).
const NEW_CAPTAIN := "vampyr"
## The checkpoints, in campaign order: the save written after each step.
const STEPS: Array[String] = [
	"m1_world",
	"m2_encounter",
	"m5_triage",
	"m6_hub",
	"m3_office",
	"m7_memory",
	"m7_storylet",
	"final",
]
const FIGHT_STEP := 2
const MID_FIGHT := "m4_fight"

var _played: Played = null
var _stop_at := ""
var _fight_stop := -1
var _taken: Array[Dictionary] = []


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else ""
	var code := 1
	if mode == "full" and args.size() >= 4:
		code = _full(args[1].to_int(), args[2] == "1", args[3])
	elif mode == "split" and args.size() >= 5:
		_fight_stop = args[5].to_int() if args.size() > 5 else -1
		code = _split(args[1].to_int(), args[2] == "1", args[3], args[4])
	elif mode == "resume" and args.size() >= 4:
		code = _resume(args[1], args[2], args[3])
	else:
		print("AUDIT usage: full|split|resume, see the header")
	quit(code)


func _full(seed_value: int, ironman: bool, out_dir: String) -> int:
	_played = Played.new(seed_value, ironman)
	_run_from(0)
	print("AUDIT stages %s" % [JSON.stringify(_played.stages)])
	print("AUDIT fight_actions %d first_company_down %d" % [_played.actions, _played.first_down])
	return _write(out_dir.path_join("final.json"), _played.save())


func _split(seed_value: int, ironman: bool, checkpoint: String, out_dir: String) -> int:
	_played = Played.new(seed_value, ironman)
	_stop_at = checkpoint
	var reached: Variant = _run_from(0)
	if not reached is Dictionary:
		print("AUDIT checkpoint %s never reached" % checkpoint)
		return 1
	var stopped: Dictionary = reached
	return _write(out_dir.path_join("cp_%s.json" % checkpoint), stopped)


func _resume(checkpoint: String, in_file: String, out_dir: String) -> int:
	var text := FileAccess.get_file_as_string(in_file)
	var parsed: Variant = JSON.parse_string(text)
	var saved: Dictionary = parsed if parsed is Dictionary else {}
	var model := SaveModel.from_dict(saved, World.data(), Fixture.defs())
	if not model.ok:
		print("AUDIT reload refused: %s" % model.error)
		return 1
	_played = Played.from_model(model)
	_taken = model.fight_actions
	var written := saved.duplicate(true)
	written.erase(FightRecord.KEY)
	var same := _canon(JSON.stringify(_played.save())) == _canon(JSON.stringify(written))
	print("AUDIT reload_writes_same_save %s" % same)
	var next := FIGHT_STEP if checkpoint == MID_FIGHT else STEPS.find(checkpoint) + 1
	_run_from(next)
	return _write(out_dir.path_join("resumed_%s.json" % checkpoint), _played.save())


## Runs the steps from `first` to the end. Returns the save to write when the split's
## checkpoint is reached (the run stops there), else null.
func _run_from(first: int) -> Variant:
	for index: int in range(first, STEPS.size()):
		var mid: Variant = _step(index)
		if mid != null:
			return mid
		if STEPS[index] == _stop_at:
			return _played.save()
	return null


func _step(index: int) -> Variant:
	match index:
		0:
			_played.leave_town()
		1:
			_played.meet()
		2:
			return _played.fight(_taken, _fight_stop if _stop_at == MID_FIGHT else -1)
		3:
			_played.hub()
		4:
			_played.stages["appointed"] = _played.company.appoint(NEW_CAPTAIN)
		5:
			_played.home()
		6:
			_played.stages["storylet"] = _played.storylet()
		7:
			_played.epilogue()
	return null


func _write(path: String, saved: Dictionary) -> int:
	var text := JSON.stringify(saved)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("AUDIT cannot write %s" % path)
		return 1
	file.store_string(text)
	file.close()
	print("AUDIT wrote %s md5 %s canon_md5 %s" % [path, text.md5_text(), _canon(text).md5_text()])
	return 0


## A save's text read and written again, so ints and floats of one number compare equal.
static func _canon(text: String) -> String:
	return JSON.stringify(JSON.parse_string(text))


## One campaign's pieces on one Rng, with the hub's hooks set (campaign_kit.gd's Played).
class Played:
	extends RefCounted
	var rng: Rng
	var world: WorldSim
	var company: Company
	var memory: Memory
	var wounds: CompanyWounds
	var story := StoryletState.new()
	var ironman := false
	var stages := {}
	var actions := 0
	var first_down := -1

	func _init(seed_value: int = 0, on: bool = false) -> void:
		if seed_value == 0:
			return
		ironman = on
		rng = Rng.from_seed(seed_value)
		world = WorldSim.new()
		world.start(World.data(), rng)
		company = Company.start(Fixture.defs())
		memory = Memory.new()
		wounds = CompanyWounds.make(company, {}, rng, Kit.rules(FATE), Kit.injury_defs())
		wounds.adopt_memory(memory)
		_wire()
		company.economy.refresh_board(world.day, _site_ids(), rng)

	## A campaign read back from a save, wired the way a new one is (no new board).
	static func from_model(model: SaveModel) -> Played:
		var played := Played.new()
		played.ironman = model.ironman
		played.rng = model.rng
		played.world = model.world
		played.company = model.company
		played.wounds = CompanyWounds.make(
			model.company, model.wounds, model.rng, Kit.rules(FATE), Kit.injury_defs()
		)
		played.memory = played.wounds.memory()
		played.wounds.adopt_memory(played.memory)
		played.story = StoryletState.restore(model.story)
		played._wire()
		return played

	func _wire() -> void:
		var lineups: Array = World.json(World.ENCOUNTERS).get("encounters", [])
		world.set_lineups(lineups)
		var site_ids := _site_ids()
		world.day_hook = func(day: int) -> void:
			company.economy.on_day(company.roster.size(), day, site_ids, rng)
		world.result_hook = func(kind: String, result: Dictionary) -> void:
			if result.get("won", false) == true:
				company.economy.take_loot(kind, rng)
				company.economy.captives.take(world.day)

	func _site_ids() -> Array[String]:
		var ids: Array[String] = []
		for i: int in range(1, world.sites.size()):
			ids.append(world.sites[i].id)
		return ids

	func save() -> Dictionary:
		var saved := SaveModel.to_dict(world, rng, company, wounds.state(), false, ironman)
		return SaveModel.with_story(saved, story.state())

	## M1: out of the gate, one lone ambush placed near (the world, the band's tile, a party).
	func leave_town() -> void:
		world.parties.clear()
		World.out_of_town(world, OUT)
		stages["placed"] = World.lone_party(world, "ambush", NEAR) != null

	## M2: walked into the party; the encounter stands.
	func meet() -> void:
		if not world.parties.is_empty():
			World.walk_toward(world, world.parties[0].tile, WALK_LIMIT)
		stages["met"] = not world.encounter.is_empty()

	## M4 and M5: the fight played action by action (Ironman: recorded, as CampaignSaves does),
	## then the triage. With stop_after >= 0 and Ironman, returns the fight's save after that
	## many actions and stops; else null.
	func fight(taken: Array[Dictionary], stop_after: int) -> Variant:
		if world.encounter.is_empty():
			return null
		wounds.day = world.day
		var record: FightRecord = null
		if ironman:
			world.mark_fighting()
			record = FightRecord.make(save())
		var battle := RoadFight.build(
			wounds, world.pending_encounter(), Kit.scenario(), Fixture.json(Fixture.BATTLE), rng
		)
		var replayed := FightRecord.replay(battle, taken)
		print("AUDIT replayed %d of %d recorded actions" % [replayed, taken.size()])
		for action: Dictionary in taken.slice(0, replayed):
			record.record(action)
		actions = replayed
		while actions < Kit.MAX_ACTIONS and not battle.is_over():
			if record != null and actions == stop_after:
				return record.saved()
			_act(battle, record)
		_settle(battle)
		return null

	func _act(battle: Battle, record: FightRecord) -> void:
		var action := MercPlay.choose(battle, battle.current(), Fixture.rules())
		var events := battle.apply(action)
		if events.is_empty():
			action = {"type": Battle.ACTION_WAIT}
			events = battle.apply(action)
		if record != null:
			record.record(action)
		for event: Dictionary in events:
			var hit := str(event.get("unit", ""))
			if event.get("type") == "down" and company.member(hit) != null and first_down < 0:
				first_down = actions
		actions += 1

	func _settle(battle: Battle) -> void:
		var kind := str(world.encounter.get("type", ""))
		var result := EncounterBattle.result(battle)
		stages["triage"] = not wounds.resolve().is_empty()
		var hook := world.result_hook
		world.result_hook = Callable()
		world.resolve_encounter(result)
		world.result_hook = hook
		hook.call(kind, result)
		stages["fought"] = true
		stages["won"] = result.get("won", false)

	## M6: a contract, a hire and the prisoner's fate at the hub.
	func hub() -> void:
		var economy := company.economy
		if not economy.board.is_empty():
			var first: Dictionary = economy.board[0]
			stages["contract"] = economy.accept(str(first.get("id", "")))
		var offers := economy.offers()
		if not offers.is_empty():
			var recruit: Dictionary = offers[0]
			stages["hired"] = economy.hire(company, str(recruit.get("id", "")))
		if not economy.prisoner.is_empty():
			stages["prisoner"] = economy.decide_prisoner(company, SPARE, world.day)
			memory.record(company.captain_id, Memory.KEY_FATE_PREFIX + SPARE, {}, world.day)

	## M7 (memory): home, two days' rest at the hub, wages paid.
	func home() -> void:
		World.walk_toward(world, world.region.entrance(RegionGen.HUB_ID), HOME_LIMIT)
		for _day: int in REST_DAYS:
			if world.at == RegionGen.HUB_ID:
				world.rest()
		stages["paid"] = company.economy.pay_wages()
		stages["rested_at_hub"] = world.at == RegionGen.HUB_ID

	## M7 (storylet): the storylet on offer at the hub, attempted by its first role.
	func storylet() -> bool:
		if world.at != RegionGen.HUB_ID:
			return false
		var book := StoryBook.new()
		book.company = company
		book.memory = memory
		book.state = story
		book.rng = rng
		book.load_defs(World.json(STORYLETS))
		var context := {"hook": "rest", "day": world.day, "site": world.at, "site_kind": "hub"}
		var offer := book.offer(context)
		if offer.is_empty():
			return false
		var attempts: Array = offer.get("attempts", [])
		var pick: Dictionary = attempts[0]
		book.choose(offer, str(pick.get("role", "")))
		return true

	## After the last milestone: three more days' rest (wages, board, parties move), the
	## storylet asked again (it must not fire twice) and the wages paid.
	func epilogue() -> void:
		for _day: int in EPILOGUE_DAYS:
			world.rest()
		stages["storylet_again"] = storylet()
		stages["paid_again"] = company.economy.pay_wages()
