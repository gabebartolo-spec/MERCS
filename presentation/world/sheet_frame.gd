class_name SheetFrame
extends RefCounted
## One frame of a factory sprite sheet (tools/pipeline, schema mercs.sheet/1): the sheet
## texture, the frame's region in it, and the pivot (the feet centre, x from the left,
## y from the top of the frame). Presentation only; the Phase 1 street stage uses it to
## show factory output, or a placeholder capsule, before a full sheet loader exists.
##
## A frame may carry a normal map (manifest "normal_image": same size as the sheet,
## camera-facing tangent space, OpenGL convention: red = screen right, green = screen
## up, blue = toward the camera, encoded n × 0.5 + 0.5). With one, lit_material() lets
## Godot lights (torch, moon, lightning) light the sprite instead of a flat tint.

const HALF := 2.0
const ALPHA_SCISSOR := 0.5
const MATTE_ROUGHNESS := 1.0
const NO_SPECULAR := 0.0

var texture: ImageTexture = null
var region := Rect2()
var pivot := Vector2.ZERO
var normal: ImageTexture = null


## The frame for a facing, or null for an unknown facing or a sheet that does not load.
static func from_manifest(manifest_path: String, facing: String) -> SheetFrame:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		return null
	var manifest: Dictionary = parsed
	var found := _find_region(manifest, facing)
	if not found.has_area():
		return null
	var image_name := str(manifest.get("image", ""))
	var image_path := manifest_path.get_base_dir().path_join(image_name)
	var image := Image.load_from_file(ProjectSettings.globalize_path(image_path))
	if image == null or image.is_empty():
		return null
	var pivot_value: Variant = manifest.get("pivot", {})
	var pivot_block: Dictionary = pivot_value if pivot_value is Dictionary else {}
	var frame := SheetFrame.new()
	frame.texture = ImageTexture.create_from_image(image)
	frame.region = found
	frame.pivot = Vector2(_num(pivot_block, "x"), _num(pivot_block, "y"))
	var normal_name := str(manifest.get("normal_image", ""))
	if not normal_name.is_empty():
		var normal_path := manifest_path.get_base_dir().path_join(normal_name)
		var normal_image := Image.load_from_file(ProjectSettings.globalize_path(normal_path))
		if normal_image == null or normal_image.get_size() != image.get_size():
			return null
		frame.normal = ImageTexture.create_from_image(normal_image)
	return frame


## A shaded material for this frame's sprite (needs a normal map): nearest texels, alpha
## scissor, camera-facing billboard keeping the sprite's scale, matte with no specular glint.
func lit_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.normal_enabled = true
	material.normal_texture = normal
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = ALPHA_SCISSOR
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.roughness = MATTE_ROUGHNESS
	material.metallic_specular = NO_SPECULAR
	return material


## A solid capsule with a 1-px outline on a transparent field, pivot at its bottom
## centre, and (with_normals) a rounded normal map; deterministic.
static func capsule(
	width: int, height: int, fill: Color, outline: Color, with_normals := false
) -> SheetFrame:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var radius := width / HALF
	var centre_x := radius - 1.0 / HALF
	for y: int in height:
		for x: int in width:
			var axis_y: float = clampf(y, radius, height - radius)
			var distance := Vector2(x - centre_x, y - axis_y).length()
			if distance <= radius - 1.0 - 1.0 / HALF:
				image.set_pixel(x, y, fill)
			elif distance <= radius - 1.0 / HALF:
				image.set_pixel(x, y, outline)
	var frame := SheetFrame.new()
	frame.texture = ImageTexture.create_from_image(image)
	frame.region = Rect2(0.0, 0.0, width, height)
	frame.pivot = Vector2(width / HALF, height)
	if with_normals:
		frame.normal = ImageTexture.create_from_image(_capsule_normals(width, height))
	return frame


## Normals of a rounded capsule: a hemisphere across the width, encoded n × 0.5 + 0.5
## with green up; outside the capsule the normal faces the camera.
static func _capsule_normals(width: int, height: int) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var radius := width / HALF
	var centre_x := radius - 1.0 / HALF
	for y: int in height:
		for x: int in width:
			var axis_y: float = clampf(y, radius, height - radius)
			var v := Vector2(x - centre_x, y - axis_y) / radius
			var n := Vector3(v.x, -v.y, sqrt(maxf(0.0, 1.0 - v.length_squared())))
			n = n.normalized() if v.length_squared() < 1.0 else Vector3.BACK
			var c := n * (1.0 / HALF) + Vector3.ONE * (1.0 / HALF)
			image.set_pixel(x, y, Color(c.x, c.y, c.z))
	return image


static func _find_region(manifest: Dictionary, facing: String) -> Rect2:
	var frames: Variant = manifest.get("frames", [])
	if not frames is Array:
		return Rect2()
	var list: Array = frames
	for entry: Variant in list:
		if entry is Dictionary:
			var frame: Dictionary = entry
			if frame.get("facing", "") == facing:
				return Rect2(_num(frame, "x"), _num(frame, "y"), _num(frame, "w"), _num(frame, "h"))
	return Rect2()


static func _num(block: Dictionary, key: String) -> float:
	var value: Variant = block.get(key, 0.0)
	if value is float or value is int:
		return value
	return 0.0
