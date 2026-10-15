class_name Merc
extends RefCounted
## One mercenary of the company (Phase 2 milestone 3): who they are, from data/mercs.json
## (stats, role words, moves by level, stage-1 gear, the three generic-gear slots), and what
## has happened to them, the little that changes and so enters the save: experience and the
## gear in the slots. Level is read from experience against the one bar in
## data/balance/company.json, never stored. Generic gear is for stats only and never shows on
## the sprite (D-066). Nothing here rolls and nothing reads the clock.

const SLOTS: Array[String] = ["weapon", "armour", "trinket"]

var id := ""
var display_name := ""
var species := ""
var role := ""
var look := ""
var placeholder := false
## The merc's numbers, whole: the battle fighter named by stats_from with the merc's own
## stats laid over it.
var stats := {}
var stage_1_gear: Array[String] = []
## Slot -> generic gear id, "" for empty.
var gear := {}
var xp := 0

var _moves_by_level := {}
var _level_xp: Array[int] = []


## def: one entry of data/mercs.json; fighters: data/balance/battle.json "fighters";
## level_xp: data/balance/company.json xp.level_xp.
static func make(def: Dictionary, fighters: Dictionary, level_xp: Array[int]) -> Merc:
	var merc := Merc.new()
	merc.id = str(def.get("id", ""))
	merc.display_name = str(def.get("name", ""))
	merc.species = str(def.get("species", ""))
	merc.role = str(def.get("role", ""))
	merc.look = str(def.get("look", ""))
	merc.placeholder = def.get("placeholder", false) == true
	var base: Variant = fighters.get(str(def.get("stats_from", "")), {})
	if base is Dictionary:
		var from_fighter: Dictionary = base
		merc.stats = from_fighter.duplicate()
	var own: Variant = def.get("stats", {})
	if own is Dictionary:
		var laid_over: Dictionary = own
		merc.stats.merge(laid_over, true)
	var learnt: Variant = def.get("moves_by_level", {})
	merc._moves_by_level = learnt if learnt is Dictionary else {}
	var gear_line: Variant = def.get("stage_1_gear", [])
	if gear_line is Array:
		for item: Variant in gear_line:
			merc.stage_1_gear.append(str(item))
	var slots: Variant = def.get("gear_slots", {})
	var named: Dictionary = slots if slots is Dictionary else {}
	for slot: String in SLOTS:
		var worn: Variant = named.get(slot)
		merc.gear[slot] = "" if worn == null else str(worn)
	merc._level_xp = level_xp
	return merc


## A stat by key (hp, attack, defense, damage, initiative, presence, resolve); 0 if absent.
func stat(key: String) -> int:
	return whole(stats.get(key, 0))


## The level the experience has reached: 1 at the first threshold, and so on, up to the last.
func level() -> int:
	var reached := 1
	for i: int in _level_xp.size():
		if xp >= _level_xp[i]:
			reached = i + 1
	return reached


func max_level() -> int:
	return maxi(1, _level_xp.size())


## Where the bar stands: {"xp": earned into this level, "span": this level's width}; span is
## 0 at the highest level.
func bar() -> Dictionary:
	var at := level()
	if at >= _level_xp.size():
		return {"xp": xp - _level_xp[at - 1], "span": 0}
	return {"xp": xp - _level_xp[at - 1], "span": _level_xp[at] - _level_xp[at - 1]}


## Adds experience (never negative); true when it raised the level.
func gain(amount: int) -> bool:
	var before := level()
	xp += maxi(0, amount)
	return level() > before


## Every move learnt up to the current level, in the order of learning, once each.
func moves() -> Array[String]:
	var out: Array[String] = []
	for at: int in range(1, level() + 1):
		var learnt: Variant = _moves_by_level.get(str(at), [])
		if not learnt is Array:
			continue
		for move: Variant in learnt:
			if str(move) not in out:
				out.append(str(move))
	return out


## The fighter this merc is in a battle, from their data. The abilities come from the moves
## learnt (charge, blood_price); a leader is whoever the company's captain is, so the caller
## says. Gear in the slots is for stats and adds nothing here yet.
func to_battle_unit(side: int, at: Vector2i, leads: bool) -> BattleUnit:
	var numbers := stats.duplicate()
	var learnt := moves()
	numbers["ability_charge"] = Battle.ACTION_CHARGE in learnt
	numbers["ability_blood_price"] = Battle.ACTION_BLOOD_PRICE in learnt
	numbers["leader"] = leads
	return BattleUnit.make(id, side, at, numbers)


## What the save keeps of this merc: experience and the gear in the slots.
func state() -> Dictionary:
	return {"id": id, "xp": xp, "gear": gear.duplicate()}


## Reads back what state() wrote; a missing or odd value keeps the default.
func apply_state(saved: Dictionary) -> void:
	xp = maxi(0, whole(saved.get("xp", 0)))
	var worn: Variant = saved.get("gear", {})
	if worn is Dictionary:
		var named: Dictionary = worn
		for slot: String in SLOTS:
			gear[slot] = str(named.get(slot, ""))


## A whole number from a JSON value: an int, or a float rounded; 0 for anything else.
static func whole(value: Variant) -> int:
	if value is int:
		return value
	if value is float:
		var number: float = value
		return roundi(number)
	return 0
