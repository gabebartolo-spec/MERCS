class_name BattleUnit
extends RefCounted
## One fighter on the battle grid: who they are (id, side, leader), where they stand, and
## the few numbers the slice's sketch battle reads (docs/specs/art_direction_slice.md §2a).
## Phase 3 replaces the numbers with the equipment "type chart"; the shape stays.

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
