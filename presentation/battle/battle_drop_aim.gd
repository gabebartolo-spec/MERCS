class_name BattleDropAim
extends RefCounted
## Where a blow's blood leaves the struck figure and which way it goes, as the camera sees it
## (P6c, lead QC round 1). Figures are camera-facing frames, so the drops fly in the figure's own
## picture plane: they leave the hit point at torso height (a share of the figure's drawn height,
## measured from its own opaque pixels, not assumed), burst out along the blow as it shows on
## screen, and rise against the screen's up. While a drop is over the figure's picture it is drawn
## just behind the figure's plane, so the figure's pixels hide it and blood never paints over the
## body; it shows only beyond the silhouette's edge. Presentation only; geometry, no randomness.


## The struck figure as the camera sees it: {feet (world), depth (metres along the view), rect
## (its opaque pixels on the logical screen), start (the world point at the hit's torso height),
## right and up (the screen's axes in world), pixel_m (one of its texels in metres)}.
static func figure(stage: StreetStage, sprite: Sprite3D, torso_share: float) -> Dictionary:
	var camera := stage.camera()
	var basis := camera.global_transform.basis
	var feet := sprite.global_position
	var at := camera.unproject_position(feet)
	var used := _used_rect(sprite)
	var tall := sprite.region_rect.size.y
	var corner := at + Vector2(sprite.offset.x, -(sprite.offset.y + tall))
	var rect := Rect2(corner + Vector2(used.position), Vector2(used.size))
	var torso := Vector2(rect.get_center().x, lerpf(rect.end.y, rect.position.y, torso_share))
	var step := sprite.pixel_size
	var start := feet + basis.x * (torso.x - at.x) * step + basis.y * (at.y - torso.y) * step
	return {
		"feet": feet,
		"depth": depth(camera, feet),
		"rect": rect,
		"start": start,
		"right": basis.x,
		"up": basis.y,
		"pixel_m": step,
	}


## The blow's direction as it shows on screen, as a world vector in the figure's picture plane
## (unit length; zero with no blow). blow is the ground step from the attacker to the target.
static func out_along(stage: StreetStage, shape: Dictionary, blow: Vector3) -> Vector3:
	if blow == Vector3.ZERO:
		return Vector3.ZERO
	var camera := stage.camera()
	var feet: Vector3 = shape["feet"]
	var screen := camera.unproject_position(feet + blow) - camera.unproject_position(feet)
	if screen.is_zero_approx():
		return Vector3.ZERO
	var right: Vector3 = shape["right"]
	var up: Vector3 = shape["up"]
	var flat := screen.normalized()
	return (right * flat.x - up * flat.y).normalized()


## A point's distance in front of the camera, along its view.
static func depth(camera: Camera3D, point: Vector3) -> float:
	return (point - camera.global_position).dot(-camera.global_transform.basis.z)


## Where to draw a drop whose path is at this point: the same spot on screen, but no nearer the
## camera than behind_m past the figure's plane while it is over the figure's picture (grown by
## the drop's size), so the figure hides it there.
static func drawn_at(stage: StreetStage, shape: Dictionary, point: Vector3, grow: float) -> Vector3:
	var camera := stage.camera()
	var rect: Rect2 = shape["rect"]
	if not rect.grow(grow).has_point(camera.unproject_position(point)):
		return point
	var floor_depth: float = shape["depth"] + shape["behind_m"]
	var now := depth(camera, point)
	if now >= floor_depth:
		return point
	var eye := camera.global_position
	return eye + (point - eye) * (floor_depth / now) if now > 0.0 else point


## The opaque pixels of the sprite's frame, in region texels (y down).
static func _used_rect(sprite: Sprite3D) -> Rect2i:
	var full := Rect2i(Vector2i.ZERO, Vector2i(sprite.region_rect.size))
	var material := sprite.material_override as ShaderMaterial
	if material == null:
		return full
	var texture: Texture2D = material.get_shader_parameter(&"albedo_texture")
	if texture == null:
		return full
	var sheet := texture.get_image()
	if sheet == null or sheet.is_empty():
		return full
	var used := sheet.get_region(Rect2i(sprite.region_rect)).get_used_rect()
	return full if used.size == Vector2i.ZERO else used
