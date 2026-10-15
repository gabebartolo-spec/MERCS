class_name HubPack
extends RefCounted
## The hub's pack and loot words (split from HubDirector for its file limit): the generic gear in
## the pack with the wearer button, the loot line of a won fight, and a gear item's words.
## Static; reads the company and the world, changes nothing.


## The pack: the wearer button and one equip button per distinct item (or a line saying empty).
static func rows(company: Company, wearer: String) -> Array[Dictionary]:
	var economy := company.economy
	var rows: Array[Dictionary] = [HubPanel.line(HubPanel.HEADING, Text.t("hub.pack.title"))]
	if economy.inventory.is_empty():
		rows.append(HubPanel.line(HubPanel.LABEL, Text.t("hub.pack.empty")))
		return rows
	var params := {"name": company.name_of(wearer)}
	rows.append(HubPanel.button_row("wearer", "next", Text.t("hub.wearer", params), true))
	var shown: Array[String] = []
	for item: String in economy.inventory:
		if item in shown:
			continue
		shown.append(item)
		var words := Text.t("hub.item.equip", item_words(company, item))
		rows.append(HubPanel.button_row("equip", item, words, true))
	return rows


## The loot line: coin, the supplies the fight won (from the world's log), the gear.
static func loot_line(company: Company, world: WorldSim, loot: Dictionary) -> String:
	var item := str(loot.get("item", ""))
	var gear := Text.t("hub.loot.none") if item == "" else str(item_words(company, item)["item"])
	var params := {"coin": loot.get("coin", 0), "supplies": _last_supplies(world), "item": gear}
	return Text.t("hub.loot", params)


static func item_words(company: Company, item_id: String) -> Dictionary:
	var def: Variant = company.economy.items().get(item_id, {})
	var found: Dictionary = def if def is Dictionary else {}
	var bonuses: Array[String] = []
	var added: Variant = found.get("bonus", {})
	if added is Dictionary:
		var numbers: Dictionary = added
		for stat: Variant in numbers:
			var key := "company.stat." + str(stat)
			bonuses.append(Text.t(key, {"value": "%+d" % Merc.whole(numbers[stat])}))
	return {"item": str(found.get("name", item_id)), "bonus": ", ".join(bonuses)}


static func _last_supplies(world: WorldSim) -> int:
	for i: int in range(world.log.size() - 1, -1, -1):
		if world.log[i].get("step") == "encounter":
			return Merc.whole(world.log[i].get("supplies", 0))
	return 0
