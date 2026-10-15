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
## Re-pinned by the playable-baseline tune (claude/baseline-tune, data only): the purse starts at
## 144 (was 80) and the board posts 2-3 contracts every 4 days paying 35-70 (was 1-3 every 5,
## 20-50), so every route's final save carries a different purse and board: all twelve move.
const GOLDEN := {
	"win/424310": "1862cccad79ece03d31e01cf5efead9eff2b030e90e0391a70f30419add331a0",
	"win/424311": "955b237c63a7292600ddb1e2c481a80ed760e75c9b22f5d7cb4f1f6238471b7a",
	"loss/424308": "9d283afd39b12dea6c4a2ae61af8c081a8edd91f28f1288807b26344a8105166",
	"loss/424316": "ff4d763d5a65b2474ac86798fc9349fe361f3eeeda65bba4c47cb68a77ec5a93",
	"toll/424308": "d43213f3c6d39f8964dea8448c361feaf432b1c9689e37fc26e7672c5cafa84d",
	"toll/424316": "e149b0330c073f796698ccdad2152c0ad265b386208ac7ab4c18edce652b94f5",
	"second_fight/424308": "b3f2d73dba751fedd1c688e579731597bc99bac33727b21602bb700bfcd6410c",
	"second_fight/424316": "ca86d6ef4abef740c44ba0dfeb56e75b30b82523648fe7ef7bcca817f8ce328a",
	"wipe/424308": "58daa09245b7a00e5e76e8f6eb220b60a76bceaf7c86e5cdab2bd83e775e9fe6",
	"wipe/424316": "3434731c56031ab5f55e4dc39ae35bb76ee8ebdad0a4ae9adf1195ef2a126e11",
	"job/424308": "c6945a1f65b4411465c2b07e534c01cbbf10a4a5291073042157a8c3bf1e2e04",
	"job/424316": "a91c36382dd1c45b84a5a9a2614750aa955a314c7d476202433d076e1fd57b49",
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
