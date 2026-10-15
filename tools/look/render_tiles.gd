extends SceneTree
## Overworld terrain tiles at true 1x (Art, tile trial 2026-10-15): each map-kit tile
## (assets/look_target/kit/overworld_kit.glb) rendered straight down by an orthographic camera
## whose frame is exactly one 4 m tile, lit by the biome's day light and snapped to core + biome
## by the look rig's palette post (tools/look/palette_post.gdshader), at tile_px x tile_px.
## Seamless by construction: each tile is rendered in the middle of a 3 x 3 block of copies, so
## shadows and crowns that cross an edge come back in from the neighbour, and the 4 x 4 dither
## lines up because tile_px is a multiple of 4. The shore is an edge tile: grass to its north,
## water to its south, more shore east and west.
##
##   APPDATA=<scratch> godot --path . --windowed --position 8000,8000
##     --script tools/look/render_tiles.gd -- --out=<dir> [--tile_px=64 --palette=<biome.json>]

const DEFAULT_PALETTE := "res://assets/palette/biomes/heartland.json"
const MAP_KIT := "res://assets/look_target/kit/overworld_kit.glb"
const POST_SHADER := "res://tools/look/palette_post.gdshader"
const DEFAULT_TILE_PX := 64
const TILE_M := 4.0
const TILE_OVERLAP := 1.002
const CAMERA_HEIGHT_M := 40.0
const SETTLE_FRAMES := 6
const FLAT := ":flat"
const SHADOW_BIAS := 0.08
const SHADOW_NORMAL_BIAS := 2.5
const SHADOW_DISTANCE_M := 60.0
## Same reserved-colour penalties as tools/look/look_target.gd.
const RESERVED_PENALTY := {"heraldry": 0.012, "blood": 0.012, "fire": 0.004}
## Output name, kit tile, and the tiles north and south of it (east and west are itself).
const TILES: Array[Array] = [
	["grass", "tile_plain", "", ""],
	["road", "tile_road", "", ""],
	["forest", "tile_forest", "", ""],
	["hill", "tile_hill", "", ""],
	["water", "tile_water", "", ""],
	["shore", "tile_shore_0", "tile_plain", "tile_water"],
]

var _args := {}
var _palette := {}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var body := arg.trim_prefix("--")
		_args[body.get_slice("=", 0)] = body.get_slice("=", 1)
	_run.call_deferred()


func _run() -> void:
	var palette_path: String = _args.get("palette", DEFAULT_PALETTE)
	var tile_text: String = _args.get("tile_px", str(DEFAULT_TILE_PX))
	var tile_px := tile_text.to_int()
	var out: String = _args.get("out", "user://tiles")
	DirAccess.make_dir_recursive_absolute(out)
	_palette = _load_palette(palette_path)
	var biome: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(palette_path))
	var light: Dictionary = biome.get("light", {})
	var day: Dictionary = light.get("day", {})
	var post: Dictionary = light.get("post", {})
	var screen := SubViewport.new()
	screen.size = Vector2i(tile_px, tile_px)
	screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(screen)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size = Vector2(tile_px, tile_px)
	container.material = _post_material(_num(post, "dither"), tile_px)
	screen.add_child(container)
	var world := SubViewport.new()
	world.size = Vector2i(tile_px, tile_px)
	world.own_world_3d = true
	world.msaa_3d = Viewport.MSAA_DISABLED
	world.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(world)
	_rig(world, day)
	var kit: Node3D = (load(MAP_KIT) as PackedScene).instantiate()
	_recolour(kit)
	for spec: Array in TILES:
		var holder := _lay(kit, spec)
		world.add_child(holder)
		for _i: int in SETTLE_FRAMES:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := screen.get_texture().get_image()
		image.convert(Image.FORMAT_RGB8)
		var name: String = spec[0]
		var path := out.path_join("%s.png" % name)
		image.save_png(path)
		print("TILE_SAVED %s %dx%d" % [path, image.get_width(), image.get_height()])
		holder.free()
	kit.free()
	quit(0)


## The tile under the camera with a ring of eight neighbours: itself east and west, and its north
## and south tiles (itself when the spec leaves them empty) on the rows above and below.
func _lay(kit: Node3D, spec: Array) -> Node3D:
	var holder := Node3D.new()
	var own: String = spec[1]
	var north: String = spec[2]
	var south: String = spec[3]
	north = own if north.is_empty() else north
	south = own if south.is_empty() else south
	for row: int in [-1, 0, 1]:
		var key := north if row < 0 else (south if row > 0 else own)
		for col: int in [-1, 0, 1]:
			var copy := (kit.find_child(key, true, false) as Node3D).duplicate() as Node3D
			copy.position = Vector3(col * TILE_M, 0.0, row * TILE_M)
			copy.scale = Vector3.ONE * TILE_OVERLAP
			holder.add_child(copy)
	return holder


func _rig(world: SubViewport, day: Dictionary) -> void:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = TILE_M
	camera.near = 0.1
	camera.far = CAMERA_HEIGHT_M * 2.0
	camera.position = Vector3(0.0, CAMERA_HEIGHT_M, 0.0)
	camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	world.add_child(camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(
		-_num(day, "elevation_degrees"), _num(day, "azimuth_degrees"), 0.0
	)
	var c: Array = day["color_rgb"]
	key.light_color = _rgb(c)
	key.light_energy = _num(day, "energy")
	key.shadow_enabled = true
	key.shadow_bias = SHADOW_BIAS
	key.shadow_normal_bias = SHADOW_NORMAL_BIAS
	key.directional_shadow_max_distance = SHADOW_DISTANCE_M
	world.add_child(key)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = _colour(_str(day, "sky"))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var a: Array = day["ambient_rgb"]
	env.ambient_light_color = _rgb(a)
	env.ambient_light_energy = _num(day, "ambient_energy")
	var holder := WorldEnvironment.new()
	holder.environment = env
	world.add_child(holder)


func _post_material(dither: float, tile_px: int) -> ShaderMaterial:
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
	material.set_shader_parameter("dither", dither)
	material.set_shader_parameter("logical_size", Vector2(tile_px, tile_px))
	return material


func _load_palette(path: String) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var out := {}
	if data.has("core"):
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


## Same recolouring as look_target.gd: pal:<ramp>:<step> is that palette colour, matte;
## a :flat suffix draws it unlit (map water).
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
