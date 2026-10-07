extends RefCounted
## GATE TEST: id stub. Hosts gate violations 3 and 5; never merge.
class_name Ids

const UI_KIT: GDScript = preload("res://ui/ui_kit.gd")  # GATE-5 sim imports upward from ui/


func parent_of(holder: Node) -> Node:
	return holder.get_node("..")  # GATE-3 get_node in sim
