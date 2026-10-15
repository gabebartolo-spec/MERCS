extends "res://tests/lib/effect_case.gd"
## death_memory: the same company and seed, after a fight in which one merc falls and
## triage (every roll sent to death) takes him, and after a fight in which nobody falls.
## Both go through a save written as JSON and read back; what the reloaded company holds
## differs: a chronicle entry and a memory on a comrade, or neither.

const BALANCE := "res://data/balance/injury.json"
const INJURIES := "res://data/injuries.json"
const WORLD := "res://data/balance/world.json"
const SEED := 424242
const DAY := 10


func id() -> String:
	return "death_memory"


func run() -> Dictionary:
	return {"on": _after(["m_a"]), "off": _after([])}


func _after(downed: Array) -> String:
	var rules := json(BALANCE).duplicate(true)
	rules["triage"] = {"die_sides": 100, "wound_upto": 0, "temporary_upto": 0, "permanent_upto": 0}
	var defs: Array = json(INJURIES).get("injuries", [])
	var aftermath := Aftermath.new(Rng.from_seed(SEED), rules, defs)
	aftermath.day = DAY
	var mercs := {"m_a": {"id": "m_a"}, "m_b": {"id": "m_b"}}
	var battle_log: Array = []
	for merc_id: Variant in downed:
		battle_log.append({"type": "down", "unit": merc_id})
	aftermath.resolve(battle_log, mercs)
	var world_balance := json(WORLD)
	var world := WorldSim.new()
	var rng := Rng.from_seed(SEED)
	world.start(world_balance, rng)
	var text := JSON.stringify(SaveModel.to_dict(world, rng, aftermath.state(mercs)))
	var parsed: Dictionary = JSON.parse_string(text)
	var model := SaveModel.from_dict(parsed, world_balance)
	var back := Aftermath.restore(model.wounds, rng, rules, [])
	return (
		"%d in the chronicle, %d memories on m_b"
		% [back.chronicle.entries.size(), back.memory.of("m_b").size()]
	)
