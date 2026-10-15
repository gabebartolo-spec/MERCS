class_name Contracts
extends RefCounted
## The contract board (Phase 2 milestone 6): the contracts the hub posts, drawn from the two
## factions weighted by each one's pressure (data/factions.json), against a site in the region,
## for a reward and a deadline from data/balance/economy.json "contracts". Seeded on the Rng
## "contracts" stream. A contract is a plain record: {"id", "faction", "site", "reward",
## "deadline" (a day), "accepted"}. Accepting, completing and expiring are Economy's.

const STREAM := "contracts"


## A fresh board posted on `day`: board_min to board_max contracts. factions: the entries of
## data/factions.json; site_ids: the places a contract can name (never the hub). The records
## carry no id yet (Economy numbers them). Empty with no faction or no site.
static func post(
	rules: Dictionary, factions: Array[Dictionary], site_ids: Array[String], day: int, rng: Rng
) -> Array[Dictionary]:
	var board: Array[Dictionary] = []
	if factions.is_empty() or site_ids.is_empty():
		return board
	var count := rng.roll(STREAM, _knob(rules, "board_min"), _knob(rules, "board_max"))
	for i: int in count:
		var wait := rng.roll(STREAM, _knob(rules, "deadline_min"), _knob(rules, "deadline_max"))
		board.append(
			{
				"faction": _pick_faction(factions, rng),
				"site": site_ids[rng.roll(STREAM, 0, site_ids.size() - 1)],
				"reward": rng.roll(STREAM, _knob(rules, "reward_min"), _knob(rules, "reward_max")),
				"deadline": day + wait,
				"accepted": false,
			}
		)
	return board


## One faction id by pressure: the point a roll lands on, walked down the factions in order.
static func _pick_faction(factions: Array[Dictionary], rng: Rng) -> String:
	var total := 0
	for faction: Dictionary in factions:
		total += maxi(0, Merc.whole(faction.get("pressure", 0)))
	if total <= 0:
		return str(factions[0].get("id", ""))
	var point := rng.roll(STREAM, 1, total)
	for faction: Dictionary in factions:
		point -= maxi(0, Merc.whole(faction.get("pressure", 0)))
		if point <= 0:
			return str(faction.get("id", ""))
	return str(factions[0].get("id", ""))


static func _knob(rules: Dictionary, key: String) -> int:
	return Merc.whole(rules.get(key, 0))
