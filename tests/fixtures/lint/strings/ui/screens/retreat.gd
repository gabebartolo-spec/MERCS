extends Control
# One planted violation per line, marked PLANT <RULE>. Everything above the plants must stay silent.

const KEY_RETREAT: String = "ui.retreat"
const ACTION: StringName = &"Idle"
const SPACED_NAME: StringName = &"Fall back"
const FX_PATH: NodePath = ^"Panel/Body Text"
const SCENE: String = "res://ui/My Screens/main.tscn"
const SAVE: String = "user://Quick Save.json"
const UID: String = "uid://b8k2c1fixture"
const FORMAT_PAIR: String = "%d / %d"
const FORMAT_ONE: String = "%s"
const FORMAT_WIDE: String = "%05.1f"
const EMPTY: String = ""
const GAP: String = " "
const HASH_KEY: String = "item#1"
const GROUP_KEY: String = "retreat_button"

var keyed: String = Text.t("ui.retreat")
var keyed_text_like: String = Text.t("Retreat now")
var keyed_multiline: String = Text.t(
	"Multi Line Key"
)
var table: Dictionary = {"Title Key": 1, "full name": 2}
var multi: Dictionary = {
	"Display Name": 3,
	"plain": 4,
}
var picked: int = table["Title Key"]
var picked_spaced: int = multi["Display Name"]


func debug() -> void:
	print("Debug text here")
	printerr("Oops: something broke")
	print_rich("[b]Debug[/b] text")
	push_warning("Missing icon for Retreat")
	push_error(
		"Bad state: it broke"
	)
	assert(table.size() > 0, "Table must not be empty")


func planted() -> void:
	var bad_space: String = "Retreat from the field"  # PLANT TEXT-LITERAL
	var bad_upper: String = "Retreat"  # PLANT TEXT-LITERAL
	var bad_single: String = 'Fall back'  # PLANT TEXT-LITERAL
	var bad_escape: String = "\nBack to camp"  # PLANT TEXT-LITERAL
	var bad_format: String = "Score: %d"  # PLANT TEXT-LITERAL
	var bad_params: String = Text.t("ui.greet", {"name": "Old Sam"})  # PLANT TEXT-LITERAL
	var bad_after_hash: String = "k#" + "Pay up"  # PLANT TEXT-LITERAL
	var bad_dict_value: Dictionary = {"title": "Retreat now"}  # PLANT TEXT-LITERAL
	var bad_array: Array = ["Hold", "ground"]  # PLANT TEXT-LITERAL
	print("dbg"); var after_print: String = "Retreat now"  # PLANT TEXT-LITERAL
	var bad_triple: String = """
Multi line
player text"""
	$Button.text = "Quit to menu"  # PLANT TEXT-LITERAL
