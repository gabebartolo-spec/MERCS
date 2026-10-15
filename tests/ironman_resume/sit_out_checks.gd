extends RefCounted
## The ironman_resume suite's sit-out check (Phase 4 P4, run by tests/run_ironman_resume_tests.gd):
## the captain sits out a fight under Ironman On and the choice survives a quit. It borrows the
## suite's own fight helpers (the saved world, the real clicks, the battle as text).

const InputKit := preload("res://tests/lib/input_kit.gd")
const World := preload("res://tests/lib/world_fixture.gd")
## The round the sat-out fight is left at (the quit), well before it can end.
const SIT_OUT_ROUND := 2

var _suite: Object = null
var _check: Callable


func setup(suite: Object, check: Callable) -> void:
	_suite = suite
	_check = check


## Ironman On, the captain sits out (P4): the fight starts with the sergeant leading and the
## company's morale dipped; a quit and reload stands at the same turn with the same choice;
## finished, the captain earned nothing, the fielded earned the fight's experience, and the
## choice is spent.
func run() -> void:
	var game: SliceGame = await _suite.call(
		"_fight_start", "ambush", OverworldDirector.FIGHT_SIT_OUT
	)
	var director := game.overworld_director()
	var captain := director.company.captain_id
	var sergeant := FieldCommand.sergeant(director.company)
	var dip := Merc.whole(director.company.deploy.get("captain_out_morale_dip", 0))
	var started := _started_as_promised(director, captain, sergeant, dip)
	var played: bool = await _suite.call("_play_to_round", director, SIT_OUT_ROUND)
	var at_turn: String = _suite.call("_battle_of", director)
	await _suite.call("_quit", game)
	var again: SliceGame = await _suite.call("_reopen")
	var back := again.overworld_director()
	var same := back.in_fight() and back.company.captain_out
	same = same and str(_suite.call("_battle_of", back)) == at_turn
	_check.call(
		started and same and played,
		(
			"Ironman On, captain sits out: sergeant leads, morale dipped %d, a reload stands there"
			% dip
		)
	)
	await _finished(back, captain, sergeant)
	await _suite.call("_quit", again)


func _started_as_promised(
	director: OverworldDirector, captain: String, sergeant: String, dip: int
) -> bool:
	var rules: Dictionary = World.json(InputKit.BATTLE_DATA).get("rules", {})
	var battle := director.view.battle
	return (
		battle.unit(captain) == null
		and battle.unit(sergeant).is_leader
		and battle.morale(BattleUnit.COMPANY) == Merc.whole(rules.get("morale_start", 0)) - dip
		and director.company.captain_out
	)


## The reloaded fight played out: the captain who sat out earned nothing, the sergeant earned the
## fight's experience (if still on the roster), and the choice is spent.
func _finished(back: OverworldDirector, captain: String, sergeant: String) -> void:
	var captain_xp := back.company.member(captain).xp
	var sergeant_xp := back.company.member(sergeant).xp
	await _suite.call("_finish", back)
	var fought := back.company.member(sergeant)
	var earned := Merc.whole(back.company.deploy.get("fight_xp", 0))
	var rested := back.company.member(captain)
	var spent := rested != null and rested.xp == captain_xp and not back.company.captain_out
	spent = spent and (fought == null or fought.xp == sergeant_xp + earned)
	_check.call(
		spent, "the captain who sat out earned no experience, the fielded earned %d" % earned
	)
