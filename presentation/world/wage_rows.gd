class_name WageRows
extends RefCounted
## The hub's wages and dues (Phase 5 C8; the rule is C3's Payroll): each merc by name with his
## level and his day's wage, and what he is owed when wages or a share stand unpaid; anyone
## owed who is no longer on the roster; and how the share of a contract's pay is split. Words
## only. Words: data/text/en.json "hub.wages.*".


## The rows. share_pct: data/balance/economy.json "wages" "share_pct".
static func rows(company: Company, share_pct: int) -> Array[Dictionary]:
	var payroll := company.economy.payroll
	var rows: Array[Dictionary] = [HubPanel.line(HubPanel.HEADING, Text.t("hub.wages.title"))]
	var listed: Array[String] = []
	for merc: Merc in company.roster:
		listed.append(merc.id)
		var params := {
			"name": company.name_of(merc.id),
			"level": merc.level(),
			"wage": payroll.day_wage(merc),
			"due": Merc.whole(payroll.dues.get(merc.id, 0)),
		}
		var key := "hub.wages.merc_owed" if params["due"] > 0 else "hub.wages.merc"
		rows.append(HubPanel.line(HubPanel.LABEL, Text.t(key, params)))
	for id: Variant in payroll.dues:
		if str(id) not in listed:
			var gone := {"name": company.name_of(str(id)), "due": payroll.dues[id]}
			rows.append(HubPanel.line(HubPanel.LABEL, Text.t("hub.wages.gone", gone)))
	rows.append(HubPanel.line(HubPanel.NOTE, Text.t("hub.wages.share", {"share_pct": share_pct})))
	return rows
