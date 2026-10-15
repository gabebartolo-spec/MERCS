extends "res://tests/lib/effect_case.gd"
## walk_drain: walking costs days. The same seed (424242): thirty steps out of the hub's gate
## and back again pass days, and each day drains the supplies; standing still passes none.

const Fixture := preload("res://tests/lib/world_fixture.gd")
const SEED := 424242
const STEPS := 30


func id() -> String:
	return "walk_drain"


func run() -> Dictionary:
	return {"on": _after(STEPS), "off": _after(0)}


func _after(steps: int) -> String:
	var world := Fixture.world(SEED)
	world.parties.clear()
	var walked := 0
	for walk: int in steps:
		if world.step(Vector2i(0, 1) if walk % 2 == 0 else Vector2i(0, -1)):
			walked += 1
	return "%d steps: day %d, %d supplies" % [walked, world.day, world.supplies]
