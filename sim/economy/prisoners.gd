class_name Prisoners
extends RefCounted
## The prisoners a won fight leaves (Economy's module; Phase 5 C0, prisoners from the fight
## C5): the enemies the battle reports as surrendered (EncounterBattle.taken), each waiting
## for the captain's call, one at a time in the order they were taken. Three fates: release,
## ransom or execute (director Q-12, "Not until you design it": no recruit fate in this pass).
## Deciding moves the economy it is handed (morale, a ransom's coin by the man's fighter type)
## and leaves two chronicle lines, one on the merc who reacts most strongly to that fate and
## then one on the captain, which the story director turns into memories. This module keeps
## no reference to the economy. Rules: data/balance/economy.json "prisoner".

const RELEASE := "release"
const RANSOM := "ransom"
const EXECUTE := "execute"
## The Phase 2 fate, dropped by Q-12: never offered or decided, but an old save's chronicle
## line ("prisoner.recruit") and memory ("memory.fate_recruit") still load and read.
const RECRUIT := "recruit"
const CHOICES: Array[String] = [RELEASE, RANSOM, EXECUTE]

## The prisoner waiting for a decision (the first held), or {}: {"day": d} and, for a man the
## battle reported, "id" (his unit id) and "kind" (his fighter type).
var waiting: Dictionary:
	get:
		return held[0] if not held.is_empty() else {}
	set(value):
		held.clear()
		if not value.is_empty():
			held.append(value)
## Every prisoner held, the waiting one first.
var held: Array[Dictionary] = []

var _rules := {}
var _max_morale := 0


## rules: data/balance/economy.json "prisoner"; max_morale: the ceiling a choice's morale
## stops at ("morale" "max").
func setup(rules: Dictionary, max_morale: int) -> void:
	_rules = rules
	_max_morale = max_morale


## A won fight leaves its prisoners on `day`. taken: the enemy unit ids the battle reports as
## surrendered (EncounterBattle.taken); each joins the line behind any still waiting. With
## none given, the Phase 2 rule: one nameless prisoner, unless one already waits.
func take(day: int, taken: Array = []) -> void:
	if taken.is_empty():
		if held.is_empty():
			held.append({"day": day})
		return
	for raw: Variant in taken:
		held.append({"day": day, "id": str(raw), "kind": kind_of(str(raw))})


## The prisoners behind the waiting one, as a save holds them.
func behind() -> Array[Dictionary]:
	return held.slice(1)


## A save's prisoners: the waiting one ("prisoner") and those behind ("prisoners_behind").
func load_state(first: Dictionary, rest: Array[Dictionary]) -> void:
	held.clear()
	if not first.is_empty():
		held.append(first)
		held.append_array(rest)


## What ransoming the waiting man brings: his fighter type's price ("ransom_by_fighter"), else
## "ransom_coin".
func ransom_coin() -> int:
	var by_kind := _block("ransom_by_fighter")
	var kind := str(waiting.get("kind", ""))
	var value: Variant = by_kind.get(kind)
	return Merc.whole(value) if value is int or value is float else _rule("ransom_coin")


## Decides the waiting prisoner for `economy`. The company reacts: its morale moves by the
## choice's number and a ransom brings coin. The merc who reacts most strongly to this fate
## (reacting()) and then the captain each get a chronicle line, so the captain's is the last.
## False (and the prisoner still waits) when none waits or the choice is not one of CHOICES.
func decide(economy: Economy, company: Company, choice: String, day: int) -> bool:
	if waiting.is_empty() or choice not in CHOICES:
		return false
	if choice == RANSOM:
		economy.purse += ransom_coin()
	var change := _rule(choice + "_morale")
	economy.morale = clampi(economy.morale + change, 0, _max_morale)
	var key := "prisoner." + choice
	var moved := reacting(company, choice)
	if moved != "":
		economy.chronicle.append({"day": day, "merc": moved, "key": key})
	economy.chronicle.append({"day": day, "merc": company.captain_id, "key": key})
	held.remove_at(0)
	return true


## The living merc, not the captain, who reacts most strongly to `choice`: the largest
## strength (either sign) in "reactions" for that fate; a tie goes to the lower id. "" when
## no one on the roster is listed.
func reacting(company: Company, choice: String) -> String:
	var listed: Variant = _block("reactions").get(choice, {})
	var strengths: Dictionary = listed if listed is Dictionary else {}
	var best := ""
	var best_strength := 0
	for merc: Merc in company.roster:
		var value: Variant = strengths.get(merc.id)
		if merc.id == company.captain_id or not (value is int or value is float):
			continue
		var strength := absi(Merc.whole(value))
		if strength > best_strength or (strength == best_strength and merc.id < best):
			best = merc.id
			best_strength = strength
	return best if best_strength > 0 else ""


## A battle unit's fighter type: its id without the "_<n>" EncounterBattle.build adds.
static func kind_of(unit_id: String) -> String:
	var cut := unit_id.rfind("_")
	if cut > 0 and unit_id.substr(cut + 1).is_valid_int():
		return unit_id.substr(0, cut)
	return unit_id


func _block(key: String) -> Dictionary:
	var value: Variant = _rules.get(key, {})
	return value if value is Dictionary else {}


func _rule(key: String) -> int:
	var value: Variant = _rules.get(key)
	return Merc.whole(value) if value is int or value is float else 0
