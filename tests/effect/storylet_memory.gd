extends "res://tests/lib/effect_case.gd"
## storylet_memory: the same seed, the same day, the same place, two companies that differ only
## in one memory (a comrade's death, written on every merc of one of them). The storylet fires
## for the company that holds it and the check's branch changes the company; the other
## company is offered nothing, and nothing changes.

const SEED := 424242
const DAY := 3
const DEAD := "fallen_comrade"
const MERCS := "res://data/mercs.json"
const BATTLE := "res://data/balance/battle.json"
const COMPANY := "res://data/balance/company.json"
const STORYLETS := "res://data/storylets.json"


func id() -> String:
	return "storylet_memory"


func run() -> Dictionary:
	return {"on": _rest(true), "off": _rest(false)}


func _rest(with_memory: bool) -> String:
	var fighters: Variant = json(BATTLE).get("fighters", {})
	var book := StoryBook.new()
	book.company = Company.start(
		{"mercs": json(MERCS), "fighters": fighters, "company": json(COMPANY)}
	)
	book.rng = Rng.from_seed(SEED)
	book.load_defs(json(STORYLETS))
	if with_memory:
		var ids: Array[String] = []
		for merc: Merc in book.company.roster:
			ids.append(merc.id)
		book.memory.on_death(DEAD, ids, DAY - 1, Memory.KEY_COMRADE_DIED)
	var made := book.offer({"hook": "rest", "day": DAY, "site": "site_hub", "site_kind": "hub"})
	if made.is_empty():
		return "no storylet, 0 effects"
	var result := book.choose(made, "mourner")
	var effects: Array = result.get("effects", [])
	return "%s fires, %s, %d effects" % [made.get("id"), result.get("branch"), effects.size()]
