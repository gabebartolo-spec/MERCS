extends RefCounted
## What the battle view suite measures in a splat's picture (colours used, solid pixels, mean
## brightness, the smallest 4-connected clump).


## How many different colours a splat uses, or -1 if one is off the ramp or see-through.
static func tones(image: Image, allowed: Array[Color]) -> int:
	var tones := {}
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a == 0.0:
				continue
			if c.a != 1.0 or not allowed.has(c):
				return -1
			tones[c.to_html()] = true
	return tones.size()


static func solid(image: Image) -> int:
	var n := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				n += 1
	return n


static func lum(image: Image) -> float:
	var total := 0.0
	var n := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a > 0.0:
				total += c.get_luminance()
				n += 1
	return total / maxf(1.0, float(n))


## The size of the smallest 4-connected clump of solid pixels.
static func smallest_clump(image: Image) -> int:
	var seen := {}
	var smallest := image.get_width() * image.get_height()
	for y: int in image.get_height():
		for x: int in image.get_width():
			var start := Vector2i(x, y)
			if image.get_pixelv(start).a > 0.0 and not seen.has(start):
				smallest = mini(smallest, clump(image, start, seen))
	return smallest


static func clump(image: Image, start: Vector2i, seen: Dictionary) -> int:
	var size := 0
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	var bounds := Rect2i(Vector2i.ZERO, image.get_size())
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		size += 1
		for step: Vector2i in BattleSplat.NEIGHBOURS:
			var next := cell + step
			if bounds.has_point(next) and image.get_pixelv(next).a > 0.0 and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return size


## One ground texel (across and down the depth) and one figure texel cover the same screen
## distance at this mark: there is one pixel scale on screen.
static func same_pixels(camera: Camera3D, node: Sprite3D, tolerance: float) -> bool:
	var at := node.global_position
	var origin := camera.unproject_position(at)
	var texel := node.pixel_size
	var wide := absf(camera.unproject_position(at + Vector3(texel, 0.0, 0.0)).x - origin.x)
	var deep := absf(
		camera.unproject_position(at + Vector3(0.0, 0.0, texel * node.scale.z)).y - origin.y
	)
	var basis := camera.global_transform.basis
	var tall := absf(camera.unproject_position(at + basis.y * texel).y - origin.y)
	var wide_figure := absf(camera.unproject_position(at + basis.x * texel).x - origin.x)
	return (
		absf(wide - wide_figure) <= tolerance * wide_figure
		and absf(deep - tall) <= tolerance * tall
	)


## How many base rings are showing on the street.
static func rings_shown(world: Node) -> int:
	var rings := 0
	for node: Node in world.get_children():
		var ring := node as MeshInstance3D
		if ring != null and ring.mesh is CylinderMesh and ring.visible:
			rings += 1
	return rings
