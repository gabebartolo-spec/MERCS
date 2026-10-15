class_name Armoury
extends RefCounted
## Gear as coin (Economy's module, Phase 5 C6, docs/plans/phase5_contracts.md; director
## 2026-10-16: "Armour: strong but costly; costs = slower to act + price and upkeep", Q-10
## "Towns buy and sell", Q-11 "Worn = one point weaker, worth less"). Three things:
## - the worn forms: each weapon or armour in data/equipment.json may have a "worn" block, its
##   battered form (own id, name, bonus one point lower, lower price; same slot and class), and
##   the pieces looted from the fallen are these (spoils());
## - the price of a piece, what a town asks for it new and pays for it back (buy, sell);
## - the upkeep: coin a day for each merc on the roster by the armour class he fights in (his
##   gear line's, else the armour he wears: Merc.to_battle_unit), on the day's bill.
## The armour's other cost, slowness, is the battle's (BattleGear rule 4). Nothing here rolls
## or reads the clock. Rules: data/balance/economy.json "armoury" (`sell_pct`, `upkeep`).

## sell_pct is a percent of the price.
const PERCENT := 100
const WORN := "worn"
## Set on a worn form's definition: the id of the piece it is the battered form of.
const WORN_OF := "worn_of"

var _rules := {}
## Battle class -> the worn form's id looted for it (the first piece of that class with one).
var _worn_by_class := {}


## rules: data/balance/economy.json "armoury". items: the economy's gear definitions by id
## (data/equipment.json); each piece's worn form is added to them under its own id, so the
## pack, the slots and the save hold it like any other piece.
func setup(rules: Dictionary, items: Dictionary) -> void:
	_rules = rules
	_worn_by_class.clear()
	for id: Variant in items.keys():
		var def := _dict(items, id)
		var worn := _dict(def, WORN).duplicate(true)
		if str(worn.get("id", "")) == "":
			continue
		worn["slot"] = def.get("slot", "")
		worn[WORN_OF] = str(id)
		var named := str(def.get("class", ""))
		if named != "":
			worn["class"] = named
			if not _worn_by_class.has(named):
				_worn_by_class[named] = str(worn["id"])
		items[str(worn["id"])] = worn


## What the fallen left that a looter can take: for each battle class they carried (in order),
## the worn form of that class, or nothing when no piece of that class has one.
func spoils(carried: Array) -> Array[String]:
	var pool: Array[String] = []
	for named: Variant in carried:
		var worn := str(_worn_by_class.get(str(named), ""))
		if worn != "":
			pool.append(worn)
	return pool


## The coin a town asks for this piece new (its "price"), 0 for a piece with none.
static func price(economy: Economy, item_id: String) -> int:
	return Merc.whole(_dict(economy.items(), item_id).get("price", 0))


## The coin a town pays for this piece: `sell_pct` percent of its price, rounded down.
func sale_price(economy: Economy, item_id: String) -> int:
	return price(economy, item_id) * maxi(0, _rule("sell_pct")) / PERCENT


## What the town sells: every new piece with a price, in data order (worn pieces come only from
## the fallen).
static func stock(economy: Economy) -> Array[String]:
	var ids: Array[String] = []
	for id: Variant in economy.items():
		if not _dict(economy.items(), id).has(WORN_OF) and price(economy, str(id)) > 0:
			ids.append(str(id))
	return ids


## Buys a new piece into the pack for its price. False (and no change) when the town does not
## sell it or the purse falls short.
func buy(economy: Economy, item_id: String) -> bool:
	var cost := price(economy, item_id)
	if item_id not in stock(economy) or economy.purse < cost:
		return false
	economy.purse -= cost
	economy.inventory.append(item_id)
	return true


## Sells a piece from the pack for its sale price. False (and no change) when the pack has none.
func sell(economy: Economy, item_id: String) -> bool:
	if item_id not in economy.inventory:
		return false
	economy.inventory.erase(item_id)
	economy.purse += sale_price(economy, item_id)
	return true


## One merc's armour upkeep for a day: `upkeep` for the armour class he fights in.
func upkeep_of(merc: Merc) -> int:
	var unit := merc.to_battle_unit(BattleUnit.COMPANY, Vector2i.ZERO, false)
	if unit.armour_class == "":
		return 0
	return maxi(0, Merc.whole(_dict(_rules, "upkeep").get(unit.armour_class, 0)))


## The day's armour upkeep for this roster.
func upkeep(roster: Array[Merc]) -> int:
	var total := 0
	for merc: Merc in roster:
		total += upkeep_of(merc)
	return total


func _rule(key: String) -> int:
	var value: Variant = _rules.get(key)
	return Merc.whole(value) if value is int or value is float else 0


static func _dict(block: Dictionary, key: Variant) -> Dictionary:
	var value: Variant = block.get(key, {})
	return value if value is Dictionary else {}
