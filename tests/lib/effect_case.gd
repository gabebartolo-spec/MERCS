extends RefCounted
## One player-effect case (04_GUARDRAILS.md A1): the same seed with a system on and off must
## give a visibly different outcome. A case lives in tests/effect/<system_id>.gd, extends this
## file, names its system in id() and returns {"on": <outcome>, "off": <outcome>} from run();
## tests/run_effect_tests.gd loads every case, prints "EFFECT <id>: <on> vs <off>" and fails
## a case whose two outcomes read the same.


func id() -> String:
	return ""


func run() -> Dictionary:
	return {}


static func json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
