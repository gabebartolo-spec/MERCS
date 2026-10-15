class_name ContractRows
extends RefCounted
## The hub's contract rows (Phase 5 C8, docs/plans/phase5_contracts.md): the board, each posted
## contract by its job's name with a button to talk terms (TermsPanel; the pay is negotiated,
## never taken as posted), and each contract the company has taken, with what was agreed and a
## button to walk away from it. Walking away asks once more, saying what it costs: the name
## with the faction falls, and after a sizeable advance (Standing.sizeable) the faction will
## send men after the company. Words only: the hub acts on the buttons. Taken contracts are
## shown anywhere; posted ones at the hub. Words: data/text/en.json "hub.contract*" and
## "hub.abandon.*".

## The panel actions these rows raise.
const TALK := "talk"
const ABANDON := "abandon"
const ABANDON_YES := "abandon_yes"
const ABANDON_NO := "abandon_no"


## The rows: a heading, the posted contracts (at the hub only) and the taken ones. confirm: the
## contract whose walking away is being asked about ("" for none).
static func rows(
	company: Company, world: WorldSim, at_hub: bool, confirm: String
) -> Array[Dictionary]:
	var rows: Array[Dictionary] = [HubPanel.line(HubPanel.HEADING, Text.t("hub.contracts.title"))]
	var shown := 0
	for row: Dictionary in company.economy.board:
		var params := words(company, world, row)
		var id := str(row.get("id", ""))
		if row.get("accepted") == true:
			rows.append(HubPanel.line(HubPanel.LABEL, Text.t("hub.contract.taken", params)))
			rows.append_array(_abandon_rows(company, row, id == confirm, params))
			shown += 1
		elif at_hub:
			rows.append(HubPanel.button_row(TALK, id, Text.t("hub.contract.talk", params), true))
			shown += 1
	if shown == 0:
		rows.append(HubPanel.line(HubPanel.LABEL, Text.t("hub.contracts.none")))
	return rows


## A contract in words: its job's name, the faction and the place, the pay and the deadline,
## and the advance paid on it.
static func words(company: Company, world: WorldSim, row: Dictionary) -> Dictionary:
	var book := company.economy.book
	var template := book.job_template(str(row.get("job", "")))
	return {
		"job": Text.t(str(template.get("words", "hub.job.none"))),
		"faction": book.faction_name(str(row.get("faction", ""))),
		"site": OverworldMap.site_name(world.site(str(row.get("site", "")))),
		"reward": Merc.whole(row.get("reward", 0)),
		"advance": Merc.whole(row.get("advance", 0)),
		"deadline": Merc.whole(row.get("deadline", 0)),
	}


static func _abandon_rows(
	company: Company, row: Dictionary, asking: bool, params: Dictionary
) -> Array[Dictionary]:
	var id := str(row.get("id", ""))
	if not asking:
		return [HubPanel.button_row(ABANDON, id, Text.t("hub.contract.abandon", params), true)]
	var rows: Array[Dictionary] = [
		HubPanel.line(HubPanel.LABEL, Text.t("hub.abandon.warn", params))
	]
	if company.economy.standing.sizeable(row):
		rows.append(HubPanel.line(HubPanel.LABEL, Text.t("hub.abandon.grudge", params)))
	var items: Array[Dictionary] = [
		HubPanel.button_row(ABANDON_YES, id, Text.t("hub.abandon.yes"), true),
		HubPanel.button_row(ABANDON_NO, id, Text.t("hub.abandon.no"), true),
	]
	rows.append({"kind": HubPanel.BUTTONS, "items": items})
	return rows
