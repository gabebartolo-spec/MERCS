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
## Each route and the two seeds it is played on (the campaign suite's, run_campaign_tests.gd).
const SEEDS := {
	"win": [424310, 424311],
	"loss": [424308, 424316],
	"toll": [424308, 424316],
	"second_fight": [424308, 424316],
	"wipe": [424308, 424316],
	"job": [424308, 424316],
}
## "route/seed" -> SHA-256 of the final save text. First pinned before the economy.gd split
## (claude/c0-economy-split). Re-pinned by Phase 5 C1 (claude/c1-jobs): every posted contract
## now carries its job type ("job", drawn on the new "jobs" stream after the board's own
## draws), so each save gains that key and a "jobs" stream position; with both stripped the
## ten saves hash exactly as C0 pinned them. C1 also added the "job" route (route_kit.gd).
const GOLDEN := {
	"win/424310": "0cc77e30757eccc8eef88da1dd93d83e01d953b5e99ad966f1f99f074a107fee",
	"win/424311": "5ab0ae4e6d572fb522927c718497d968d0aee6bd5b777b3fa7c553d48da27bbb",
	"loss/424308": "78527d9fb2aeea09260487d334b9cf12c1a433219f7ff89de46564a9ed4daf1c",
	"loss/424316": "af1863700312175c63a4eb197d4dab5555932e4e3c07518d3c8ee11bc30efac2",
	"toll/424308": "f7854fd802c0402b11b5db2308d06987f6c919bfc4131c39b4677ca6bbdfe58f",
	"toll/424316": "17feb8d953f76ef6c83866a38e3495b25339802f083bb4d238335984d1128f81",
	"second_fight/424308": "c57ddff4aa89ec36c1b5388939a071aa4a4278521b47286edbcefebc49cbc4e9",
	"second_fight/424316": "6c88fcadc3dca0e30d7f551e1060ad4b5121b17803d8485c35e499f3352c08d9",
	"wipe/424308": "c2a1651d45788bdf39496e475bd3408d4f021f5fd1c1167f75c7d4be8b8b3bcb",
	"wipe/424316": "052a22183247a44ae3feb842e7d98f0dbb0d355a1dd08c7e4e99145b4e4bde9c",
	"job/424308": "99f26c9416bf5a63df3e9643b9a12d5fc9fa3c8e67c579e51b976d6b4474c6b7",
	"job/424316": "6626317582575f2a0114faa022c3bf60aefabcd3020646ed2e853f93e4f0e84e",
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
