extends RefCounted
# One planted violation per line, marked PLANT <RULE>.

var _node: Node = null  # PLANT SIM-ENGINE
var _node_2d: Node2D = null  # PLANT SIM-ENGINE
var _node_3d: Node3D = null  # PLANT SIM-ENGINE
var _control: Control = null  # PLANT SIM-ENGINE
var _tree: SceneTree = null  # PLANT SIM-ENGINE


func poke() -> void:
	var pressed: bool = Input.is_action_pressed("go")  # PLANT SIM-ENGINE
	var speed: float = Engine.time_scale  # PLANT SIM-ENGINE
	var host: String = OS.get_name()  # PLANT SIM-ENGINE
	var kid = get_node("Kid")  # PLANT SIM-ENGINE
	var tree = get_tree()  # PLANT SIM-ENGINE
	var dollar = $Sprite  # PLANT SIM-ENGINE
	var dollar_path = $"Body/Head"  # PLANT SIM-ENGINE
	var unique = %Unique  # PLANT SIM-ENGINE
	var unique_list = [%Third]  # PLANT SIM-ENGINE
	var scene = "res://sim/battle.tscn"  # PLANT SIM-ENGINE
	var packed = "res://sim/battle.scn"  # PLANT SIM-ENGINE


func unique_return():
	return %Other  # PLANT SIM-ENGINE
