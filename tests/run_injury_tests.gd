extends "res://tests/lib/runner.gd"
## Injury suite (sim/merc/: Injury, Aftermath, Chronicle, Memory, Succession; data/injuries.json,
## data/balance/injury.json): the data holds exactly one wound, one temporary and one
## permanent injury with what each needs and words in en.json; the triage thresholds cut the
## die where the balance says; the same seed gives the same triage in any id order; a
## temporary injury ends on its day, a permanent one stays and shows in stats, layer and
## role; after a fight a death is in the chronicle with its cause, writes a memory on every
## survivor and, for the captain, names a successor and one dissenting voice; a dead id
## cannot be recorded twice or restored; chronicle, memories and injuries survive a save
## (also through JSON) and an old save reads with empty ones.
## Seeded by design: Rng.from_seed(424242) and 424243
##   godot --headless --path . --script tests/run_injury_tests.gd

const Kit := preload("res://tests/lib/injury_kit.gd")
const WORLD_BALANCE := "res://data/balance/world.json"
const TEXT := "res://data/text/en.json"
const SEED := 424242
const OTHER_SEED := 424243
const DAY := Kit.DAY
const MANY := 200
## Rules that send every roll to one end of the ladder.
const ALL_DIE := {"die_sides": 100, "wound_upto": 0, "temporary_upto": 0, "permanent_upto": 0}
const ALL_PERMANENT := {
	"die_sides": 100, "wound_upto": 0, "temporary_upto": 0, "permanent_upto": 100
}


func suite_name() -> String:
	return "Injury"


func run_checks() -> void:
	_check_data()
	_check_thresholds()
	_check_triage_seeded()
	_check_ladder_effects()
	_check_permanent_effects()
	_check_apply_is_copy()
	_check_aftermath_death()
	_check_aftermath_injuries()
	_check_succession()
	_check_succession_passed_over()
	_check_mortality_final()
	_check_save_reload()
	_check_old_save_defaults()
	await process_frame


func _verify(condition: Variant, expectation: String) -> void:
	var holds: bool = condition
	check(holds, expectation)


func _check_data() -> void:
	var problems: Array[String] = []
	var text := Kit.json(TEXT)
	for kind: String in Injury.LADDER:
		var found := Kit.defs().filter(func(d: Dictionary) -> bool: return d.get("kind") == kind)
		if found.size() != 1:
			problems.append("%s: %d entries" % [kind, found.size()])
	var temporary := Injury.definition_of_kind(Kit.defs(), "temporary")
	var permanent := Injury.definition_of_kind(Kit.defs(), "permanent")
	if Injury.num(temporary, "days") < 1:
		problems.append("temporary has no days")
	for field: String in ["stat_change", "role_key", "layer_id", "name_key"]:
		if not permanent.has(field):
			problems.append("permanent lacks %s" % field)
	for def: Dictionary in Kit.defs():
		for field: String in ["name_key", "role_key"]:
			if def.has(field) and not text.has(def[field]):
				problems.append("%s: no text for %s" % [def.get("id"), def[field]])
	for key: String in [Memory.KEY_COMRADE_DIED, Memory.KEY_CAPTAIN_DIED, Memory.KEY_DISSENT]:
		if not text.has(key):
			problems.append("no text for %s" % key)
	_verify(
		problems.is_empty(), "one wound, one temporary, one permanent injury, worded: %s" % problems
	)


func _check_thresholds() -> void:
	var rules: Dictionary = Kit.rules().get("triage", {})
	var cuts := {
		"wound_upto": "wound", "temporary_upto": "temporary", "permanent_upto": "permanent"
	}
	var wrong: Array[String] = []
	for key: String in cuts:
		var edge := Injury.num(rules, key)
		if Injury.outcome_for_roll(edge, rules) != cuts[key]:
			wrong.append("%d should be %s" % [edge, cuts[key]])
		var past := Injury.outcome_for_roll(edge + 1, rules)
		if past == cuts[key]:
			wrong.append("%d should be past %s" % [edge + 1, cuts[key]])
	var top := Injury.num(rules, "die_sides")
	if Injury.outcome_for_roll(top, rules) != Injury.OUTCOME_DEAD:
		wrong.append("the top of the die should be death")
	_verify(wrong.is_empty(), "the triage thresholds cut the die as the balance says: %s" % wrong)


func _check_triage_seeded() -> void:
	var rules: Dictionary = Kit.rules().get("triage", {})
	var ids: Array = []
	for index: int in MANY:
		ids.append("m_%03d" % index)
	var backwards := ids.duplicate()
	backwards.reverse()
	var first := Injury.triage(ids, Rng.from_seed(SEED), rules)
	var again := Injury.triage(backwards, Rng.from_seed(SEED), rules)
	var other := Injury.triage(ids, Rng.from_seed(OTHER_SEED), rules)
	var seen := {}
	for merc_id: Variant in first:
		seen[first[merc_id]] = true
	_verify(
		first == again and first.keys() == again.keys(), "same seed, same triage, in any id order"
	)
	_verify(first != other, "another seed gives another triage")
	_verify(
		seen.size() == Injury.LADDER.size() + 1,
		"a company of %d meets every outcome: %s" % [MANY, seen.keys()]
	)


func _check_ladder_effects() -> void:
	var defs := Kit.defs()
	var merc := Kit.merc("m_a", 3)
	var broken := Injury.apply(merc, "inj_broken_arm", DAY, defs)
	var temporary := Injury.definition_of_kind(defs, "temporary")
	var last_day := DAY + Injury.num(temporary, "days")
	var hurt := Injury.effective_stats(broken, DAY, defs)
	var healed := Injury.effective_stats(Injury.expire(broken, last_day), last_day, defs)
	_verify(
		Injury.num(hurt, "attack") < 5 and Injury.num(healed, "attack") == 5,
		"a temporary injury lowers the stat for its days and then it is back"
	)
	_verify(
		Injury.effective_stats(broken, last_day, defs) == healed,
		"a temporary injury is out of force on its last day even before expire()"
	)
	var wound := Injury.apply(merc, "inj_gash", DAY, defs)
	_verify(
		(
			Injury.effective_stats(wound, DAY, defs) == merc["stats"]
			and Injury.records(Injury.expire(wound, DAY)).is_empty()
		),
		"a wound costs nothing and has healed by the end of its day"
	)


func _check_permanent_effects() -> void:
	var defs := Kit.defs()
	var merc := Kit.merc("m_a", 3)
	var wound := Injury.apply(merc, "inj_gash", DAY, defs)
	var eyeless := Injury.apply(merc, "inj_lost_eye", DAY, defs)
	var later := Injury.expire(eyeless, DAY * MANY)
	var permanent := Injury.definition_of_kind(defs, "permanent")
	var change: Dictionary = permanent.get("stat_change", {})
	_verify(
		(
			Injury.effective_stats(later, DAY * MANY, defs).get("attack")
			== 5 + Injury.num(change, "attack")
		),
		"a permanent injury changes the stat for good"
	)
	_verify(
		(
			Injury.layers(later, defs) == [permanent["layer_id"]]
			and Injury.role_keys(later, defs) == [permanent["role_key"]]
		),
		"a permanent injury gives its sprite layer and its role change; a healthy merc gives none"
	)
	_verify(
		Injury.layers(merc, defs).is_empty() and Injury.role_keys(wound, defs).is_empty(),
		"no layer or role for a wound or none"
	)


func _check_apply_is_copy() -> void:
	var merc := Kit.merc("m_a", 3)
	var hurt := Injury.apply(merc, "inj_lost_eye", DAY, Kit.defs())
	var unknown := Injury.apply(merc, "inj_nothing", DAY, Kit.defs())
	_verify(
		Injury.records(merc).is_empty() and Injury.records(hurt).size() == 1 and unknown == merc,
		"apply returns a changed copy; the original and an unknown injury id are untouched"
	)


func _check_aftermath_death() -> void:
	var mercs := Kit.company()
	var aftermath := Kit.aftermath(SEED, ALL_DIE)
	var events := aftermath.resolve(Kit.battle_log(["m_c", "bandit_1"], "bandit_1"), mercs)
	var dead := aftermath.chronicle.entries
	_verify(
		(
			events.size() == 1
			and events[0]["type"] == "death"
			and not mercs.has("m_c")
			and mercs.size() == 3
		),
		"a downed company merc is resolved; an enemy in the log is not; the dead leave the roster"
	)
	_verify(
		dead.size() == 1 and dead[0] == {"merc": "m_c", "day": DAY, "cause": "bandit_1"},
		"the chronicle has the death with its day and cause: %s" % [dead]
	)
	var every_survivor := true
	for merc_id: String in ["m_a", "m_b", "m_d"]:
		var memories := aftermath.memory.of(merc_id)
		every_survivor = (
			every_survivor
			and memories.size() == 1
			and memories[0]["about"] == "m_c"
			and memories[0]["key"] == Memory.KEY_COMRADE_DIED
		)
	_verify(
		every_survivor and aftermath.memory.of("m_c").is_empty(),
		"a death writes one memory sentence on each surviving comrade"
	)
	var again := Kit.aftermath(SEED, ALL_DIE)
	var repeat := again.resolve(Kit.battle_log(["m_c"], "bandit_1"), Kit.company())
	_verify(repeat == events, "same seed and log, same aftermath events")


func _check_aftermath_injuries() -> void:
	var mercs := Kit.company()
	var aftermath := Kit.aftermath(SEED, ALL_PERMANENT)
	var events := aftermath.resolve(Kit.battle_log(["m_b", "m_a"], "bandit_1"), mercs)
	var injury_ids := events.map(func(e: Dictionary) -> String: return str(e["injury"]))
	_verify(
		(
			events.map(func(e: Dictionary) -> String: return str(e["merc"])) == ["m_a", "m_b"]
			and injury_ids == ["inj_lost_eye", "inj_lost_eye"]
		),
		"triage events come in id order and name the injury of the outcome"
	)
	_verify(
		(
			Injury.layers(Kit.state_of(mercs, "m_a"), Kit.defs()).size() == 1
			and Injury.layers(Kit.state_of(mercs, "m_c"), Kit.defs()).is_empty()
			and aftermath.chronicle.entries.is_empty()
		),
		"a permanent outcome marks the merc, not the others, and nobody died"
	)


func _check_succession() -> void:
	var mercs := Kit.company()
	var aftermath := Kit.aftermath(SEED, ALL_DIE)
	aftermath.captain_id = "m_b"
	var events := aftermath.resolve(Kit.battle_log(["m_b"], "bandit_1"), mercs)
	var rules: Dictionary = Kit.rules().get("succession", {})
	_verify(
		(
			events.size() == 2
			and (
				events[1]
				== {
					"type": "succession",
					"dead": "m_b",
					"day": DAY,
					"captain": "m_c",
					"dissent": "m_d"
				}
			)
			and aftermath.captain_id == "m_c"
		),
		(
			"the captain's death names the highest resolve (tie by id) and one dissenting runner-up: %s"
			% [events]
		)
	)
	var dissent := aftermath.memory.of("m_d")
	_verify(
		(
			dissent.size() == 2
			and dissent[0]["key"] == Memory.KEY_CAPTAIN_DIED
			and dissent[1]["key"] == Memory.KEY_DISSENT
		),
		"the dissenting voice remembers the dissent as well as the death"
	)


func _check_succession_passed_over() -> void:
	var rules: Dictionary = Kit.rules().get("succession", {})
	var other := Kit.aftermath(SEED, ALL_DIE)
	other.captain_id = "m_b"
	var both := other.resolve(Kit.battle_log(["m_b", "m_c"], "bandit_1"), Kit.company())
	_verify(
		(
			other.captain_id == "m_d"
			and both.back()["captain"] == "m_d"
			and both.back()["dissent"] == "m_a"
		),
		"a successor who also fell in the fight is passed over"
	)
	var quiet := Kit.aftermath(SEED, ALL_DIE)
	quiet.captain_id = "m_b"
	_verify(
		(
			quiet.resolve(Kit.battle_log(["m_a"], "bandit_1"), Kit.company()).size() == 1
			and quiet.captain_id == "m_b"
			and Succession.after_death("m_b", "m_b", [], rules, DAY)["captain"] == ""
		),
		"a comrade's death names no successor; a captain with nobody left names none"
	)


func _check_mortality_final() -> void:
	var chronicle := Chronicle.new()
	var first := chronicle.record_death("m_a", DAY, "bandit_1")
	var second := chronicle.record_death("m_a", DAY + 1, "fever")
	_verify(
		(
			first
			and not second
			and chronicle.entries.size() == 1
			and chronicle.entries[0]["cause"] == "bandit_1"
			and not chronicle.record_death("", DAY, "x")
		),
		"a death is recorded once and never rewritten; an empty id is refused"
	)
	var roster := {"m_a": [{"id": "inj_lost_eye"}], "m_b": [{"id": "inj_lost_eye"}]}
	var restored := Injury.restore(roster, chronicle)
	_verify(
		(
			not restored.has("m_a")
			and restored.has("m_b")
			and chronicle.living(["m_a", "m_b"]) == ["m_b"]
		),
		"restore refuses to bring a dead id back: its injuries and its place in the roster are dropped"
	)
	var saved := Chronicle.restore(
		{
			"entries":
			[{"merc": "m_a", "day": 1, "cause": "x"}, {"merc": "m_a", "day": 2, "cause": "y"}]
		}
	)
	_verify(
		saved.entries.size() == 1 and saved.entries[0]["cause"] == "x",
		"a save that repeats a death restores it once, as first written"
	)


func _check_save_reload() -> void:
	var mercs := Kit.company()
	var aftermath := Kit.aftermath(SEED, ALL_DIE)
	aftermath.captain_id = "m_b"
	aftermath.resolve(Kit.battle_log(["m_b"], "bandit_1"), mercs)
	var first: Dictionary = mercs["m_a"]
	mercs["m_a"] = Injury.apply(first, "inj_lost_eye", DAY, Kit.defs())
	var world_balance := Kit.json(WORLD_BALANCE)
	var world := WorldSim.new()
	var rng := Rng.from_seed(SEED)
	world.start(world_balance, rng)
	var text := JSON.stringify(SaveModel.to_dict(world, rng, null, aftermath.state(mercs)))
	var through_json: Dictionary = JSON.parse_string(text)
	var model := SaveModel.from_dict(through_json, world_balance)
	var back := Aftermath.restore(model.wounds, Rng.from_seed(SEED), Kit.rules(), Kit.defs())
	_verify(
		(
			model.ok
			and back.chronicle.entries == aftermath.chronicle.entries
			and back.chronicle.is_dead("m_b")
		),
		"the chronicle survives a save and reload (through JSON)"
	)
	_verify(
		(
			back.memory.of("m_a") == aftermath.memory.of("m_a")
			and back.memory.of("m_d").size() == 2
			and back.captain_id == "m_c"
		),
		"the comrades' memories and the new captain survive a save and reload"
	)
	var survivor := {"injuries": back.injuries["m_a"]}
	_verify(
		Injury.layers(survivor, Kit.defs()) == ["injury_lost_eye"] and not back.injuries.has("m_b"),
		"a permanent injury survives a save and reload"
	)


func _check_old_save_defaults() -> void:
	var world_balance := Kit.json(WORLD_BALANCE)
	var world := WorldSim.new()
	var rng := Rng.from_seed(SEED)
	world.start(world_balance, rng)
	var old_save := SaveModel.to_dict(world, rng)
	old_save.erase("wounds")
	var old := SaveModel.from_dict(old_save, world_balance)
	var empty := Aftermath.restore(old.wounds, Rng.from_seed(SEED), Kit.rules(), Kit.defs())
	_verify(
		(
			old.ok
			and empty.chronicle.entries.is_empty()
			and empty.memory.of("m_a").is_empty()
			and empty.injuries.is_empty()
			and empty.captain_id == ""
		),
		"a save from before wounds loads with an empty chronicle, memories and injuries"
	)
