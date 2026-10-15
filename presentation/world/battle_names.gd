class_name BattleNames
extends RefCounted
## The names a battle shows for its fighters (BattleView): from the company's data where
## given (a merc's own name), else by kind from the text table; a name two fighters share is
## numbered so a line or a button says which one. Words: data/text/en.json.


## {fighter id: display name} for every fighter of the battle.
static func of(battle: Battle, given: Dictionary) -> Dictionary:
	var plain := {}
	var count := {}
	for fighter: BattleUnit in battle.units:
		var text := _plain(fighter, given)
		plain[fighter.id] = text
		var before: int = count.get(text, 0)
		count[text] = before + 1
	var seen := {}
	var out := {}
	for fighter: BattleUnit in battle.units:
		var text: String = plain[fighter.id]
		if count[text] > 1:
			var number: int = seen.get(text, 0)
			seen[text] = number + 1
			text = Text.t("battle.name.numbered", {"name": text, "n": number + 1})
		out[fighter.id] = text
	return out


static func _plain(fighter: BattleUnit, given: Dictionary) -> String:
	if given.has(fighter.id):
		return str(given[fighter.id])
	var kind := fighter.id.rstrip("0123456789").trim_suffix("_")
	var key := ("cast.%s.name" if fighter.side == BattleUnit.COMPANY else "enemy.%s.name") % kind
	return Text.t(key)
