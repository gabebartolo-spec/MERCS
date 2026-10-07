class_name UiKit
extends RefCounted
# The ui layer is the top one: it may use every layer below it. PLANT <RULE> marks violations.

const SPARK: String = "res://presentation/vfx/hit_spark.gd"
const RNG_PATH: String = "res://sim/core/Rng.gd"
const DATA: String = "res://data/balance/combat.json"
const GOLDEN: String = "res://assets/golden/ref.png"
const SIBLING: String = "res://ui/ui_state.gd"
const TOOLS: String = "res://tools/pipeline/pack.py"  # PLANT LAYER-IMPORT
const ADDON: String = "res://addons/plugin/plugin.gd"  # PLANT LAYER-IMPORT

var _spark: HitSpark = null
var _rng: Rng = null


func ping() -> void:
	GameData.reload()
	UiState.reset()
