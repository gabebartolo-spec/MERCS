extends Control
# Engine names written as plain strings (#5 review): groups, node paths, OS names, animations.
# None of these is player text. The plants at the bottom still must fire.


func _ready() -> void:
	add_to_group("Enemy Units")
	remove_from_group("Enemy Units")
	var grouped: bool = is_in_group("Enemy Units")
	var close: Node = get_node("Panel/Close Button")
	var maybe: Node = get_node_or_null("Panel/Close Button")
	var present: bool = has_node("Panel/Close Button")
	var on_windows: bool = OS.get_name() == "Windows"
	var on_mac: bool = "macOS" == OS.get_name()
	$Anim.play("Idle")
	$Anim.play("Fall Back")
	get_node("Anim").play("Idle")
	var anim_ok: bool = $Anim.has_animation("Fall Back")
	print(grouped, close, maybe, present, on_windows, on_mac, anim_ok)
	var shown: String = "Retreat now"  # PLANT TEXT-LITERAL
	set_title("Close Button")  # PLANT TEXT-LITERAL
	var label_text: String = get_name() + " Ready"  # PLANT TEXT-LITERAL
	print(shown, label_text)
