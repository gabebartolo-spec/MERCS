extends Node2D
# presentation/ is scanned like ui/. One planted violation per line, marked PLANT <RULE>.

const FRAME: StringName = &"Hit Frame"
const ICON: String = "res://assets/icons/hit.png"

var _label: Label = null


func show_hit(amount: int) -> void:
	_label.text = Text.t("battle.hit", {"amount": amount})
	push_warning("Hit label missing for %d" % amount)
	_label.text = "Critical hit"  # PLANT TEXT-LITERAL
