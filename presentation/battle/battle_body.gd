class_name BattleBody
extends RefCounted
## The picture of a fallen fighter (P6b): the fighter's own frame at full size, turned flat to lie
## along a diagonal of its cell, head away from the killer. Turning is by nearest sampling, so it
## adds no colour and no blur and the body keeps the figure's pixel size (a body is never smaller
## than the man). Presentation only.

const PAIR := 2
const OPAQUE := 0.5


## The frame (already cropped to its pixels) turned clockwise by this many radians, nearest
## sampling, on a canvas just big enough to hold it.
static func turn(frame: Image, angle: float) -> Image:
	var w := frame.get_width()
	var h := frame.get_height()
	var span := ceili(absf(sin(angle)) * h + absf(cos(angle)) * w) + 1
	var tall := ceili(absf(cos(angle)) * h + absf(sin(angle)) * w) + 1
	var out := Image.create(span, tall, false, Image.FORMAT_RGBA8)
	var back := Transform2D(-angle, Vector2.ZERO)
	var from := Vector2(w, h) / PAIR
	var to := Vector2(span, tall) / PAIR
	for y: int in tall:
		for x: int in span:
			var source := back * (Vector2(x + 0.5, y + 0.5) - to) + from
			var sx := floori(source.x)
			var sy := floori(source.y)
			if sx >= 0 and sy >= 0 and sx < w and sy < h:
				out.set_pixel(x, y, frame.get_pixel(sx, sy))
	return out


## How many pixels of a picture are solid.
static func solid(image: Image) -> int:
	var n := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a >= OPAQUE:
				n += 1
	return n


## The mean place of the solid pixels, in pixels from the picture's centre: the torso.
static func torso(image: Image) -> Vector2:
	var total := Vector2.ZERO
	var n := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a >= OPAQUE:
				total += Vector2(x + 0.5, y + 0.5)
				n += 1
	if n == 0:
		return Vector2.ZERO
	return total / n - Vector2(image.get_size()) / PAIR
