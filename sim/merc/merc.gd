class_name Merc
extends RefCounted
## One mercenary of the company (Phase 2 milestone 3): who they are, from data/mercs.json
## (stats, role words, moves by level, stage-1 gear, the three generic-gear slots), and what
## has happened to them, the little that changes and so enters the save: experience and the
## gear in the slots. Level is read from experience against the one bar in
## data/balance/company.json, never stored. Generic gear is for stats only and never shows on
## the sprite (D-066). Nothing here rolls and nothing reads the clock.

const SLOTS: Array[String] = ["weapon", "armour", "trinket"]
## The slots whose gear has a battle class, and the BattleUnit data key each feeds.
const CLASS_KEYS := {"weapon": BattleGear.WEAPON_KEY, "armour": BattleGear.ARMOUR_KEY}

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
## The battle classes of the merc's own gear (data/mercs.json "gear_line": "weapon", "armour",
## "shield"); empty when the data names none.
var gear_line := {}
## Slot -> generic gear id, "" for empty.
var gear := {}
var xp := 0
## Generic-gear definitions by id (data/equipment.json), set by the Company that holds this
## merc; with none, gear in the slots adds nothing.
var items := {}

var _moves_by_level := {}
## Stat -> whole points gained per level above the first (data/mercs.json "growth").
var _growth := {}
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
	var grows: Variant = def.get("growth", {})
	merc._growth = grows if grows is Dictionary else {}
	var gear_line: Variant = def.get("stage_1_gear", [])
	if gear_line is Array:
		for item: Variant in gear_line:
			merc.stage_1_gear.append(str(item))
	var line: Variant = def.get("gear_line", {})
	if line is Dictionary:
		var classes: Dictionary = line
		merc.gear_line = classes.duplicate()
	var slots: Variant = def.get("gear_slots", {})
	var named: Dictionary = slots if slots is Dictionary else {}
	for slot: String in SLOTS:
		var worn: Variant = named.get(slot)
		merc.gear[slot] = "" if worn == null else str(worn)
	merc._level_xp = level_xp
	return merc


## A stat by key (hp, attack, defense, damage, initiative, presence, resolve); 0 if absent.
## Each level above the first adds the merc's growth for it (D-094); the generic gear in the
## slots adds its bonus (D-066: stats only).
func stat(key: String) -> int:
	return whole(stats.get(key, 0)) + grown(key) + bonus(key)


## What the levels reached add to one stat: growth per level times the levels above the first.
func grown(key: String) -> int:
	return whole(_growth.get(key, 0)) * (level() - 1)


## What the next level brings, from data: {"level": n, "growth": {stat: points}, "moves":
## [ids new at that level]}; {} at the highest level.
func next_level() -> Dictionary:
	var at := level() + 1
	if at > max_level():
		return {}
	var gains := {}
	for key: Variant in _growth:
		if whole(_growth[key]) != 0:
			gains[str(key)] = whole(_growth[key])
	var fresh: Array[String] = []
	var learnt: Variant = _moves_by_level.get(str(at), [])
	if learnt is Array:
		for move: Variant in learnt:
			if str(move) not in moves():
				fresh.append(str(move))
	return {"level": at, "growth": gains, "moves": fresh}


## What the gear in the slots adds to one stat.
func bonus(key: String) -> int:
	var total := 0
	for slot: String in SLOTS:
		var worn: Variant = items.get(str(gear.get(slot, "")), {})
		if not worn is Dictionary:
			continue
		var piece: Dictionary = worn
		var numbers: Variant = piece.get("bonus", {})
		if numbers is Dictionary:
			var added: Dictionary = numbers
			total += whole(added.get(key, 0))
	return total


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
## says. Generic gear in the slots adds its bonus to the numbers. `fit` are the merc's
## numbers as injuries leave them (CompanyWounds); each change from `stats` is laid over.
func to_battle_unit(side: int, at: Vector2i, leads: bool, fit: Dictionary = {}) -> BattleUnit:
	var numbers := stats.duplicate()
	for key: Variant in numbers:
		if numbers[key] is int or numbers[key] is float:
			var hurt := whole(fit.get(key, 0)) - whole(stats.get(key, 0)) if fit.has(key) else 0
			numbers[key] = stat(str(key)) + hurt
	var learnt := moves()
	numbers["ability_charge"] = Battle.ACTION_CHARGE in learnt
	numbers["ability_blood_price"] = Battle.ACTION_BLOOD_PRICE in learnt
	numbers["leader"] = leads
	numbers.merge(gear_classes(), true)
	return BattleUnit.make(id, side, at, numbers)


## The initiative the merc acts at in a fight: his stat with his armour's slowness (BattleGear
## rule 4). rules: data/balance/battle.json "rules" (its "gear" block).
func fighting_initiative(rules: Dictionary) -> int:
	var unit := to_battle_unit(BattleUnit.COMPANY, Vector2i.ZERO, false)
	var gear: Variant = rules.get(BattleGear.GEAR_KEY, {})
	var block: Dictionary = gear if gear is Dictionary else {}
	return unit.initiative + BattleGear.armour_initiative(block, unit.armour_class)


## The battle classes the merc fights with (BattleGear.dress keys): the gear line's, and for a
## slot it leaves open, the class of the generic gear worn there (D-066: the look still shows
## the gear line). Slots with neither are left out, so a stats_from fighter's "gear" applies.
func gear_classes() -> Dictionary:
	var out := {}
	for slot: String in CLASS_KEYS:
		var key := str(CLASS_KEYS[slot])
		var named := str(gear_line.get(slot, ""))
		if named == "":
			var worn: Variant = items.get(str(gear.get(slot, "")), {})
			var piece: Dictionary = worn if worn is Dictionary else {}
			named = str(piece.get("class", ""))
		if named != "":
			out[key] = named
	if gear_line.get(BattleGear.SHIELD) == true:
		out[BattleGear.SHIELD] = true
	return out


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
