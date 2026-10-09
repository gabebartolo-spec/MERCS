class_name BattleUnit
extends RefCounted
## One fighter on the battle grid: who they are (id, side, leader), where they stand, and
## the few numbers the slice's sketch battle reads (docs/specs/art_direction_slice.md §2a).
## Counters come from combat roles and each merc's own abilities, never a type chart (vision,
## 2026-10-09). The abilities here are the director's reference pair: the orc charges in on
## pure aggression; the Vampyr spends his own health to power an attack.

## Sides (ints, so they travel in event logs and saves as plain numbers).
const COMPANY := 0
const ENEMY := 1
const SIDES: Array[int] = [COMPANY, ENEMY]

var id := ""
var side := COMPANY
var cell := Vector2i.ZERO
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
var can_charge := false
var can_blood_price := false
## Added to this fighter's next attack only, then cleared (the Vampyr's blood price).
var next_attack_bonus := 0
var next_damage_bonus := 0


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
	unit.can_charge = stats.get("ability_charge", false) == true
	unit.can_blood_price = stats.get("ability_blood_price", false) == true
	return unit


func can_act() -> bool:
	return not down


static func _int(stats: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = stats.get(key, fallback)
	if value is int:
		return value
	if value is float:
		var number: float = value
		return roundi(number)
	return fallback
