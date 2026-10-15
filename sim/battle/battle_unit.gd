class_name BattleUnit
extends RefCounted
## One fighter on the battle grid: who they are (id, side, leader), where they stand and which
## way they face (one of eight), the few numbers the battle reads, and their loadout: up to
## four learnt moves by id (D-066), each defined with its numbers in data/balance/battle.json
## "rules" "moves". Counters come from combat roles and each merc's own moves, never a type
## chart (vision, 2026-10-09). The director's reference pair: the orc charges in on pure
## aggression; the Vampyr spends his own health to power an attack.

## Sides (ints, so they travel in event logs and saves as plain numbers).
const COMPANY := 0
const ENEMY := 1
const SIDES: Array[int] = [COMPANY, ENEMY]
## Each side's key in data (battle.json "rules" "morale_sides"), by side.
const SIDE_KEYS: Array[String] = ["company", "enemy"]
## The eight facings, as grid steps, in the order the grid tries them.
const FACINGS: Array[Vector2i] = [
	Vector2i(-1, -1),
	Vector2i.LEFT,
	Vector2i(-1, 1),
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i(1, -1),
	Vector2i.RIGHT,
	Vector2i(1, 1),
]
## The reference pair's move ids (battle.json "rules" "moves").
const MOVE_CHARGE := "charge"
const MOVE_BLOOD_PRICE := "blood_price"
## The sketch's ability flags in fighter data, and the move each one stands for.
const FLAGS := {"ability_charge": MOVE_CHARGE, "ability_blood_price": MOVE_BLOOD_PRICE}

var id := ""
var side := COMPANY
var cell := Vector2i.ZERO
## One of FACINGS: where the fighter looks (towards the nearest foe at the start, then along
## each walk and at each target).
var facing := Vector2i.RIGHT
var hp := 1
var max_hp := 1
var attack := 0
var defense := 0
var damage := 1
var initiative := 0
var is_leader := false
var down := false
var wounded := false
## The merc's resolve-flavoured social weight, read by visible checks (sim/story/checks.gd).
var presence := 0
## The merc's own resolve: at the captain's fall he holds at or above the rules' bar (BattleMorale).
var resolve := 0
## The class of the weapon in hand (stats "weapon_class": sword, axe, spear, mace, bow; director
## Q-B, 2026-10-15), "" for none; the action kit gives its weapon action (BattleKit).
var weapon_class := ""
## Learnt moves taken into this fight, by id, in loadout order (at most "loadout_max").
var moves: Array[String] = []
## Added to this fighter's next attack only, then cleared (the Vampyr's blood price).
var next_attack_bonus := 0
var next_damage_bonus := 0

## The sketch's flags, kept as views of the loadout.
var can_charge: bool:
	get:
		return knows(MOVE_CHARGE)
	set(value):
		teach(MOVE_CHARGE, value)
var can_blood_price: bool:
	get:
		return knows(MOVE_BLOOD_PRICE)
	set(value):
		teach(MOVE_BLOOD_PRICE, value)


## stats: one fighter of battle.json "fighters": numbers, "leader", and "moves" as
## {move_id: true} (an Array of ids also reads); the sketch's "ability_charge" and
## "ability_blood_price" flags, when present, decide those two moves either way (a merc's
## learnt moves outrank the fighter data, Merc.to_battle_unit).
static func make(unit_id: String, unit_side: int, at: Vector2i, stats: Dictionary) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.id = unit_id
	unit.side = unit_side
	unit.cell = at
	unit.max_hp = _int(stats, "hp", 1)
	unit.hp = unit.max_hp
	unit.attack = _int(stats, "attack", 0)
	unit.defense = _int(stats, "defense", 0)
	unit.damage = _int(stats, "damage", 1)
	unit.initiative = _int(stats, "initiative", 0)
	unit.is_leader = stats.get("leader", false) == true
	unit.presence = _int(stats, "presence", 0)
	unit.resolve = _int(stats, "resolve", 0)
	unit.weapon_class = str(stats.get("weapon_class", ""))
	for move: String in _listed_moves(stats.get("moves", [])):
		unit.teach(move, true)
	for flag: Variant in FLAGS:
		if stats.has(flag):
			var learnt: bool = stats.get(flag) == true
			unit.teach(str(FLAGS[flag]), learnt)
	return unit


func can_act() -> bool:
	return not down


func knows(move: String) -> bool:
	return moves.has(move)


## Adds a move to the end of the loadout, or takes it out.
func teach(move: String, learnt: bool) -> void:
	if learnt and not moves.has(move):
		moves.append(move)
	elif not learnt:
		moves.erase(move)


## Move ids from {id: true} or [id, ...], in the order given.
static func _listed_moves(listed: Variant) -> Array[String]:
	var out: Array[String] = []
	if listed is Dictionary:
		var flags: Dictionary = listed
		for key: Variant in flags:
			if flags[key] == true:
				out.append(str(key))
	elif listed is Array:
		var ids: Array = listed
		for key: Variant in ids:
			out.append(str(key))
	return out


static func _int(stats: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = stats.get(key, fallback)
	if value is int:
		return value
	if value is float:
		var number: float = value
		return roundi(number)
	return fallback
