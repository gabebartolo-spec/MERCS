extends Node
# The GameData autoload (presentation layer). One planted violation per line, PLANT <RULE>.
# Look-alikes: its own layer and everything below it is fine, and sim-only rules do not
# apply to presentation (clock, await, get_tree and friends).

const DATA: String = "res://data/balance/combat.json"
const RNG_PATH: String = "res://sim/core/Rng.gd"
const GOLDEN: String = "res://assets/golden/ref.png"
const SIBLING: String = "res://presentation/vfx/hit_spark.gd"
const FROM_UI: String = "res://ui/ui_kit.gd"  # PLANT LAYER-IMPORT
const FROM_TESTS: String = "res://tests/helpers/fixture.gd"  # PLANT LAYER-IMPORT

var _rng: Rng = null
var _spark: HitSpark = null
var _kit: UiKit = null  # PLANT LAYER-CLASS


func reload() -> void:
	var started: int = Time.get_ticks_msec()
	await get_tree().process_frame
	var back: Node = get_node("/root/Main")
	_rng = Rng.new()


func describe() -> String:
	return "GameData"


func reach_up() -> void:
	UiState.reset()  # PLANT LAYER-AUTOLOAD
