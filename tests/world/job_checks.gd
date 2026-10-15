extends RefCounted
## The job checks (Phase 5 C1), run by tests/run_sim_world_tests.gd: a contract is a job.
## The board draws a job type for each contract on its own stream, leaving the contracts'
## own draws as they were; each of the four types is won and lost the way the director
## decided (Q-9); the deadline fails a job; a job's party leaves when its contract does; a job
## saved and loaded mid-play ends as the uninterrupted play does; a contract from before jobs
## is left alone. Seeded by design: tests/lib/job_kit.gd on SEED.

const JobKit := preload("res://tests/lib/job_kit.gd")
const Fixture := preload("res://tests/lib/company_fixture.gd")
const World := preload("res://tests/lib/world_fixture.gd")
const SEED := 424242
const BOARDS := 12
const SITES: Array[String] = ["site_1", "site_2", "site_3"]
const TYPES: Array[String] = ["clear_bandits", "escort", "hold", "hunt"]
const SPLIT := 4
const SHORT_DEADLINE := 2
const WAIT_DAYS := 4
## Moves enough for a company that loses every fight to reach the wide deadline.
const LONG_PLAY := 2000

var _check: Callable


## check: the runner's check(condition, expectation).
func run(check: Callable) -> void:
	_check = check
	_check_board_draws()
	for job_type: String in TYPES:
		_check_done(job_type)
	_check_lost_fights()
	_check_escort_lost_on_the_way()
	_check_deadline()
	_check_deadline_with_advance()
	_check_stray_party()
	_check_reload_continues()
	_check_old_contract()


## Every posted contract carries one of the four types; with no job data the board is the
## same contracts, roll for roll (the job is drawn after them, on "jobs").
func _check_board_draws() -> void:
	var with_jobs := Economy.make(Fixture.defs())
	var bare_defs := Fixture.defs()
	bare_defs.erase("jobs")
	var bare := Economy.make(bare_defs)
	var rng_a := Rng.from_seed(SEED)
	var rng_b := Rng.from_seed(SEED)
	var same := true
	var types := {}
	for day: int in BOARDS:
		with_jobs.refresh_board(day, SITES, rng_a)
		bare.refresh_board(day, SITES, rng_b)
		for i: int in with_jobs.board.size():
			var row: Dictionary = with_jobs.board[i].duplicate()
			types[str(row.get("job", ""))] = true
			row.erase("job")
			same = same and i < bare.board.size() and str(row) == str(bare.board[i])
	var all_four := TYPES.all(func(t: String) -> bool: return types.has(t)) and types.size() == 4
	_check.call(
		same and all_four,
		(
			"the board's contracts roll as before and each carries a job type (seen %s)"
			% [types.keys()]
		)
	)


## Taken and every fight won: done, paid the reward, off the board, its party gone, and each
## merc who fights for the company remembers it.
func _check_done(job_type: String) -> void:
	var taken := JobKit.begin(SEED, job_type, true)
	JobKit.play(taken, true)
	var left := JobKit.begin(SEED, job_type, false)
	JobKit.play(left, true, taken.world.day)
	var reward := Merc.whole(taken.contract.get("reward", 0))
	var economy := taken.company.economy
	var verdict := _verdict(taken)
	var key := Jobs.MEMORY_PREFIX + job_type + "." + Jobs.DONE
	var remembered := taken.company.fighting_order().all(
		func(id: String) -> bool: return taken.memory.has_key(id, key)
	)
	(
		_check
		. call(
			(
				verdict == Jobs.DONE
				and economy.purse == left.company.economy.purse + reward
				and economy.book.contract(str(taken.contract.get("id"))).is_empty()
				and not _job_party_on_map(taken)
				and remembered
			),
			(
				"%s taken and won is done on day %d: paid %d, off the board, its party gone, remembered (%s)"
				% [job_type, taken.world.day, reward, verdict]
			)
		)
	)


## Every fight lost: the camp and the quarry stand after the loss and the job goes on (it
## fails only at the deadline); a hold fails with the fight that comes.
func _check_lost_fights() -> void:
	var outcomes: Array[String] = []
	for job_type: String in ["clear_bandits", "hunt", "hold"]:
		var played := JobKit.begin(SEED, job_type, true)
		while played.fights.is_empty() and played.world.day <= JobKit.WIDE:
			played.move(false)
		outcomes.append("%s %s day %d" % [job_type, _verdict(played), played.world.day])
		var judged := played.verdicts.size() == 1
		var wanted := job_type == "hold"
		var standing := played.fights.size() == 1 and judged == wanted
		if job_type != "hold":
			JobKit.play(played, false, LONG_PLAY)
			standing = standing and _verdict(played) == Jobs.FAILED
			standing = standing and played.world.day > JobKit.WIDE
		_check.call(standing, "a lost fight: %s (%s)" % [job_type, outcomes.back()])


## An escort that loses a fight on the road (bandits met on the way) has failed.
func _check_escort_lost_on_the_way() -> void:
	var played := JobKit.begin(SEED, "escort", true)
	var charge := played.world.parties.duplicate()
	World.lone_party(played.world, "ambush", 3)
	played.world.parties.append_array(charge)
	JobKit.play(played, false, LONG_PLAY)
	_check.call(
		played.fights == ["ambush"] and _verdict(played) == Jobs.FAILED,
		"an escort that loses a fight on the way fails (%s, %s)" % [played.fights, _verdict(played)]
	)


## Past the deadline the job fails: its party leaves the map and nothing is paid.
func _check_deadline() -> void:
	var played := JobKit.begin(SEED, "hunt", true)
	var row := played.company.economy.book.contract(str(played.contract.get("id")))
	row["deadline"] = SHORT_DEADLINE
	var purse := played.company.economy.purse
	var faction := str(played.contract.get("faction", ""))
	var name_before := played.company.economy.standing.reputation(faction)
	var had_party := _job_party_on_map(played)
	for _day: int in WAIT_DAYS:
		played.world.rest()
	(
		_check
		. call(
			(
				had_party
				and _verdict(played) == Jobs.FAILED
				and not _job_party_on_map(played)
				and played.company.economy.purse == purse
				and played.company.economy.standing.reputation(faction) < name_before
			),
			(
				"a hunt still running past its deadline (day %d) fails: quarry gone, unpaid, name dented"
				% SHORT_DEADLINE
			)
		)
	)


## Taken with an advance, a lapsed deadline is abandonment (the board's expiry, C2), never
## also judged failed here: no verdict, no dent from the jobs, and the party leaves as a stray.
func _check_deadline_with_advance() -> void:
	var played := JobKit.begin(SEED, "hunt", true)
	var row := played.company.economy.book.contract(str(played.contract.get("id")))
	row["deadline"] = SHORT_DEADLINE
	row["advance"] = Merc.whole(row.get("reward", 0))
	var faction := str(played.contract.get("faction", ""))
	var standing := played.company.economy.standing
	var name_before := standing.reputation(faction)
	for _day: int in WAIT_DAYS:
		played.world.rest()
	_check.call(
		(
			played.verdicts.is_empty()
			and standing.reputation(faction) >= name_before - _abandon_dent()
			and played.company.economy.book.contract(str(played.contract.get("id"))).is_empty()
			and not _job_party_on_map(played)
		),
		"a hunt taken with an advance that lapses is not judged failed (no double dent), party gone"
	)


## The most one abandonment dents (data/balance/economy.json "standing"): the board's expiry
## may abandon the contract (C2), the jobs must add nothing on top.
static func _abandon_dent() -> int:
	var standing: Dictionary = Fixture.json(Fixture.ECONOMY).get("standing", {})
	return Merc.whole(standing.get("abandon_dent", 0))


## A job's contract taken off the board some other way: its party leaves on the next day.
func _check_stray_party() -> void:
	var played := JobKit.begin(SEED, "clear_bandits", true)
	var had := _job_party_on_map(played)
	played.company.economy.book.drop(str(played.contract.get("id")))
	played.world.rest()
	_check.call(
		had and not _job_party_on_map(played),
		"a camp whose contract is gone leaves the map at the next day"
	)


## Saved and loaded mid-job, the play ends in the same save as the uninterrupted one.
func _check_reload_continues() -> void:
	var whole := JobKit.begin(SEED, "hold", true)
	JobKit.play(whole, true)
	var paused := JobKit.begin(SEED, "hold", true)
	JobKit.play(paused, true, SPLIT)
	var resumed := JobKit.load_back(paused)
	JobKit.play(resumed, true)
	_check.call(
		(
			not whole.verdicts.is_empty()
			and paused.verdicts.is_empty()
			and JobKit.save_text(resumed) == JobKit.save_text(whole)
		),
		"a hold saved after %d moves and loaded ends in the uninterrupted save" % SPLIT
	)


## A contract saved before jobs (no "job") loads, is never judged, and lapses as before.
func _check_old_contract() -> void:
	var played := JobKit.begin(SEED, "hunt", false)
	var economy := played.company.economy
	var row: Dictionary = economy.board[0]
	row.erase("job")
	row["deadline"] = SHORT_DEADLINE
	var restored := Economy.restore(economy.state(), Fixture.defs())
	played.company.economy = restored
	var id := str(row.get("id"))
	var took := played.jobs.take(id)
	var parties := played.world.parties.size()
	for _day: int in WAIT_DAYS:
		played.world.rest()
	_check.call(
		(
			took
			and parties == 0
			and played.verdicts.is_empty()
			and restored.book.contract(id).is_empty()
		),
		"a contract from before jobs is taken, places nothing, is never judged and lapses"
	)


static func _verdict(played: JobKit.Played) -> String:
	return "" if played.verdicts.is_empty() else str(played.verdicts[0].get("verdict", ""))


static func _job_party_on_map(played: JobKit.Played) -> bool:
	return played.world.parties.any(
		func(party: WorldParty) -> bool: return party.id.begins_with(Jobs.PREFIX)
	)
