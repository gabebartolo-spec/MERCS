class_name HitSpark
extends Node2D
# Presentation script. One planted violation per line, PLANT <RULE>.
# Look-alikes: a presentation script may use sim classes, its own autoloads and the engine.

const FROM_ASSETS: String = "res://assets/golden/ref.png"
const FROM_TESTS: String = "res://tests/run_ui_tests.gd"  # PLANT LAYER-IMPORT

var _started: int = Time.get_ticks_msec()
var _info: String = GameData.describe()
var _rng: Rng = null
var _kit: UiKit = null  # PLANT LAYER-CLASS

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	await get_tree().process_frame
	var kid: Node = get_node("Kid")
	GameData.reload()
	UiState.reset()  # PLANT LAYER-AUTOLOAD
