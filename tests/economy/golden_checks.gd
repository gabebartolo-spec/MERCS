extends RefCounted
## The economy suite's golden campaigns, run by tests/run_economy_tests.gd (Phase 5 C0): the
## six whole-campaign routes (campaign_kit.gd's winning route, route_kit.gd's loss, toll,
## second fight, wipe and, since C1, job), each on two seeds, every roll on the one Rng of its
## seed. Each final save, as JSON text, hashes to a pinned SHA-256: a change meant to keep
## behaviour (the split of economy.gd into a facade and modules) must leave every hash
## as it is. A package that
## changes the routes on purpose re-pins the hashes it moves in the same PR, with a one-line
## reason (docs/plans/phase5_contracts.md "Shared files"); one meant to be neutral for the old
## routes adds a route and leaves these alone.
## Seeded by design: the campaign suite's seeds (tests/run_campaign_tests.gd).

const Campaign := preload("res://tests/lib/campaign_kit.gd")
const Routes := preload("res://tests/lib/route_kit.gd")
const WIN := "win"
## Each route and the two seeds it is played on (the campaign suite's until P1b).
const SEEDS := {
	"win": [424310, 424311],
	"loss": [424308, 424316],
	"toll": [424308, 424316],
	"second_fight": [424308, 424316],
	"wipe": [424308, 424316],
	"job": [424308, 424316],
}
## Pinned before the economy.gd split (claude/c0-economy-split); "route/seed" -> SHA-256 of the
## final save text.
## Re-pinned by Phase 4 P1b (equipment physics): gear moves the fights in win/424310,
## win/424311, loss/424316 and both second_fight routes; toll, wipe and loss/424308 hold.
## The win route keeps 424310/424311 (the campaign suite plays its own seed for its stages).
## Re-pinned by Phase 5 C1 (claude/c1-jobs): every posted contract now carries its job type
## ("job", drawn on the new "jobs" stream after the board's own draws), so all ten saves gain
## that key and a "jobs" stream position; with both stripped each hashes as P1b left it.
## C1 also added the "job" route (route_kit.gd).
## Re-pinned by Phase 5 C5 (claude/c5-prisoners): win/424310 only. Its fight leaves one
## surrendered man, released at the hub; the release is now remembered by the merc who reacts
## most strongly (merc_3, economy.json "prisoner" "reactions") beside the captain, so the save
## gains that one chronicle line and memory. 6e3ccee3... -> a9086cba...; the rest hold.
## Re-pinned by Phase 5 C6 (claude/c6-armoury): armour upkeep goes on the day's bill, so every
## route where the plated orc or Vampyr is on the roster when a day ticks owes more (win, toll,
## second_fight, job/424316); loot is drawn from the fallen's gear, so second_fight/424316's
## first win (only the chief's mace fell: no piece) skips the pick and its second fight's loot
## rolls move. loss and wipe (the orc and Vampyr are dead) and job/424308 (no day ticks) hold.
## Re-pinned by Phase 5 C7 (claude/c7-road): the road's line-ups grew to 4-8 soldiers (or
## 12-16 rabble off the road) and are drawn from those the place and day allow, so every route
## that meets an encounter on the map fights a bigger band (pinned on top of C5 and C6): win
## x2, loss/424308, second_fight x2 and wipe x2 move; toll (paid, no fight), job and
## loss/424316 hold.
const GOLDEN := {
	"win/424310": "88342bd38398520fe0f8f0725b1437fd9aa2ce3c6e33bc7de4d4336a9b6c5e25",
	"win/424311": "d76ebdfbcf3e6bac5c9040aa7d4d5f86b252ff40c65f7c419c1245dd9b4494f6",
	"loss/424308": "349aa5b355698567ed053bc0dc4f7015235a58d87465065a69110048ef2d6a0b",
	"loss/424316": "ae1491173ccf7b35563033ab048932fe88b7f9e34b0a41d32b40520df5a03e9b",
	"toll/424308": "6f97c63c31c7cdfb03baaa5448afd92670b8eff5ca12eddeff3aa2bdcb7a237a",
	"toll/424316": "84a0597763a649f8d644d6499dfe34a8e5e5819a63ced8ff4db6ff5af0f5c32a",
	"second_fight/424308": "845acf7afb26b34532996ef94ebb5e428f1593b041b6daf49e107b612ffafa63",
	"second_fight/424316": "c466a1db386136bffef03656530b73482079e31327e768189c4232ed86d87438",
	"wipe/424308": "90ca7d0846980e50963ffe9ae27abebcc7469312d4165bb1e858c44236990d0a",
	"wipe/424316": "166f60989c2a7aa80be42896f7b0077ca87f530cce370c067d936ca989fe7c23",
	"job/424308": "17748c59ae8ea3b7a71d4af78836d37084877417e699dfa05fcef4486130f2c1",
	"job/424316": "5173a1b21a140efe63db148bc7f21ddb990b170587ea6f374c471a22d8dda873",
}


## check: the runner's check(condition, expectation).
func run(check: Callable) -> void:
	var moved: Array[String] = []
	var digests := {}
	for route: String in SEEDS:
		for seed_value: int in SEEDS[route]:
			var key := "%s/%d" % [route, seed_value]
			var digest := save_text(route, seed_value).sha256_text()
			print("ECONOMY GOLDEN %s sha256=%s" % [key, digest])
			digests[digest] = true
			if digest != str(GOLDEN.get(key, "")):
				moved.append(key)
	check.call(
		moved.is_empty(),
		"every golden campaign route's final save hashes as pinned (moved: %s)" % [moved]
	)
	check.call(
		digests.size() == GOLDEN.size(),
		(
			"the %d golden saves are as many different campaigns, got %d"
			% [GOLDEN.size(), digests.size()]
		)
	)


## The final save of one route on one seed, as the JSON text a save file holds.
static func save_text(route: String, seed_value: int) -> String:
	if route == WIN:
		return str(Campaign.run(seed_value)["save"])
	return str(Routes.run(route, seed_value)["save"])
