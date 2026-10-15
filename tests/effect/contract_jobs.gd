extends "res://tests/lib/effect_case.gd"
## contract_jobs (Phase 5 C1): a contract is a job. Seed 424242, the first contract made each
## of the four job types and taken, against the same contract left on the board, the same
## greedy play (tests/lib/job_kit.gd, every fight won): taken, the job's party appears on the
## map, a fight is raised at the place (all but the escort, whose charge walks with the band)
## and the purse ends richer by the reward; left, nothing appears and the purse is short.

const JobKit := preload("res://tests/lib/job_kit.gd")
const SEED := 424242
const TYPES: Array[String] = ["clear_bandits", "escort", "hold", "hunt"]


func id() -> String:
	return "contract_jobs"


func run() -> Dictionary:
	return {"on": _plays(true), "off": _plays(false)}


func _plays(taken: bool) -> String:
	var lines: Array[String] = []
	for job_type: String in TYPES:
		var played := JobKit.begin(SEED, job_type, taken)
		JobKit.play(played, true)
		lines.append(
			(
				"%s: parties %s, fights %s, purse %d"
				% [job_type, played.seen, played.fights, played.company.economy.purse]
			)
		)
	return "; ".join(lines)
