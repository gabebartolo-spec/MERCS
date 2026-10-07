extends SceneTree
# Prints node_classes.txt: every instantiable Node class in this engine build.


func _init() -> void:
	var names: Array[String] = []
	for name: StringName in ClassDB.get_class_list():
		if ClassDB.is_parent_class(name, &"Node") and ClassDB.can_instantiate(name):
			names.append(String(name))
	names.sort()
	var version: String = Engine.get_version_info().string
	print("# Every instantiable Node class in Godot %s, one per line." % version)
	print("# layering.py reports any of them in sim/; lines that are not a bare name are skipped.")
	print("# Regenerate after an engine upgrade:")
	print("#   godot --headless --script tools/lint/node_classes.gd > tools/lint/node_classes.txt")
	print("\n".join(names))
	quit()
