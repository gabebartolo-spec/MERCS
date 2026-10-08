extends "res://tests/run_stage_tests.gd"
## Stage light suite: lit sprites. A frame with a normal map (mercs.sheet/1
## "normal_image", or the capsule's generated one) is drawn with a shaded material so the
## scene's lights light it; without one, or with lit_sprites off, it stays unshaded and
## takes the night tint. The capsule's normal map faces the camera at its centre, right
## at its right edge and up at its top (OpenGL convention).
## Seeded by design: no randomness; generated images are deterministic.
##   godot --headless --path . --script tests/run_stage_light_tests.gd

const GOOD_SHEET := "res://tests/fixtures/pipeline/sheets/good/average_m_body_rest.json"
const LIT_DIR := "user://stage_light"
const NORMAL_TOLERANCE := 0.05
const FLAT_NORMAL := Color(0.5, 0.5, 1.0)


func suite_name() -> String:
	return "Stage light"


func run_checks() -> void:
	_stage_data = _load_stage_data()
	await _check_lit_capsule()
	await _check_unlit()
	await _check_lit_sheet()


func _spawn_lit(lit: bool, night: bool) -> StreetStage:
	var packed: PackedScene = load(STAGE_SCENE) as PackedScene
	var stage: StreetStage = packed.instantiate() as StreetStage
	stage.lit_sprites = lit
	stage.auto_walk = false
	if night:
		stage.lighting = StreetStage.Lighting.RAIN_NIGHT
	root.add_child(stage)
	await process_frame
	return stage


func _check_lit_capsule() -> void:
	var stage: StreetStage = await _spawn_lit(true, true)
	var material := stage.merc().material_override as StandardMaterial3D
	check(
		(
			material != null
			and material.normal_enabled
			and material.normal_texture != null
			and material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED
			and material.billboard_mode == BaseMaterial3D.BILLBOARD_FIXED_Y
			and material.billboard_keep_scale
			and material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST
			and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		),
		"a lit capsule draws with a shaded, normal-mapped, nearest, Y-billboard material"
	)
	check(
		stage.merc().modulate == Color.WHITE,
		"a lit sprite at night is not tinted: the scene's lights darken it"
	)
	if material != null and material.normal_texture != null:
		_check_capsule_normals(material.normal_texture.get_image())
	else:
		check(false, "the capsule normal map faces camera, right and up where it should")
	await _despawn(stage)


func _check_capsule_normals(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var centre := image.get_pixel(w / 2, h / 2)
	var right := image.get_pixel(w - 2, h / 2)
	var top := image.get_pixel(w / 2, 1)
	check(
		(
			absf(centre.r - FLAT_NORMAL.r) < NORMAL_TOLERANCE
			and absf(centre.b - FLAT_NORMAL.b) < NORMAL_TOLERANCE
			and right.r > FLAT_NORMAL.r + NORMAL_TOLERANCE
			and top.g > FLAT_NORMAL.g + NORMAL_TOLERANCE
		),
		(
			"the capsule normal map faces camera, right and up where it should: centre %s, right %s, top %s"
			% [centre, right, top]
		)
	)


func _check_unlit() -> void:
	var stage: StreetStage = await _spawn_lit(false, true)
	check(
		stage.merc().material_override == null and not stage.merc().shaded,
		"with lit_sprites off the sprite is unshaded with no material override"
	)
	check(stage.merc().modulate != Color.WHITE, "an unlit sprite at night takes the night tint")
	await _despawn(stage)


## Writes copies of the good sheet's manifest into user://: one naming a flat normal map, one
## naming a missing file, and one with no normal_image (the good sheet itself ships one), then
## loads all three.
func _check_lit_sheet() -> void:
	var lit_manifest := _write_lit_sheet("lit.json", "flat_normal.png")
	var broken_manifest := _write_lit_sheet("broken.json", "missing_normal.png")
	var stage: StreetStage = await _spawn_lit(true, false)
	var shown := stage.use_sheet(lit_manifest, "S")
	var material := stage.merc().material_override as StandardMaterial3D
	check(
		shown and material != null and material.normal_texture != null,
		"a sheet naming a normal_image is drawn lit"
	)
	check(
		not stage.use_sheet(broken_manifest, "S"),
		"a sheet whose normal_image is missing is refused"
	)
	var plain := stage.use_sheet(_write_lit_sheet("plain.json", ""), "S")
	check(
		plain and stage.merc().material_override == null,
		"a sheet with no normal_image falls back to unshaded"
	)
	await _despawn(stage)


func _write_lit_sheet(name: String, normal_name: String) -> String:
	DirAccess.make_dir_recursive_absolute(LIT_DIR)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GOOD_SHEET))
	var manifest: Dictionary = parsed if parsed is Dictionary else {}
	var colour_path := GOOD_SHEET.get_base_dir().path_join(str(manifest.get("image", "")))
	var colour := Image.load_from_file(ProjectSettings.globalize_path(colour_path))
	colour.save_png(LIT_DIR.path_join("sheet.png"))
	var flat := Image.create(colour.get_width(), colour.get_height(), false, Image.FORMAT_RGBA8)
	flat.fill(FLAT_NORMAL)
	flat.save_png(LIT_DIR.path_join("flat_normal.png"))
	manifest["image"] = "sheet.png"
	if normal_name.is_empty():
		manifest.erase("normal_image")
	else:
		manifest["normal_image"] = normal_name
	var path := LIT_DIR.path_join(name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	return path
