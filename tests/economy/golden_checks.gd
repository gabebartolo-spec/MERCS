extends RefCounted
## The economy suite's golden campaigns, run by tests/run_economy_tests.gd (Phase 5 C0): the
## five whole-campaign routes (campaign_kit.gd's winning route, route_kit.gd's loss, toll,
## second fight and wipe), each on two seeds, every roll on the one Rng of its seed. Each final
## save, as JSON text, hashes to a pinned SHA-256: a change meant to keep behaviour (the split
## of economy.gd into a facade and modules) must leave every hash as it is. A package that
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
}
## Pinned before the economy.gd split (claude/c0-economy-split); "route/seed" -> SHA-256 of the
## final save text.
const GOLDEN := {
	"win/424310": "b0e5255a80c3dd821a9a53aa2c4220c5b4ff5aa97a241124f2105331406e72da",
	"win/424311": "16f42f04427d73411dd49471adc36623c9abf784f6f0f2d75174eb8de3fa3f04",
	"loss/424308": "bf24e8ad4f759ec41f11f782bb6fab625ffa194275174d76859d3e5c8d67687c",
	"loss/424316": "03e981bba5f58a61e5b2609da8b7683f0edcd2751808c7bcd140c47ccd00bcd3",
	"toll/424308": "07b3f8c3aee0d23d81887b9f460df4c10f060d63b96bb96472a0b1d9b24592ad",
	"toll/424316": "6ebb4b56cf86829e401bae68b0fbdf364f02aa31168e3eaf25fe096f3fb0e9ad",
	"second_fight/424308": "cd473eb2ad14db1d9a0be0f3d8f1dd8ae8507a2db88559a062c215da01f83b85",
	"second_fight/424316": "3cb79ddecfaa680c9260df267aedfa4637ea345dd717aed97e109927d68690a4",
	"wipe/424308": "d8cca9bde2564397726057206f8f69099013637e2a0fe261c9d4550f44ed8bde",
	"wipe/424316": "902fba124f6b0e7486a73fc9c7df605cf7253634e194be2a0b440aef16690f9a",
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
		"the ten golden saves are ten different campaigns, got %d" % digests.size()
	)


## The final save of one route on one seed, as the JSON text a save file holds.
static func save_text(route: String, seed_value: int) -> String:
	if route == WIN:
		return str(Campaign.run(seed_value)["save"])
	return str(Routes.run(route, seed_value)["save"])
