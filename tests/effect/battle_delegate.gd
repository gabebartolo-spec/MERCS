extends "res://tests/lib/effect_case.gd"
## battle_delegate: the captain's place in a fight (Phase 4 P4; director Q-F, "no XP, small
## morale dip"). The whole starting company, one road fight on seed 424242 against the
## scenario's band, both sides played by MercPlay. "on": the captain leads and fights; "off":
## the captain sits out and the field sergeant leads. The outcome names who led, the morale
## the company started with (what the player sees before the fight), the fighters fielded, the
## fight's length and how many rounds it took (the captain earns no experience by sitting out:
## he is not fielded), so the two read differently.

const Fixture := preload("res://tests/lib/company_fixture.gd")
const SEED := 424242
const MAX_ACTIONS := 400


func id() -> String:
	return "battle_delegate"


func run() -> Dictionary:
	return {"on": outcome(false), "off": outcome(true)}


## One fight with the captain leading (`out` false) or sitting out, as a line of what it came to.
static func outcome(out: bool) -> String:
	var company := Company.start(Fixture.defs())
	FieldCommand.set_out(company, out)
	var fight := fight_of(company)
	var battle: Battle = fight["battle"]
	var fielded: Array[String] = fight["fielded"]
	FieldCommand.finish(company)
	return (
		"%s led, company morale %d at the start, %d fielded, %s in %d rounds"
		% [
			fight["leader"],
			fight["start_morale"],
			fielded.size(),
			"won" if battle.winner == BattleUnit.COMPANY else "lost",
			battle.round_number,
		]
	)


## The fight: {"battle", "leader": id of who led, "start_morale", "fielded": ids}.
static func fight_of(company: Company) -> Dictionary:
	var scenarios := Fixture.rows(Fixture.json(Fixture.SCENARIOS), "scenarios")
	var scenario: Dictionary = scenarios[0]
	var setup := Fixture.sect(scenario, "battle")
	var spots: Array[Vector2i] = []
	for pair: Variant in Fixture.rows(setup, "road_cells"):
		var cell: Array = pair
		spots.append(Fixture._cell(cell))
	var ids := company.fighting_order()
	var fighters := company.battle_units(ids, spots, BattleUnit.COMPANY)
	var enemies := Fixture.rows(setup, "enemies")
	for i: int in enemies.size():
		var enemy: Dictionary = enemies[i]
		var kind := str(enemy.get("fighter", ""))
		var enemy_cell: Array = enemy.get("cell", [0, 0])
		fighters.append(
			BattleUnit.make(
				"%s_%d" % [kind, i],
				BattleUnit.ENEMY,
				Fixture._cell(enemy_cell),
				Fixture.fighter(kind)
			)
		)
	var battle := Battle.new()
	var grid := Fixture.rows(setup, "grid")
	battle.setup(Fixture.rules(), {"size": Fixture._cell(grid)}, fighters, Rng.from_seed(SEED))
	FieldCommand.apply(company, battle)
	var leader := ""
	for fighter: BattleUnit in fighters:
		if fighter.side == BattleUnit.COMPANY and fighter.is_leader:
			leader = fighter.id
	var start_morale := battle.morale(BattleUnit.COMPANY)
	MercPlay.play_out(battle, Fixture.rules(), MAX_ACTIONS)
	return {"battle": battle, "leader": leader, "start_morale": start_morale, "fielded": ids}
