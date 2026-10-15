class_name Payroll
extends RefCounted
## Wages (Economy's module, Phase 5 C3, docs/plans/phase5_contracts.md): each merc's daily wage,
## set by his level; his cut of the share when a contract pays, the share being a part of the
## contract's pay split among the mercs who fought the job, weighted by level; and who is owed
## what. The economy keeps the total debt (`owed`) as before; this module keeps the same coin
## by merc, so a share left unpaid is owed to named men. Nothing here rolls or reads the clock.
## Rules: data/balance/economy.json "wages" (`day_by_level`, `share_pct`).

## share_pct is a percent of the reward.
const PERCENT := 100

## Coin owed and not yet paid, by merc id (wages fallen due plus any share). Cleared when the
## whole debt is paid. An older save has none: its debt is owed to the company as a whole.
var dues: Dictionary = {}

var _rules := {}


## rules: data/balance/economy.json "wages".
func setup(rules: Dictionary) -> void:
	_rules = rules


## A merc's wage for one day: the level table's entry for his level (the last entry past its
## end, nothing when the table is missing).
func day_wage(merc: Merc) -> int:
	var table := _table()
	if table.is_empty():
		return 0
	return table[clampi(merc.level() - 1, 0, table.size() - 1)]


## What one day of wages costs for this roster.
func wage_per_day(roster: Array[Merc]) -> int:
	var total := 0
	for merc: Merc in roster:
		total += day_wage(merc)
	return total


## A day's wages fall due: each merc is owed his day wage. Returns the day's total.
func fall_due(roster: Array[Merc]) -> int:
	var total := 0
	for merc: Merc in roster:
		total += _owe(merc.id, day_wage(merc))
	return total


## The share of a contract's pay: `share_pct` percent of the reward (rounded down), split among
## the mercs who fought the job, each cut weighted by his level. Cuts are whole coins: each
## merc gets his weighted part rounded down, and the coins left over go one each to the
## largest remainders (ties to the earlier merc in `fought`), so the whole share is owed. Each
## cut is owed to its merc. Returns the share's total, 0 when nobody fought.
func share(reward: int, fought: Array[Merc]) -> int:
	var pot := maxi(0, reward) * maxi(0, _rule("share_pct")) / PERCENT
	var weight := 0
	for merc: Merc in fought:
		weight += maxi(1, merc.level())
	if pot <= 0 or weight <= 0:
		return 0
	var cuts: Array[int] = []
	var left := pot
	for merc: Merc in fought:
		cuts.append(pot * maxi(1, merc.level()) / weight)
		left -= cuts[-1]
	var order := range(fought.size())
	order.sort_custom(
		func(a: int, b: int) -> bool:
			var rest_a := pot * maxi(1, fought[a].level()) % weight
			var rest_b := pot * maxi(1, fought[b].level()) % weight
			return rest_a > rest_b or (rest_a == rest_b and a < b)
	)
	for index: int in order:
		if left <= 0:
			break
		cuts[index] += 1
		left -= 1
	for index: int in fought.size():
		_owe(fought[index].id, cuts[index])
	return pot


## A merc died: whatever he was owed is forfeit, the company no longer owes it (director
## 2026-10-16). Returns the coin struck off the debt, 0 when he was owed nothing by name.
func forfeit(id: String) -> int:
	var coin := Merc.whole(dues.get(id, 0))
	dues.erase(id)
	return coin


## The whole debt was paid: nobody is owed anything.
func clear() -> void:
	dues.clear()


func restore(saved: Dictionary) -> void:
	dues.clear()
	for id: Variant in saved:
		var coin: Variant = saved[id]
		if (coin is int or coin is float) and Merc.whole(coin) > 0:
			dues[str(id)] = Merc.whole(coin)


func _owe(id: String, coin: int) -> int:
	if coin <= 0:
		return 0
	dues[id] = Merc.whole(dues.get(id, 0)) + coin
	return coin


func _table() -> Array[int]:
	var table: Array[int] = []
	var value: Variant = _rules.get("day_by_level", [])
	if value is Array:
		for entry: Variant in value:
			if entry is int or entry is float:
				table.append(maxi(0, Merc.whole(entry)))
	return table


func _rule(key: String) -> int:
	var value: Variant = _rules.get(key)
	return Merc.whole(value) if value is int or value is float else 0
