class_name CampaignSaves
extends RefCounted
## How the overworld's campaign is written to the one save on disk (SaveSystem). Save by hand
## writes it in either mode. Ironman (D-087: quitting can't undo a death or a lost fight) also
## writes it by itself right after every decision the player commits: a fight's start and each
## action in it, the fight's end and Continue after its triage, the toll, a rest day and the
## hub's actions. During a fight the save is the fight's starting save with the actions taken
## since (FightRecord), so a reload rebuilds the same battle and replays it to the same turn.
## Writing only reads the run; nothing here draws from the Rng or decides anything.

const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")

## The campaign's mode (chosen at its start, kept in the save).
var ironman := false

var _saves: SAVE_SYSTEM = null
var _world: WorldSim = null
var _rng: Rng = null
var _wounds: CompanyWounds = null
## The fight being recorded under Ironman, else null.
var _fight: FightRecord = null


## The run this writes, set once the overworld holds it: the company is the wounds' own.
func bind(saves: SAVE_SYSTEM, world: WorldSim, rng: Rng, wounds: CompanyWounds) -> void:
	_saves = saves
	_world = world
	_rng = rng
	_wounds = wounds


## The run written as it stands, in the campaign's mode. True when written.
func write() -> bool:
	if _saves == null:
		return false
	_saves.ironman = ironman
	return _saves.save_game(_world, _rng, _wounds.company, _wounds.state())


## Ironman: the run written silently (during a fight, its record); Off: nothing.
func autosave() -> void:
	if not ironman or _saves == null:
		return
	if _fight != null:
		_saves.write(_fight.saved())
	else:
		write()


## Ironman, Fight chosen: the encounter marked fighting and the save as it stands kept as the
## fight's start. Called before the battle is built, so the start holds the Rng it is built from.
func begin_fight() -> void:
	_fight = null
	if not ironman or _saves == null:
		return
	_world.mark_fighting()
	_saves.ironman = true
	_fight = FightRecord.make(_saves.to_save(_world, _rng, _wounds.company, _wounds.state()))


## The actions already replayed into the rebuilt battle (none for a fresh fight), then the
## fight's save written.
func resume(taken: Array[Dictionary]) -> void:
	if _fight == null:
		return
	for action: Dictionary in taken:
		_fight.record(action)
	autosave()


## One more action the battle applied (BattleView.acted): recorded and written at once.
func record(action: Dictionary) -> void:
	if _fight == null:
		return
	_fight.record(action)
	autosave()


## The fight is over: what follows is saved as the run stands again.
func end_fight() -> void:
	_fight = null
