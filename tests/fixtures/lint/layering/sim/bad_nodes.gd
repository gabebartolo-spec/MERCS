extends RefCounted
# Building engine nodes in sim (#5 review). The look-alikes at the top stay silent:
# RefCounted, Resource and sim-owned classes may be built; scene nodes may not.

var ok_ref: RefCounted = RefCounted.new()
var ok_res: Resource = Resource.new()
var ok_timer: CooldownTimer = CooldownTimer.new()
var ok_array: PackedInt32Array = PackedInt32Array()

var bad_timer: Variant = Timer.new()  # PLANT SIM-ENGINE
var bad_sprite: Variant = Sprite2D.new()  # PLANT SIM-ENGINE
var bad_label: Variant = Label.new()  # PLANT SIM-ENGINE
var bad_anim: Variant = AnimationPlayer.new()  # PLANT SIM-ENGINE
var bad_http: Variant = HTTPRequest.new()  # PLANT SIM-ENGINE
var bad_spaced: Variant = Timer . new()  # PLANT SIM-ENGINE
