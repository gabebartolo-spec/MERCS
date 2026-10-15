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
## Re-pinned by Phase 5 C7 (claude/c7-road): the road's line-ups grew to 4-8 soldiers (or
## 12-16 rabble off the road) and are drawn from those the place and day allow, so every route
## that meets an encounter on the map fights a bigger band; toll (paid, no fight), job and
## loss/424316 hold.
const GOLDEN := {
	"win/424310": "4c974be15bed0c5b331ac216cfd4adda57fed910dc794338e5c242d59bd6a38c",
	"win/424311": "b24c97d1b5fcb6dec8236b705c3e40ee35b7a011ba918283bffbcb04d2c139ea",
	"loss/424308": "349aa5b355698567ed053bc0dc4f7015235a58d87465065a69110048ef2d6a0b",
	"loss/424316": "ae1491173ccf7b35563033ab048932fe88b7f9e34b0a41d32b40520df5a03e9b",
	"toll/424308": "f7854fd802c0402b11b5db2308d06987f6c919bfc4131c39b4677ca6bbdfe58f",
	"toll/424316": "17feb8d953f76ef6c83866a38e3495b25339802f083bb4d238335984d1128f81",
	"second_fight/424308": "88ed71d3c3ea8f7bb31fbeaa680ea79819e690aebf45a37ae53b8da140f1e065",
	"second_fight/424316": "17f1351e854a5ff9ff9313e70350b696d670cf5f7309a50731602d7201cfaa14",
	"wipe/424308": "90ca7d0846980e50963ffe9ae27abebcc7469312d4165bb1e858c44236990d0a",
	"wipe/424316": "166f60989c2a7aa80be42896f7b0077ca87f530cce370c067d936ca989fe7c23",
	"job/424308": "17748c59ae8ea3b7a71d4af78836d37084877417e699dfa05fcef4486130f2c1",
	"job/424316": "468e33572bdfc88f0221c974e6bac8bf834d876660fce1eefc472a410ce79f6e",
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
