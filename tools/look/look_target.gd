extends SceneTree
## Look-target capture (Art, 2026-10-15): one palette in the real street stage, on one
## camera, light, pixel and outline rig. Runs the game's StreetStage (55-degree camera, 960 x 540
## logical pixels, whole-screen pixel mode, lit sprites with normal maps), swaps the grey boxes for
## the Blender kit (assets/look_target/kit, every face named pal:<ramp>:<step> and coloured from the
## palette), applies the palette's day or night light and snaps the whole frame to the palette
## (tools/look/palette_post.gdshader). Default: the heartland biome (core + biome palette, its
## "light" block) and the heartland sprites;
## --palette/--light/--sprites/--tag run any other palette (the options not picked, kept under
## docs/audits/look_target/options/<X>/).
## The map frame is the same stage at map scale: the merc density drops from 84 to MAP_HEIGHT_PX, so
## the camera rail pulls back, and the map tiles and tokens stand in for the street.
##
##   APPDATA=<scratch> godot --path . --resolution 3840x2160 --script tools/look/look_target.gd
##     -- --scene=day|night|map --out=<png> [--palette= --light= --sprites= --tag=]

const STAGE_SCENE := "res://presentation/world/street_stage.tscn"
const DEFAULT_PALETTE := "res://assets/palette/biomes/heartland.json"
const DEFAULT_SPRITES := "res://assets/look_target/heartland/sprites/"
const DEFAULT_TAG := "heartland"
const STREET_KIT := "res://assets/look_target/kit/street_kit.glb"
const MAP_KIT := "res://assets/look_target/kit/overworld_kit.glb"
const POST_SHADER := "res://tools/look/palette_post.gdshader"
const LookMap := preload("res://tools/look/look_map.gd")
const FLAT := ":flat"
const SCREEN_SCALE := 4
const MAP_HEIGHT_PX := 20
const SETTLE_FRAMES := 12
const ORC_AT := Vector3(-0.85, 0.0, 0.55)
const VAMPYR_AT := Vector3(0.95, 0.0, 0.25)
const TORCH_AT := Vector3(0.05, 2.06, 1.3)
const FLAME_AT := Vector3(0.05, 2.06, 1.3)
const BLOB_RADIUS_M := 0.27
const TOKEN_BLOB_M := 0.5
const SHADOW_BIAS := 0.08
const SHADOW_NORMAL_BIAS := 2.5
const SHADOW_DISTANCE_M := 120.0
## Squared OKLab distance added to reserved colours, by ramp: heraldry and blood about 0.1 in
## lightness or hue (only cloth painted in them keeps them); fire less, so the flame keeps
## it but lit plate does not catch stray orange pixels.
const RESERVED_PENALTY := {"heraldry": 0.012, "blood": 0.012, "fire": 0.004}
## The rain's particle seed for these frames: stage.json's seed 7 drops a streak down the Vampyr's
## body, which reads as a blade.
const RAIN_SEED := 11
const WINDOW_PX := Vector2i(3840, 2160)
const STREET_FOCUS := Vector3(0.0, 0.0, -2.0)
## The band's standard is planted beside its token, clear of the figure, slightly toward the camera.
const BANNER_OFFSET_M := Vector3(1.7, 0.0, 0.3)
const TOWN_TILE := Vector2i(8, 4)
const TOWN_SCALE := 1.5
const MAP_FOCUS := Vector3(0.0, 0.0, 4.0)
const BAND_TILE := Vector2i(10, 6)
const PARTY_TILE := Vector2i(4, 6)

var _args := {}
var _palette := {}
var _look := {}
var _stage: StreetStage = null
var _sprites := DEFAULT_SPRITES


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var body := arg.trim_prefix("--")
		_args[body.get_slice("=", 0)] = body.get_slice("=", 1)
	_run.call_deferred()


func _run() -> void:
	var option: String = _args.get("tag", DEFAULT_TAG)
	_sprites = _args.get("sprites", DEFAULT_SPRITES)
	var scene: String = _args.get("scene", "day")
	var palette_path: String = _args.get("palette", DEFAULT_PALETTE)
	_palette = _load_palette(palette_path)
	var light_path: String = _args.get("light", "")
	if light_path.is_empty():
		var biome: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(palette_path))
		_look = biome.get("light", {})
	else:
		_look = JSON.parse_string(FileAccess.get_file_as_string(light_path))
	var packed: PackedScene = load(STAGE_SCENE)
	_stage = packed.instantiate() as StreetStage
	_stage.auto_walk = false
	_stage.integer_scale = SCREEN_SCALE
	if scene == "night":
		_stage.lighting = StreetStage.Lighting.RAIN_NIGHT
	if scene == "map":
		_stage.sprite_height_px = MAP_HEIGHT_PX
	# The 4K TV frame: the game's 1920 x 1080 canvas at 2x is the logical 960 x 540 world at 4x; a
	# 3840 x 2160 SubViewport holds it so the frame does not depend on the desktop's window limits.
	var screen := SubViewport.new()
	screen.size = WINDOW_PX
	screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(screen)
	screen.add_child(_stage)
	await process_frame
	_stage.street().visible = false
	if scene == "map":
		_build_map(option)
	else:
		_build_street(option, scene == "night")
	_light(_block("night" if scene == "night" else "day"))
	_post(option)
	for _i: int in SETTLE_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := screen.get_texture().get_image()
	var out: String = _args.get("out", "user://look.png")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	image.save_png(out)
	print("LOOK_SAVED %s %dx%d" % [out, image.get_width(), image.get_height()])
	quit(0)


func _load_palette(path: String) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var out := {}
	if data.has("core"):  # a biome palette: the core ramps, then the biome's (06 section 2)
		var core: String = data["core"]
		out = _load_palette(path.get_base_dir().path_join(core).simplify_path())
	for ramp: Dictionary in data["ramps"]:
		var colours: Array = ramp["colours"]
		for i: int in colours.size():
			var hex: String = colours[i]
			out["%s:%d" % [ramp["name"], i]] = Color.html(hex)
	return out


func _colour(key: String) -> Color:
	return _palette.get(key, Color.MAGENTA)


func _build_street(option: String, night: bool) -> void:
	var kit: Node3D = (load(STREET_KIT) as PackedScene).instantiate()
	_stage.world().add_child(kit)
	_recolour(kit)
	var post := kit.find_child("lantern_post", true, false) as GeometryInstance3D
	if post != null:
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dir := _sprites
	_stage.use_sheet(dir + "orc_look_%s.json" % option, "SE")
	_stage.focus_on(STREET_FOCUS)
	_stage.stand_at(ORC_AT)
	var vampyr := _stage.add_merc(VAMPYR_AT)
	_stage.show_frame_on(
		vampyr, SheetFrame.from_manifest(dir + "vampyr_look_%s.json" % option, "SW")
	)
	for at: Vector3 in [ORC_AT, VAMPYR_AT]:
		_blob(at, BLOB_RADIUS_M, "soot:3", _stage.world())
	if night:
		var torch := _stage.world().get_node_or_null("Torch") as OmniLight3D
		if torch != null:
			torch.position = TORCH_AT
			torch.light_color = _colour("fire:0")
			torch.light_energy = _num(_block("night"), "torch_energy")
			torch.omni_range = _num(_block("night"), "torch_range_m")
		var flame := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.07
		ball.height = 0.16
		ball.radial_segments = 6
		ball.rings = 3
		var hot := StandardMaterial3D.new()
		hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hot.albedo_color = _colour("fire:1")
		ball.material = hot
		flame.mesh = ball
		flame.position = FLAME_AT
		_stage.world().add_child(flame)
		var rain := _stage.world().get_node_or_null("Rain") as GPUParticles3D
		if rain != null:
			rain.seed = RAIN_SEED
			rain.restart()
			# Frozen after its preprocess: the frame no longer depends on how long rendering took.
			rain.speed_scale = 0.0
			var streak := rain.draw_pass_1 as QuadMesh
			var wet := streak.material as StandardMaterial3D
			wet.albedo_color = _colour(_str(_block("night"), "rain"))


func _blob(at: Vector3, radius: float, key: String, parent: Node3D) -> void:
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.01
	mesh.radial_segments = 12
	var m := StandardMaterial3D.new()
	m.albedo_color = _colour(key)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = m
	disc.mesh = mesh
	disc.scale = Vector3(1.0, 1.0, 0.6)
	disc.position = at + Vector3(0.0, 0.075, 0.0)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(disc)


func _build_map(option: String) -> void:
	var kit: Node3D = (load(MAP_KIT) as PackedScene).instantiate()
	_recolour(kit)
	var holder := Node3D.new()
	_stage.world().add_child(holder)
	LookMap.lay(kit, holder)
	var town := (kit.find_child("marker_town", true, false) as Node3D).duplicate() as Node3D
	town.position = LookMap.centre(TOWN_TILE.x, TOWN_TILE.y)
	town.scale = Vector3.ONE * TOWN_SCALE
	holder.add_child(town)
	_stage.focus_on(MAP_FOCUS)
	_stage.merc().visible = false
	var dir := _sprites
	_token(dir + "orc_token_%s.png" % option, LookMap.centre(BAND_TILE.x, BAND_TILE.y), holder)
	_token(dir + "vampyr_token_%s.png" % option, LookMap.centre(PARTY_TILE.x, PARTY_TILE.y), holder)
	_banner(kit, "marker_banner_band", LookMap.centre(BAND_TILE.x, BAND_TILE.y), holder)
	_banner(kit, "marker_banner_party", LookMap.centre(PARTY_TILE.x, PARTY_TILE.y), holder)
	kit.free()


func _banner(kit: Node3D, key: String, at: Vector3, holder: Node3D) -> void:
	var pole := (kit.find_child(key, true, false) as Node3D).duplicate() as Node3D
	pole.position = at + BANNER_OFFSET_M
	holder.add_child(pole)


func _token(path: String, at: Vector3, holder: Node3D) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	var meta: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(path.get_basename() + ".json")
	)
	var pivot: Array = meta["pivot_px"]
	var sprite := Sprite3D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.centered = false
	var px: float = pivot[0]
	var py: float = pivot[1]
	sprite.offset = Vector2(-px, py - image.get_height())
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.no_depth_test = false
	holder.add_child(sprite)
	sprite.global_position = at
	var camera := _stage.camera()
	var forward: Vector3 = -camera.global_transform.basis.z
	var depth := (at - camera.global_position).dot(forward)
	sprite.pixel_size = _stage.texel_m() * depth / _stage.rail_distance_m()
	_blob(at, TOKEN_BLOB_M, "soot:1", holder)


## Gives every surface named pal:<ramp>:<step> that palette colour: matte, flat, no specular.
## pal:<ramp>:<step>:flat is drawn unlit, exactly that colour (map water: the warm sun turned the
## palette's one blue-slate into brown-grey, and the water read as a road).
func _recolour(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for s: int in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(s)
			var tag := source.resource_name if source != null else ""
			if not tag.begins_with("pal:"):
				continue
			var m := StandardMaterial3D.new()
			var key := tag.trim_prefix("pal:")
			if key.ends_with(FLAT):
				key = key.trim_suffix(FLAT)
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = _colour(key)
			m.roughness = 1.0
			m.metallic_specular = 0.0
			mi.set_surface_override_material(s, m)
	for child: Node in node.get_children():
		_recolour(child)


func _light(spec: Dictionary) -> void:
	var key := _stage.world().get_node("KeyLight") as DirectionalLight3D
	key.rotation_degrees = Vector3(
		-_num(spec, "elevation_degrees"), _num(spec, "azimuth_degrees"), 0.0
	)
	var c: Array = spec["color_rgb"]
	key.light_color = _rgb(c)
	key.light_energy = _num(spec, "energy")
	key.shadow_enabled = true
	key.shadow_bias = SHADOW_BIAS
	key.shadow_normal_bias = SHADOW_NORMAL_BIAS
	key.directional_shadow_max_distance = SHADOW_DISTANCE_M
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = _colour(_str(spec, "sky"))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var a: Array = spec["ambient_rgb"]
	env.ambient_light_color = _rgb(a)
	env.ambient_light_energy = _num(spec, "ambient_energy")
	(_stage.world().get_node("Ambient") as WorldEnvironment).environment = env


func _post(_option: String) -> void:
	var container := _stage.get_node("PixelScreen") as SubViewportContainer
	var material := ShaderMaterial.new()
	material.shader = load(POST_SHADER)
	var labs := PackedVector3Array()
	var rgbs := PackedVector3Array()
	var penalty := PackedFloat32Array()
	for key: String in _palette:
		var col: Color = _palette[key]
		rgbs.append(Vector3(col.r, col.g, col.b))
		labs.append(_oklab(col))
		var cost: float = RESERVED_PENALTY.get(key.get_slice(":", 0), 0.0)
		penalty.append(cost)
	material.set_shader_parameter("palette_rgb", rgbs)
	material.set_shader_parameter("palette_lab", labs)
	material.set_shader_parameter("palette_penalty", penalty)
	material.set_shader_parameter("colour_count", rgbs.size())
	material.set_shader_parameter("dither", _num(_block("post"), "dither"))
	material.set_shader_parameter("logical_size", Vector2(_stage.logical_size()))
	container.material = material


func _oklab(col: Color) -> Vector3:
	var r := _lin(col.r)
	var g := _lin(col.g)
	var b := _lin(col.b)
	var l := pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1.0 / 3.0)
	var m := pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1.0 / 3.0)
	var s := pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1.0 / 3.0)
	return Vector3(
		0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
	)


func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


func _block(name: String) -> Dictionary:
	var block: Dictionary = _look.get(name, {})
	return block


func _num(block: Dictionary, key: String) -> float:
	var value: float = block.get(key, 0.0)
	return value


func _str(block: Dictionary, key: String) -> String:
	var value: String = block.get(key, "")
	return value


func _rgb(values: Array) -> Color:
	var r: float = values[0]
	var g: float = values[1]
	var b: float = values[2]
	return Color(r, g, b)
