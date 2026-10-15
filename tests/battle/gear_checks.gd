extends RefCounted
## The battle suite's equipment-physics checks (Phase 4 P1b, BattleGear; director's rulings
## D-092), run by tests/run_battle_tests.gd: the classes in data stay within the caps and every
## fighter and merc names only known classes; a fighter is dressed from data; armour soaks a
## hit unless the blow finds its gap (mail is open to a thrust, a mace dents plate), never below
## min_damage; a whole shield adds defense, an axe splits it on a blow that would have hit
## without it and a sword never does; plate is slow, once; odds() gives the same numbers the
## blow uses and rolls nothing; a merc fights with his gear line's classes, generic gear only
## filling a slot the line leaves open. Seeded by design: every roll comes from
## Rng.from_seed(SEED).

const BATTLE_DATA := "res://data/balance/battle.json"
const MERCS_DATA := "res://data/mercs.json"
const CAPS_DATA := "res://data/caps.json"
const SEED := 424242
const GRID := Vector2i(8, 8)
const SURE_HIT := 100
const SURE_MISS := -100
const PROBE := 40

var _check: Callable


## check: the runner's check(condition, expectation).
func run(check: Callable) -> void:
	_check = check
	_check_data()
	_check_dress()
	_check_soak()
	_check_shield()
	_check_slow()
	_check_odds()
	_check_merc()


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _rules() -> Dictionary:
	return _json(BATTLE_DATA).get("rules", {})


func _gear_rules() -> Dictionary:
	return _rules().get("gear", {})


func _knob(block: String, kind: String, key: String) -> int:
	var group: Dictionary = _gear_rules().get(block, {})
	var def: Dictionary = group.get(kind, {})
	return BattleRules.read(def, key)


func _duel(attacker: Dictionary, defender: Dictionary) -> Battle:
	var a := BattleUnit.make("a", BattleUnit.COMPANY, Vector2i(1, 1), attacker)
	var d := BattleUnit.make("d", BattleUnit.ENEMY, Vector2i(2, 1), defender)
	a.initiative = SURE_HIT
	var pair: Array[BattleUnit] = [a, d]
	var battle := Battle.new()
	battle.setup(_rules(), {"size": GRID}, pair, Rng.from_seed(SEED))
	return battle


## One sure hit by a on d (seeded); its "damage" event.
func _blow(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	var battle := _duel(attacker, defender)
	for event: Dictionary in battle.apply(_strike(battle, "d")):
		if event.get("type") == BattleResolver.EVENT_DAMAGE:
			return event
	return {}


func _check_data() -> void:
	var caps: Dictionary = _json(CAPS_DATA).get("caps", {})
	var weapons: Dictionary = _gear_rules().get("weapons", {})
	var armour: Dictionary = _gear_rules().get("armour", {})
	var known_weapons := weapons.keys().all(func(k: String) -> bool: return k in BattleGear.WEAPONS)
	var known_armour := armour.keys().all(func(k: String) -> bool: return k in BattleGear.ARMOURS)
	var bows := weapons.keys().filter(func(k: String) -> bool: return k == BattleGear.BOW).size()
	var shields := 1 if _gear_rules().has(BattleGear.SHIELD) else 0
	_check.call(
		(
			known_weapons
			and known_armour
			and weapons.size() <= Merc.whole(caps.get("weapon_classes", 0))
			and armour.size() <= Merc.whole(caps.get("armour_classes", 0))
			and shields <= Merc.whole(caps.get("shields", 0))
			and bows <= Merc.whole(caps.get("bows", 0))
		),
		(
			"rules.gear holds only the named classes, within the caps (%d weapons, %d armour)"
			% [weapons.size(), armour.size()]
		)
	)
	var odd := _odd_fighters() + _odd_mercs()
	_check.call(
		odd.is_empty(),
		(
			"every fighter's gear is a known class; a merc's gear line agrees with its fighter: %s"
			% [odd]
		)
	)


func _odd_fighters() -> Array[String]:
	var fighters: Dictionary = _json(BATTLE_DATA).get("fighters", {})
	var known := BattleGear.WEAPONS + BattleGear.ARMOURS + [BattleGear.SHIELD]
	var odd: Array[String] = []
	for kind: String in fighters:
		var stats: Dictionary = fighters[kind]
		var worn: Dictionary = stats.get(BattleGear.GEAR_KEY, {})
		for name: String in worn:
			if name not in known:
				odd.append("%s:%s" % [kind, name])
	return odd


func _odd_mercs() -> Array[String]:
	var fighters: Dictionary = _json(BATTLE_DATA).get("fighters", {})
	var mercs: Array = _json(MERCS_DATA).get("mercs", [])
	var odd: Array[String] = []
	for entry: Dictionary in mercs:
		var line: Dictionary = entry.get("gear_line", {})
		var from: Dictionary = fighters.get(str(entry.get("stats_from", "")), {})
		var fighter_gear: Dictionary = from.get(BattleGear.GEAR_KEY, {})
		for slot: String in ["weapon", "armour"]:
			if line.has(slot) and not from.is_empty() and fighter_gear.get(line[slot]) != true:
				odd.append("%s:%s disagrees with battle.json" % [entry.get("id"), line[slot]])
	return odd


func _check_dress() -> void:
	var fighters: Dictionary = _json(BATTLE_DATA).get("fighters", {})
	var orc_stats: Dictionary = fighters.get("orc", {})
	var watch_stats: Dictionary = fighters.get("watchman", {})
	var orc := BattleUnit.make("o", BattleUnit.COMPANY, Vector2i.ZERO, orc_stats)
	var watch := BattleUnit.make("w", BattleUnit.ENEMY, Vector2i.ZERO, watch_stats)
	var named := BattleUnit.make(
		"n",
		BattleUnit.COMPANY,
		Vector2i.ZERO,
		{"weapon_class": "mace", "armour_class": "gown", "gear": {"axe": true, "leather": true}}
	)
	_check.call(
		(
			orc.weapon_class == BattleGear.AXE
			and orc.armour_class == BattleGear.PLATE
			and not orc.shield
			and watch.weapon_class == BattleGear.SPEAR
			and watch.shield
			and named.weapon_class == BattleGear.MACE
			and named.armour_class == BattleGear.LEATHER
		),
		(
			"fighters are dressed from data (the orc: axe, plate; the watchman's shield); "
			+ "a named class outranks the gear block, an unknown name does not count"
		)
	)


func _check_soak() -> void:
	var plate := _knob("armour", BattleGear.PLATE, "soak")
	var leather := _knob("armour", BattleGear.LEATHER, "soak")
	var floor_damage := BattleRules.read(_gear_rules(), "min_damage")
	var big := plate + SURE_HIT
	var sword_bare := _hit(1, {"sword": true}, {})
	var cut := _hit(big, {"sword": true}, {"plate": true})
	var crush := _hit(big, {"mace": true}, {"plate": true})
	var thrust_mail := _hit(big, {"spear": true}, {"mail": true})
	var bare_leather := _hit(big, {}, {"leather": true})
	var tiny := _hit(1, {"sword": true}, {"plate": true})
	(
		_check
		. call(
			(
				plate > leather
				and leather > 0
				and Merc.whole(cut.get("soaked", 0)) == plate
				and not crush.has("soaked")
				and not thrust_mail.has("soaked")
				and Merc.whole(bare_leather.get("soaked", 0)) == leather
				and Merc.whole(tiny.get("amount", 0)) == mini(1, floor_damage)
				and not sword_bare.has("soaked")
			),
			(
				(
					"plate soaks %d of a cut, a mace dents it, a spear goes through mail, leather soaks "
					% plate
				)
				+ (
					"%d of anything, never below min_damage (%s %s %s %s %s)"
					% [leather, cut, crush, thrust_mail, bare_leather, tiny]
				)
			)
		)
	)


## A sure hit of 1..damage by a fighter with `weapon` gear on one with `armour` gear.
func _hit(damage: int, weapon: Dictionary, armour: Dictionary) -> Dictionary:
	return _blow(
		{"attack": SURE_HIT, "damage": damage, "gear": weapon}, {"hp": SURE_HIT * 2, "gear": armour}
	)


## The hit roll's need against a shield; whether an axe or a sword splits it over many blows.
func _check_shield() -> void:
	var shield: Dictionary = _gear_rules().get(BattleGear.SHIELD, {})
	var guard := BattleRules.read(shield, "defense")
	var bare := _duel({"gear": {"sword": true}}, {"hp": SURE_HIT})
	var held := _duel({"gear": {"sword": true}}, {"hp": SURE_HIT, "gear": {"shield": true}})
	var need_bare := BattleRules.read(bare.odds(_strike(bare, "d")), "need")
	var need_held := BattleRules.read(held.odds(_strike(held, "d")), "need")
	var axe := _splits({"axe": true})
	var sword := _splits({"sword": true})
	var missed := _duel(
		{"attack": SURE_MISS, "gear": {"axe": true}}, {"hp": SURE_HIT, "gear": {"shield": true}}
	)
	missed.apply(_strike(missed, "d"))
	_check.call(
		(
			guard > 0
			and need_held == need_bare + guard
			and axe > 0
			and sword == 0
			and missed.unit("d").shield
		),
		(
			(
				"a shield adds %d to the roll needed; an axe split it in %d of %d tries, a sword "
				+ "in %d; a blow that misses even without it leaves it whole"
			)
			% [guard, axe, PROBE, sword]
		)
	)


## How many of PROBE seeded single blows by this weapon split the shield (one event each).
func _splits(weapon: Dictionary) -> int:
	var count := 0
	for i: int in PROBE:
		var a := BattleUnit.make("a", BattleUnit.COMPANY, Vector2i(1, 1), {"gear": weapon})
		var d := BattleUnit.make(
			"d", BattleUnit.ENEMY, Vector2i(2, 1), {"hp": SURE_HIT, "gear": {"shield": true}}
		)
		a.initiative = SURE_HIT
		var pair: Array[BattleUnit] = [a, d]
		var battle := Battle.new()
		battle.setup(_rules(), {"size": GRID}, pair, Rng.from_seed(SEED + i))
		var events := battle.apply(_strike(battle, "d"))
		var split := events.filter(
			func(e: Dictionary) -> bool: return e.get("type") == BattleGear.EVENT_SHIELD_BROKEN
		)
		if split.size() == 1 and not d.shield:
			count += 1
	return count


func _check_slow() -> void:
	var slow := _knob("armour", BattleGear.PLATE, "initiative")
	var knight := BattleUnit.make(
		"k", BattleUnit.COMPANY, Vector2i(1, 1), {"initiative": 3, "gear": {"plate": true}}
	)
	var page := BattleUnit.make(
		"p", BattleUnit.ENEMY, Vector2i(5, 5), {"initiative": 3, "gear": {"leather": true}}
	)
	var pair: Array[BattleUnit] = [knight, page]
	var battle := Battle.new()
	battle.setup(_rules(), {"size": GRID}, pair, Rng.from_seed(SEED))
	battle.setup(_rules(), {"size": GRID}, pair, Rng.from_seed(SEED))
	_check.call(
		(
			slow < 0
			and knight.initiative == 3 + slow
			and page.initiative == 3
			and battle.current() == page
		),
		(
			(
				"plate is slow: %d initiative, applied once however often the fight is set up, "
				+ "so the man in leather acts first"
			)
			% slow
		)
	)


func _check_odds() -> void:
	var battle := _duel(
		{"attack": 2, "damage": 6, "gear": {"sword": true}},
		{"hp": SURE_HIT, "defense": 1, "gear": {"plate": true, "shield": true}}
	)
	var rng_before := battle.odds(_strike(battle, "d"))
	var again := battle.odds(_strike(battle, "d"))
	var own_side := battle.odds(_strike(battle, "a"))
	var events := battle.apply(_strike(battle, "d"))
	var need := -1
	for event: Dictionary in events:
		if event.get("type") == BattleResolver.EVENT_ATTACK:
			need = Merc.whole(event.get("need", -1))
	var rules := _rules()
	var sides := Merc.whole(rules.get("die_sides", 0))
	var plate := _knob("armour", BattleGear.PLATE, "soak")
	var expected_chance := (sides - need + 1) * 100 / sides
	_check.call(
		(
			str(rng_before) == str(again)
			and Merc.whole(rng_before.get("need", 0)) == need
			and Merc.whole(rng_before.get("chance", 0)) == expected_chance
			and Merc.whole(rng_before.get("damage_max", 0)) == 6 - plate
			and Merc.whole(rng_before.get("soak", 0)) == plate
			and own_side.is_empty()
		),
		(
			(
				"odds() gives the roll the blow needs (%d), its chance and the damage after plate, "
				+ "rolls nothing, and {} for no foe: %s"
			)
			% [need, rng_before]
		)
	)


func _check_merc() -> void:
	var battle := _json(BATTLE_DATA)
	var fighters: Dictionary = battle.get("fighters", {})
	var defs: Array = _json(MERCS_DATA).get("mercs", [])
	var by_id := {}
	for entry: Dictionary in defs:
		by_id[entry.get("id")] = entry
	var level_xp: Array[int] = [0]
	var items := {
		"mail": {"slot": "armour", "class": "mail"}, "pike": {"slot": "weapon", "class": "spear"}
	}
	var orc_def: Dictionary = by_id.get("orc", {})
	var spare_def: Dictionary = by_id.get("merc_3", {})
	var orc := Merc.make(orc_def, fighters, level_xp)
	orc.items = items
	orc.gear["armour"] = "mail"
	var spare := Merc.make(spare_def, fighters, level_xp)
	spare.items = items
	var bare_unit := spare.to_battle_unit(BattleUnit.COMPANY, Vector2i.ZERO, false)
	spare.gear["armour"] = "mail"
	spare.gear["weapon"] = "pike"
	var orc_unit := orc.to_battle_unit(BattleUnit.COMPANY, Vector2i.ZERO, true)
	var spare_unit := spare.to_battle_unit(BattleUnit.COMPANY, Vector2i.ZERO, false)
	_check.call(
		(
			orc_unit.weapon_class == BattleGear.AXE
			and orc_unit.armour_class == BattleGear.PLATE
			and bare_unit.armour_class == ""
			and spare_unit.armour_class == BattleGear.MAIL
			and spare_unit.weapon_class == BattleGear.SPEAR
		),
		(
			"a merc fights with his gear line (the orc keeps axe and plate under a mail shirt); "
			+ "generic gear fills only a slot the line leaves open"
		)
	)


## The current fighter's weapon action on a target (the plain attack without a class, P1a).
func _strike(battle: Battle, target: String) -> Dictionary:
	return {"type": battle.kit(battle.current().id)[0], "target": target}
