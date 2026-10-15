extends "res://tests/lib/effect_case.gd"
## world_tick: the daily supply drain. The same seed with company.supplies_per_day as the
## balance says, against the drain set to 0, after seven days at rest: the supplies differ.

const BALANCE := "res://data/balance/world.json"
const SEED := 424242
const DAYS := 7


func id() -> String:
	return "world_tick"


func run() -> Dictionary:
	var on_balance := json(BALANCE)
	var off_balance := on_balance.duplicate(true)
	var company: Dictionary = off_balance.get("company", {})
	company["supplies_per_day"] = 0
	return {"on": _supplies_after(on_balance), "off": _supplies_after(off_balance)}


func _supplies_after(balance: Dictionary) -> String:
	var world := WorldSim.new()
	world.start(balance, Rng.from_seed(SEED))
	for _day: int in DAYS:
		world.rest()
	return "%d supplies on day %d" % [world.supplies, world.day]
