extends RefCounted
# Inner classes: the first three are fine, the rest are planted (PLANT <RULE>).

class GoodSim extends Rng:
	pass


class GoodInner extends GoodSim:
	pass


class GoodPath extends "res://sim/core/Rng.gd":
	pass


class GoodPlain:
	pass


class BadNode extends Node:  # PLANT SIM-EXTENDS
	pass


class BadResource extends Resource:  # PLANT SIM-EXTENDS
	pass


class BadObject extends Object:  # PLANT SIM-EXTENDS
	pass


class BadPath extends "res://presentation/autoload/game_data.gd":  # PLANT SIM-EXTENDS LAYER-IMPORT
	pass


class BadUi extends UiKit:  # PLANT SIM-EXTENDS LAYER-CLASS
	pass
