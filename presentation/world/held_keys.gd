class_name HeldKeys
extends RefCounted
## The walking keys held down (WASD and the arrows), as one direction: diagonals by two keys,
## each axis kept to one step so W and Up together are still one step north. The street's
## merc and the overworld's band both walk by it (SliceGame feeds it the key events).

const DIRECTION_BY_KEY := {
	KEY_W: Vector2i(0, -1),
	KEY_UP: Vector2i(0, -1),
	KEY_S: Vector2i(0, 1),
	KEY_DOWN: Vector2i(0, 1),
	KEY_A: Vector2i(-1, 0),
	KEY_LEFT: Vector2i(-1, 0),
	KEY_D: Vector2i(1, 0),
	KEY_RIGHT: Vector2i(1, 0),
}

var _held := {}


## Records a walking key's press or release. False for any other key.
func take(code: Key, pressed: bool) -> bool:
	if not DIRECTION_BY_KEY.has(code):
		return false
	_held[code] = pressed
	return true


func direction() -> Vector2i:
	var sum := Vector2i.ZERO
	for code: Variant in _held:
		if _held[code]:
			var step_dir: Vector2i = DIRECTION_BY_KEY[code]
			sum += step_dir
	return sum.clamp(-Vector2i.ONE, Vector2i.ONE)
