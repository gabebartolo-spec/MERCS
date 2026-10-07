extends RefCounted
# One planted violation per line, marked PLANT <RULE>.
# Look-alikes: res://tools/x in a comment, allowed imports, higher-layer names as words.

const FROM_DATA: String = "res://data/balance/combat.json"
const FROM_SIM: String = "res://sim/core/Rng.gd"
const WORDS: String = "GameData and UiKit and HitSpark are only words here"

const FROM_UI: String = "res://ui/ui_kit.gd"  # PLANT LAYER-IMPORT
const FROM_PRESENTATION: String = "res://presentation/vfx/hit_spark.gd"  # PLANT LAYER-IMPORT
const FROM_TESTS: String = "res://tests/run_data_tests.gd"  # PLANT LAYER-IMPORT
const FROM_TOOLS: String = "res://tools/lint/layering.py"  # PLANT LAYER-IMPORT
const FROM_ASSETS: String = "res://assets/golden/ref.png"  # PLANT LAYER-IMPORT
const SCENE: String = "res://presentation/battle/arena.tscn"  # PLANT LAYER-IMPORT SIM-ENGINE

var _kit: UiKit = null  # PLANT LAYER-CLASS
var _spark: HitSpark = null  # PLANT LAYER-CLASS


func touch() -> void:
	GameData.reload()  # PLANT LAYER-AUTOLOAD
	UiState.reset()  # PLANT LAYER-AUTOLOAD
