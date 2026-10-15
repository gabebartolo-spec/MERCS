class_name Terms
extends RefCounted
## Terms and negotiation (Economy's module, Phase 5 C2, docs/plans/phase5_contracts.md): the
## player asks a price for a posted contract and how much of it comes as an advance, paid now,
## against the rest paid on return (Q-6). The employer's reply is computed, never rolled: he
## accepts, counters at his limit, or walks, by the faction's name with the company, the
## faction's need (its pressure in data/factions.json) and the ask. The player can read why:
## every reply carries the numbers it was judged on.
##
## Once per negotiation one merc the player picks may step in: a visible check from his
## bargaining trait (data/traits.json "bargain"; odds() is what the player is shown before the
## roll) on the Rng "terms" stream, never "story". Success raises the employer's limit, failure
## lowers it, for the rest of that contract's talks; the merc remembers it either way (a line
## in the economy's chronicle). An ask past the walk line ends the offer: the contract leaves
## the board and the faction thinks less of the company.
##
## The faction's name is C4's Standing (sim/economy/standing.gd, the economy's `standing`):
## the employer reads standing.reputation(faction) and a walk calls standing.walked(faction).
## Rules: data/balance/economy.json "terms". No node, no clock, no file.

const STREAM := "terms"
const ACCEPT := "accept"
const COUNTER := "counter"
const WALK := "walk"
const PERCENT := 100
## Chronicle keys (data/text/en.json) for the merc who stepped in.
const KEY_STEP_WON := "hub.terms.step_in_won"
const KEY_STEP_LOST := "hub.terms.step_in_lost"

var _standing: Standing = null
var _rules := {}
var _pressure := {}
var _bargain := {}


## rules: economy.json "terms"; factions: data/factions.json "factions"; traits:
## data/traits.json "traits" (each trait's "bargain" counts for every merc in its "held_by");
## standing: the economy's Standing, the company's name with each faction (C4).
func setup(
	rules: Dictionary, factions: Array[Dictionary], traits: Array[Dictionary], standing: Standing
) -> void:
	_rules = rules
	_standing = standing
	for def: Dictionary in factions:
		_pressure[str(def.get("id", ""))] = Merc.whole(def.get("pressure", 0))
	for def: Dictionary in traits:
		var held: Variant = def.get("held_by", [])
		if held is Array:
			for merc_id: Variant in held:
				var key := str(merc_id)
				_bargain[key] = Merc.whole(_bargain.get(key, 0)) + Merc.whole(def.get("bargain", 0))


## The company's name with a faction, as the employer reads it (C4's Standing).
func reputation(faction_id: String) -> int:
	return _standing.reputation(faction_id) if _standing != null else 0


## A faction's need: its pressure on the region.
func need(faction_id: String) -> int:
	return Merc.whole(_pressure.get(faction_id, 0))


## A merc's bargaining, from his traits (0 when he has none).
func bargain(merc_id: String) -> int:
	return Merc.whole(_bargain.get(merc_id, 0))


## The chance, in whole percent, that this merc's step-in succeeds: shown before the roll.
func odds(merc_id: String) -> int:
	return Checks.odds(_rule("die_sides"), bargain(merc_id), _rule("step_in_difficulty"))


## The most the employer will give for `row`, in percent of its posted reward: the base, plus
## his regard for the company, plus his need, plus whatever a step-in moved.
func limit_pct(row: Dictionary) -> int:
	var faction := str(row.get("faction", ""))
	return (
		_rule("base_limit_pct")
		+ reputation(faction) * _rule("reputation_weight_pct") / PERCENT
		+ need(faction) * _rule("need_weight_pct") / PERCENT
		+ Merc.whole(row.get("step_shift", 0))
	)


## The employer's reply to an ask of `price` coin with `advance` of it paid now, computed:
## {"reply", "reputation", "need", "limit_pct", "ask_pct", "counter_price", "counter_advance"}.
## An advance costs him more than coin on return ("advance_cost_pct" of each coin). Inside his
## limit he accepts; up to "counter_band_pct" past it he counters at his limit (the same
## advance, or less if the price falls below it); further, he walks.
func judge(row: Dictionary, price: int, advance: int) -> Dictionary:
	var reward := maxi(1, Merc.whole(row.get("reward", 0)))
	var faction := str(row.get("faction", ""))
	var limit := limit_pct(row)
	var asked := price * PERCENT + advance * _rule("advance_cost_pct")
	var give := reward * limit
	var reply := ACCEPT
	if asked > give + reward * _rule("counter_band_pct"):
		reply = WALK
	elif asked > give:
		reply = COUNTER
	var counter_price := maxi(0, (give - advance * _rule("advance_cost_pct")) / PERCENT)
	return {
		"reply": reply,
		"reputation": reputation(faction),
		"need": need(faction),
		"limit_pct": limit,
		"ask_pct": asked / reward,
		"counter_price": counter_price if reply == COUNTER else 0,
		"counter_advance": mini(advance, counter_price) if reply == COUNTER else 0,
	}


## Negotiates a posted, untaken contract of `economy` (see Economy.negotiate for `ask`). The
## reply as judge() gives it plus "check" (the step-in's numbers, {} when none stepped in), or
## {"reply": ""} and no change for a contract not open to talks or an ask that makes no sense.
func negotiate(
	economy: Economy, company: Company, contract_id: String, ask: Dictionary
) -> Dictionary:
	var row := economy.book.contract(contract_id)
	var price := Merc.whole(ask.get("price", 0))
	var advance := Merc.whole(ask.get("advance", 0))
	if row.is_empty() or row.get("accepted") == true or advance < 0 or advance > price:
		return {"reply": ""}
	var check := _step_in(economy, company, row, ask)
	var result := judge(row, price, advance)
	result["check"] = check
	match str(result["reply"]):
		ACCEPT:
			_agree(economy, row, price, advance)
		COUNTER:
			row["counter_price"] = result["counter_price"]
			row["counter_advance"] = result["counter_advance"]
		WALK:
			economy.book.board.erase(row)
			economy.standing.walked(str(row.get("faction", "")))
	return result


## The deal is struck: the advance is paid now; the contract's reward becomes the agreed price
## and "advance" what of it was paid up front (Economy.complete pays the rest on return; C4's
## Standing.sizeable reads the two); the posted reward stays as "terms_posted".
func _agree(economy: Economy, row: Dictionary, price: int, advance: int) -> void:
	row["accepted"] = true
	row["terms_posted"] = Merc.whole(row.get("reward", 0))
	row["reward"] = price
	row["advance"] = advance
	row.erase("counter_price")
	row.erase("counter_advance")
	economy.purse += advance


## The once-per-negotiation step-in, when the ask names a merc on the roster and nobody has
## stepped in on this contract yet: the roll on the "terms" stream, the limit moved, and the
## merc's chronicle line. {} when nobody steps in.
func _step_in(economy: Economy, company: Company, row: Dictionary, ask: Dictionary) -> Dictionary:
	var speaker := str(ask.get("speaker", ""))
	var held: Variant = ask.get("rng")
	if speaker == "" or row.has("step_in") or company.member(speaker) == null or not held is Rng:
		return {}
	var rng: Rng = held
	var skill := bargain(speaker)
	var roll := rng.roll(STREAM, 1, _rule("die_sides"))
	var need_roll := _rule("step_in_difficulty") - skill
	var success := roll >= need_roll
	var shift := _rule("step_in_shift_pct")
	row["step_in"] = speaker
	row["step_shift"] = shift if success else -shift
	(
		economy
		. chronicle
		. append(
			{
				"day": Merc.whole(ask.get("day", 0)),
				"merc": speaker,
				"key": KEY_STEP_WON if success else KEY_STEP_LOST,
				"contract": str(row.get("id", "")),
			}
		)
	)
	return {
		"merc": speaker,
		"roll": roll,
		"skill": skill,
		"need": need_roll,
		"odds": odds(speaker),
		"success": success,
	}


func _rule(key: String) -> int:
	var value: Variant = _rules.get(key)
	return Merc.whole(value) if value is int or value is float else 0
