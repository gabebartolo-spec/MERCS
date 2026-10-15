class_name Prisoners
extends RefCounted
## The prisoner a won fight leaves (Economy's module, Phase 5 C0): the one waiting for a
## decision and the four choices, release, ransom, execute or recruit. Deciding moves the
## economy it is handed (morale, a ransom's coin, a recruit hired, the captain's chronicle
## line); this module keeps no reference to it. Rules: data/balance/economy.json "prisoner".

const RELEASE := "release"
const RANSOM := "ransom"
const EXECUTE := "execute"
const RECRUIT := "recruit"
const CHOICES: Array[String] = [RELEASE, RANSOM, EXECUTE, RECRUIT]

## The prisoner waiting for a decision, or {} ({"day": d}).
var waiting: Dictionary = {}

var _rules := {}
var _recruits: Array[Dictionary] = []
var _max_morale := 0


## rules: data/balance/economy.json "prisoner"; recruits: data/recruits.json "recruits";
## max_morale: the ceiling a choice's morale stops at ("morale" "max").
func setup(rules: Dictionary, recruits: Array[Dictionary], max_morale: int) -> void:
	_rules = rules
	_recruits = recruits
	_max_morale = max_morale


## A won fight leaves one prisoner to decide on (none while one waits).
func take(day: int) -> void:
	if waiting.is_empty():
		waiting = {"day": day}


func ransom_coin() -> int:
	return _rule("ransom_coin")


## Decides the waiting prisoner for `economy`. The company reacts: its morale moves by the
## choice's number, a ransom brings coin, a recruit joins as the next placeholder, and the
## captain remembers it (a chronicle line). False (and the prisoner still waits) when none
## waits, the choice is unknown, or a recruit cannot join.
func decide(economy: Economy, company: Company, choice: String, day: int) -> bool:
	if waiting.is_empty() or choice not in CHOICES:
		return false
	if choice == RECRUIT:
		var next := _unhired(economy.hired)
		if next == "" or not company.add(next):
			return false
		economy.hired.append(next)
	if choice == RANSOM:
		economy.purse += ransom_coin()
	var change := _rule(choice + "_morale")
	economy.morale = clampi(economy.morale + change, 0, _max_morale)
	economy.chronicle.append({"day": day, "merc": company.captain_id, "key": "prisoner." + choice})
	waiting = {}
	return true


## Whether a recruit could join through the prisoner choice now, given who was ever hired.
func can_recruit(company: Company, hired: Array[String]) -> bool:
	return _unhired(hired) != "" and company.roster.size() < company.cap()


func _unhired(hired: Array[String]) -> String:
	for def: Dictionary in _recruits:
		if str(def.get("id", "")) not in hired:
			return str(def.get("id", ""))
	return ""


func _rule(key: String) -> int:
	var value: Variant = _rules.get(key)
	return Merc.whole(value) if value is int or value is float else 0
