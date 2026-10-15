extends RefCounted
## The economy suite's armoury checks, run by tests/run_economy_tests.gd (Phase 5 C6,
## docs/plans/phase5_contracts.md; director: worn loot from the fallen, armour "strong but
## costly", Q-10 towns buy and sell, Q-11 worn = one point weaker, worth less): the worn forms
## in the data, loot drawn from what the fallen carried (and only the fallen), buying and
## selling, the armour upkeep on the day's bill, and the save: worn pieces in the pack and on a
## merc survive a reload, reload-then-continue equals an uninterrupted run, and an economy saved
## before C6 loads with every piece as it was. Numbers are read from the data, never restated.
## Seeded by design: the economy suite's seed.

const Fixture := preload("res://tests/lib/company_fixture.gd")
const PRE_ARMOURY := "res://tests/fixtures/save/economy_pre_armoury.json"
const SEED := 424242
const SEEDS := 40
const SITES: Array[String] = ["site_1", "site_2", "site_3"]
const WHO := "merc_3"
const MAIL := "arm_mail_shirt"
const MAIL_WORN := "arm_mail_shirt_worn"
const BLADE := "wpn_iron_blade"
## A battle field big enough for the three fighters below.
const FIELD := Vector2i(8, 6)

var _check: Callable


## check: the runner's check(condition, expectation).
func run(check: Callable) -> void:
	_check = check
	_worn_forms()
	_loot_from_the_fallen()
	_fallen_are_the_down()
	_buy_and_sell()
	_upkeep_on_the_bill()
	_worn_round_trip()
	_old_save()


func _company() -> Company:
	return Company.start(Fixture.defs())


## Q-11: each worn form is one point weaker than its piece (bonus total one lower), worth less,
## the same slot and class, and reachable by id from the economy.
func _worn_forms() -> void:
	var items := _company().economy.items()
	var wrong: Array[String] = []
	var count := 0
	for entry: Variant in Fixture.json(Fixture.EQUIPMENT)["equipment"]:
		var def: Dictionary = entry
		if not def.has("worn"):
			continue
		count += 1
		var form: Dictionary = def["worn"]
		var worn: Dictionary = items.get(str(form["id"]), {})
		var weaker := _total(worn.get("bonus", {})) == _total(def["bonus"]) - 1
		var cheaper := Merc.whole(worn.get("price", 0)) < Merc.whole(def.get("price", 0))
		var same: bool = worn.get("slot") == def["slot"] and worn.get("class") == def.get("class")
		if not (weaker and cheaper and same and worn.get(Armoury.WORN_OF) == def["id"]):
			wrong.append(str(def["id"]))
	_check.call(
		count > 0 and wrong.is_empty(),
		"every worn form is one point weaker and worth less (%d forms), wrong: %s" % [count, wrong]
	)


## Beating a mail-wearer can leave worn mail; beating men who carried nothing never leaves a
## piece; across seeds both pieces a watchman carried turn up.
func _loot_from_the_fallen() -> void:
	var watchman := {"won": true, Loot.FALLEN_GEAR: _carried("watchman")}
	var bare := {"won": true, Loot.FALLEN_GEAR: _carried("recruit_placeholder")}
	var seen := {}
	var from_bare := 0
	for seed_value: int in range(1, SEEDS):
		var item := str(
			_company().economy.take_loot("patrol", Rng.from_seed(seed_value), watchman)["item"]
		)
		if item != "":
			seen[item] = true
		var none := _company().economy.take_loot("patrol", Rng.from_seed(seed_value), bare)
		from_bare += 0 if str(none["item"]) == "" else 1
	_check.call(
		seen.has(MAIL_WORN) and seen.size() == 2 and from_bare == 0,
		(
			"fallen watchmen leave worn mail and worn spears, men with nothing leave none: %s, %d"
			% [seen.keys(), from_bare]
		)
	)
	var rng := Rng.from_seed(SEED)
	_company().economy.take_loot("patrol", rng, watchman)
	var streams: Dictionary = rng.state().get("streams", {})
	_check.call(
		streams.keys() == ["loot"], 'loot from the fallen rolls only "loot": %s' % [streams.keys()]
	)


## EncounterBattle.result lists what the down enemies carried; a standing enemy (fled, taken)
## carried his gear away.
func _fallen_are_the_down() -> void:
	var fighters: Array[BattleUnit] = [
		BattleUnit.make("orc", BattleUnit.COMPANY, Vector2i(1, 1), Fixture.fighter("orc")),
		BattleUnit.make(
			"watchman_0", BattleUnit.ENEMY, Vector2i(5, 1), Fixture.fighter("watchman")
		),
		BattleUnit.make("bandit_1", BattleUnit.ENEMY, Vector2i(5, 3), Fixture.fighter("bandit")),
	]
	var battle := Battle.new()
	battle.setup(Fixture.rules(), {"size": FIELD}, fighters, Rng.from_seed(SEED))
	battle.unit("watchman_0").down = true
	var result := EncounterBattle.result(battle)
	_check.call(
		Loot.fallen_gear(result) == _carried("watchman"),
		"a battle's result lists the gear of the fallen only: %s" % [Loot.fallen_gear(result)]
	)


## Towns sell new pieces for their price and buy any piece back for sell_pct of its own price;
## worn pieces are not on sale and fetch less.
func _buy_and_sell() -> void:
	var economy := _company().economy
	var price := Armoury.price(economy, MAIL)
	economy.purse = price
	var bought := economy.buy(MAIL) and economy.purse == 0 and MAIL in economy.inventory
	_check.call(bought, "buying a mail shirt costs its price, %d, and puts it in the pack" % price)
	economy.purse = price
	_check.call(
		not economy.buy(MAIL_WORN) and not economy.buy("arm_none") and economy.purse == price,
		"a town does not sell worn pieces or pieces that do not exist"
	)
	economy.purse = price - 1
	_check.call(not economy.buy(MAIL) and economy.purse == price - 1, "a short purse buys nothing")
	economy.inventory.append(MAIL_WORN)
	var new_sale := economy.armoury.sale_price(economy, MAIL)
	var worn_sale := economy.armoury.sale_price(economy, MAIL_WORN)
	var before := economy.purse
	var sold := economy.armoury.sell(economy, MAIL) and economy.armoury.sell(economy, MAIL_WORN)
	_check.call(
		sold and economy.purse == before + new_sale + worn_sale and worn_sale < new_sale,
		"a town buys a new piece for %d and a worn one for less, %d" % [new_sale, worn_sale]
	)
	_check.call(not economy.armoury.sell(economy, MAIL), "nothing is sold from an empty pack")


## Each merc's armour costs its class's upkeep every day, owed with the wages: the orc's plate,
## and merc_3 once he wears a worn mail shirt.
func _upkeep_on_the_bill() -> void:
	var company := _company()
	var economy := company.economy
	var table := Fixture.sect(Fixture.sect(Fixture.json(Fixture.ECONOMY), "armoury"), "upkeep")
	var merc := company.member(WHO)
	var bare := economy.armoury.upkeep_of(merc)
	economy.inventory.append(MAIL_WORN)
	economy.equip(company, WHO, MAIL_WORN)
	_check.call(
		(
			economy.armoury.upkeep_of(company.member("orc")) == Merc.whole(table["plate"])
			and bare == 0
			and economy.armoury.upkeep_of(merc) == Merc.whole(table["mail"])
		),
		"the orc's plate and a worn mail shirt cost their class's upkeep, no armour costs nothing"
	)
	var day := economy.wage_per_day(company.roster) + economy.armoury.upkeep(company.roster)
	economy.on_day(company.roster, 1, SITES, Rng.from_seed(SEED))
	_check.call(
		economy.owed == day and economy.armoury.upkeep(company.roster) > 0,
		"a day's bill is the wages and the upkeep: owed %d" % economy.owed
	)


## A worn piece in the pack and one on a merc survive a save; reload then continue matches the
## run that never stopped.
func _worn_round_trip() -> void:
	var company := _company()
	var rng := Rng.from_seed(SEED)
	company.economy.inventory.append_array([MAIL_WORN, "wpn_iron_blade_worn"])
	company.economy.equip(company, WHO, MAIL_WORN)
	company.economy.on_day(company.roster, 1, SITES, rng)
	var parsed: Variant = JSON.parse_string(JSON.stringify(company.state()))
	var saved: Dictionary = parsed if parsed is Dictionary else {}
	var reloaded := Company.restore(saved, Fixture.defs())
	_check.call(
		(
			reloaded.economy.inventory == company.economy.inventory
			and reloaded.member(WHO).gear["armour"] == MAIL_WORN
			and reloaded.member(WHO).stat("hp") == company.member(WHO).stat("hp")
		),
		"worn pieces in the pack and on a merc survive a save and reload"
	)
	var again := Rng.restore(rng.state())
	for day: int in [2, 3]:
		company.economy.on_day(company.roster, day, SITES, rng)
		reloaded.economy.on_day(reloaded.roster, day, SITES, again)
	_check.call(
		JSON.stringify(reloaded.state()) == JSON.stringify(company.state()),
		"reload then continue matches the run that never stopped, upkeep and all"
	)


## An economy saved before C6 (new pieces only) loads with every piece as it was, none read
## as worn.
func _old_save() -> void:
	var saved := Fixture.json(PRE_ARMOURY)
	var economy := Economy.restore(saved, Fixture.defs())
	_check.call(
		(
			economy.inventory == [MAIL, BLADE, "trk_lucky_knot"]
			and economy.last_loot.get("item") == "trk_lucky_knot"
			and not Fixture.sect(economy.items(), MAIL).has(Armoury.WORN_OF)
		),
		"an economy saved before worn gear loads its pack as it was: %s" % [economy.inventory]
	)


## The battle classes a fighter of `kind` carries (data/balance/battle.json), weapon then
## armour, as EncounterBattle.result reports them for one who fell.
static func _carried(kind: String) -> Array[String]:
	var unit := BattleUnit.make(kind, BattleUnit.ENEMY, Vector2i.ZERO, Fixture.fighter(kind))
	var carried: Array[String] = []
	for named: String in [unit.weapon_class, unit.armour_class]:
		if named != "":
			carried.append(named)
	return carried


static func _total(bonus: Variant) -> int:
	var total := 0
	if bonus is Dictionary:
		var numbers: Dictionary = bonus
		for key: Variant in numbers:
			total += Merc.whole(numbers[key])
	return total
