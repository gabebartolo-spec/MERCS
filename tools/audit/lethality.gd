extends SceneTree
## The lethality ledger (Phase 5 C7): N seeded campaigns played by tests/lib/lethality_kit.gd
## (the company fighting the road's line-ups with MercPlay and the real triage), reported as
## named deaths per fight and per four fights against the director's target (1 named death per
## 4 fights, Q-14), enemies per fight, fights per campaign, how many were fielded and held in
## reserve, and who went down and who died, by merc. It reports; it tunes nothing: the director
## reads the number and the lead tunes injury.json / battle.json from his answer. The same
## seeds give the same report (tests/run_campaign_tests.gd checks it). Every line starts
## "LEDGER ". Tooling only.
##   godot --headless --path . --script tools/audit/lethality.gd -- [first_seed] [count] [fights]

const Lethality := preload("res://tests/lib/lethality_kit.gd")
const FIRST_SEED := 424200
const COUNT := 100
const TARGET_PER_FOUR := 1.0
## The slice fight's seeds the lead flagged (#127: the Vampyr in plate never falls there).
const SLICE_FIRST := 424200
const SLICE_LAST := 426400


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var first := args[0].to_int() if args.size() > 0 else FIRST_SEED
	var count := args[1].to_int() if args.size() > 1 else COUNT
	var fights := args[2].to_int() if args.size() > 2 else 0
	for line: String in report_lines(Lethality.ledger(first, count, fights), first, count):
		print(line)
	for line: String in slice_lines(Lethality.slice(SLICE_FIRST, SLICE_LAST)):
		print(line)
	quit(0)


## The slice fight's line: who of the company went down there, the Vampyr named.
static func slice_lines(found: Dictionary) -> Array[String]:
	var down: Dictionary = found["down"]
	var lines: Array[String] = []
	lines.append(
		(
			"LEDGER slice fight seeds %d-%d: %d fights, company won %d; the Vampyr went down in %d"
			% [SLICE_FIRST, SLICE_LAST, found["fights"], found["won"], down.get("vampyr", 0)]
		)
	)
	var ids: Array = down.keys()
	ids.sort()
	for unit_id: Variant in ids:
		lines.append("LEDGER slice fight: %s went down in %d" % [unit_id, down[unit_id]])
	return lines


## The ledger as text lines, the same for the same ledger.
static func report_lines(ledger: Dictionary, first: int, count: int) -> Array[String]:
	var total: Dictionary = ledger["total"]
	var lines: Array[String] = []
	lines.append("LEDGER seeds %d-%d (%d campaigns)" % [first, first + count - 1, count])
	lines.append(
		(
			"LEDGER fights %d, won %d, rabble fights %d, campaigns wiped out %d"
			% [total["fights"], total["won"], total["rabble_fights"], total["wiped"]]
		)
	)
	lines.append(
		(
			"LEDGER named deaths %d: %.3f per fight, %.2f per 4 fights (target %.2f per 4)"
			% [
				total["deaths"],
				total["deaths_per_fight"],
				total["deaths_per_4_fights"],
				TARGET_PER_FOUR
			]
		)
	)
	lines.append(
		(
			"LEDGER enemies per fight %.2f, fights per campaign %.2f, fielded %.2f, reserve %.2f"
			% [
				total["enemies_per_fight"],
				total["fights_per_campaign"],
				total["fielded_per_fight"],
				total["reserve_per_fight"]
			]
		)
	)
	var fought: Dictionary = ledger["fought_by"]
	var downs: Dictionary = ledger["down_by"]
	var dead: Dictionary = ledger["dead"]
	var ids: Array = fought.keys()
	ids.sort()
	for merc_id: Variant in ids:
		lines.append(
			(
				"LEDGER merc %s: fought %d, went down %d, died %d"
				% [merc_id, fought[merc_id], downs.get(merc_id, 0), dead.get(merc_id, 0)]
			)
		)
	return lines
