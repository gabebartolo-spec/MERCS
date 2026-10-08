class_name StreetStage
extends Node
## Phase 1 grey-box capture stage (docs/specs/phase1_visual_proof.md §1 step 2, §2).
## A 40 × 20 m street of placeholder boxes in a GridMap, one warm key light with flat
## ambient, a perspective camera on a rail above the street centre line, and one
## Sprite3D (a capsule, or a factory sheet frame via use_sheet) that walks a loop past
## the well. Every number that is not an exported var comes from
## data/balance/stage.json (stage.md explains each knob).
##
## Scale contract (tools/pipeline/camera_rig.json): a texel is
## merc_height_m × cos(pitch) / sprite_height_px of the image plane, the sprite is
## stretched 1 / cos(pitch) on Y so the figure stands merc_height_m tall, and the rail
## distance is derived so one texel covers one logical pixel at the look-at point.
## The scene is presentation only: nothing here decides an outcome, and nothing is random.
##
## pixel_mode WHOLE_SCREEN renders the 3D world through a 640 × 360 SubViewport scaled
## 3× with nearest filtering, and snaps the sprite to that viewport's pixel grid each
## step. CRISP renders the world at window resolution with the sprite unsnapped.

enum PixelMode { CRISP, WHOLE_SCREEN }

const STAGE_DATA_PATH := "res://data/balance/stage.json"
const ITEM_GROUND := 0
const ITEM_HOUSE := 1
const ITEM_WELL := 2
const ITEM_CART := 3
const ITEM_DOOR := 4
const HALF := 2.0

## Camera pitch below the horizon, in degrees. Applies at once when changed.
@export var pitch_degrees: float = 35.0:
	set = set_pitch_degrees
## How the 3D world reaches the window; see the class comment.
@export var pixel_mode: PixelMode = PixelMode.CRISP
## On-screen figure height in logical pixels (the factory's char_height_px); the
## texel size and the rail distance follow from it.
@export var sprite_height_px: int = 48
## When false the walker only moves through step(), which captures and tests call.
@export var auto_walk: bool = true

## Times the walker has wrapped past the end of its loop since the stage was ready.
var laps_completed: int = 0

var _data: Dictionary = {}
var _loop_length_m: float = 0.0
var _walk_speed: float = 0.0
var _merc_height_m: float = 0.0

@onready var _world: Node3D = %World
@onready var _street: GridMap = %Street
@onready var _key_light: DirectionalLight3D = %KeyLight
@onready var _ambient: WorldEnvironment = %Ambient
@onready var _rail: Node3D = %CameraRail
@onready var _camera: Camera3D = %Camera
@onready var _path: Path3D = %WalkPath
@onready var _walker: PathFollow3D = %Walker
@onready var _merc: Sprite3D = %PlaceholderMerc


func _ready() -> void:
	_data = _load_data()
	_build_street()
	_setup_light()
	_setup_camera()
	_setup_path()
	_setup_merc()
	_apply_pixel_mode()
	_place_merc()


func _process(delta: float) -> void:
	if auto_walk:
		step(delta)


## Advances the walker by delta seconds and places the sprite. Deterministic: the
## same sequence of deltas always gives the same positions.
func step(delta: float) -> void:
	if _loop_length_m <= 0.0:
		return
	var before: float = _walker.progress
	_walker.progress = before + _walk_speed * delta
	if _walker.progress < before:
		laps_completed += 1
	_place_merc()


func set_pitch_degrees(value: float) -> void:
	pitch_degrees = value
	if is_node_ready():
		_apply_pitch()


## Seconds one full walk of the loop takes at the data's walk speed.
func loop_seconds() -> float:
	if _walk_speed <= 0.0:
		return 0.0
	return _loop_length_m / _walk_speed


func camera() -> Camera3D:
	return _camera


func merc() -> Sprite3D:
	return _merc


func world() -> Node3D:
	return _world


func street() -> GridMap:
	return _street


## The sprite's feet in the pixels of the viewport the camera renders to (the
## 640 × 360 logical viewport in WHOLE_SCREEN, the window in CRISP).
func merc_screen_position() -> Vector2:
	return _camera.unproject_position(_merc.global_position)


## The middle of the standing figure, in the same pixels as merc_screen_position().
func merc_centre_screen_position() -> Vector2:
	return _camera.unproject_position(_merc.global_position + Vector3.UP * _merc_height_m / HALF)


func _load_data() -> Dictionary:
	var text: String = FileAccess.get_file_as_string(STAGE_DATA_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_warning("stage data missing or invalid: %s" % STAGE_DATA_PATH)
	return {}


func _section(name: String) -> Dictionary:
	var section: Variant = _data.get(name, {})
	if section is Dictionary:
		return section
	return {}


func _num(section: String, key: String) -> float:
	var value: Variant = _section(section).get(key, 0.0)
	if value is float or value is int:
		return value
	return 0.0


func _floats(section: String, key: String) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	var value: Variant = _section(section).get(key, [])
	if value is Array:
		var items: Array = value
		for item: Variant in items:
			if item is float or item is int:
				var number: float = item
				out.append(number)
	return out


func _vec3(section: String, key: String) -> Vector3:
	var v := _floats(section, key)
	if v.size() < 3:
		return Vector3.ZERO
	return Vector3(v[0], v[1], v[2])


func _cell(section: String, key: String) -> Vector3i:
	return Vector3i(_vec3(section, key))


func _grey(key: String) -> Color:
	var g := _num("shades", key)
	return Color(g, g, g)


func _build_street() -> void:
	var cell := _num("street", "cell_size_m")
	var library := MeshLibrary.new()
	var thickness := _num("street", "ground_thickness_m")
	_add_box_item(library, ITEM_GROUND, Vector3(cell, thickness, cell), _grey("ground"))
	# Ground tiles sit one layer down with their top face at y = 0, so props above
	# never replace a tile in its cell.
	library.set_item_mesh_transform(
		ITEM_GROUND, Transform3D(Basis(), Vector3(0.0, cell - thickness / HALF, 0.0))
	)
	_add_box_item(library, ITEM_HOUSE, _vec3("street", "house_size_m"), _grey("house"))
	_add_box_item(library, ITEM_WELL, _vec3("street", "well_size_m"), _grey("well"))
	_add_box_item(library, ITEM_CART, _vec3("street", "cart_size_m"), _grey("cart"))
	var door_size := _vec3("street", "door_size_m")
	_add_box_item(library, ITEM_DOOR, door_size, _grey("door"))
	var door_lift := Vector3(0.0, door_size.y / HALF, _num("street", "door_offset_z_m"))
	library.set_item_mesh_transform(ITEM_DOOR, Transform3D(Basis(), door_lift))
	_street.mesh_library = library
	_street.cell_size = Vector3(cell, cell, cell)
	_street.cell_center_y = false
	_fill_cells(cell)


## A box item whose base sits on the cell floor (mesh origin lifted by half its height).
func _add_box_item(library: MeshLibrary, id: int, size: Vector3, shade: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = shade
	mesh.material = material
	library.create_item(id)
	library.set_item_mesh(id, mesh)
	library.set_item_mesh_transform(id, Transform3D(Basis(), Vector3(0.0, size.y / HALF, 0.0)))


func _fill_cells(cell: float) -> void:
	var half_w := int(_num("street", "width_m") / cell / HALF)
	var half_d := int(_num("street", "depth_m") / cell / HALF)
	for x: int in range(-half_w, half_w):
		for z: int in range(-half_d, half_d):
			_street.set_cell_item(Vector3i(x, -1, z), ITEM_GROUND)
	var houses := _floats("street", "house_cells_xz")
	for i: int in range(0, houses.size() - 1, 2):
		_street.set_cell_item(Vector3i(int(houses[i]), 0, int(houses[i + 1])), ITEM_HOUSE)
	_street.set_cell_item(_cell("street", "well_cell"), ITEM_WELL)
	_street.set_cell_item(_cell("street", "cart_cell"), ITEM_CART)
	_street.set_cell_item(_cell("street", "door_cell"), ITEM_DOOR)


func _setup_light() -> void:
	_key_light.rotation_degrees = Vector3(
		-_num("light", "elevation_degrees"), _num("light", "azimuth_degrees"), 0.0
	)
	var rgb := _floats("light", "color_rgb")
	if rgb.size() >= 3:
		_key_light.light_color = Color(rgb[0], rgb[1], rgb[2])
	_key_light.light_energy = _num("light", "energy")
	_key_light.shadow_enabled = true
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = _grey("sky")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var ambient := _num("light", "ambient_grey")
	environment.ambient_light_color = Color(ambient, ambient, ambient)
	environment.ambient_light_energy = _num("light", "ambient_energy")
	_ambient.environment = environment


func _setup_camera() -> void:
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = _num("camera", "fov_degrees")
	_camera.near = _num("camera", "near_m")
	_camera.far = _num("camera", "far_m")
	_rail.position = Vector3(0.0, _num("camera", "look_at_height_m"), 0.0)
	_apply_pitch()


## Metres of the camera's image plane one sprite texel covers.
func texel_m() -> float:
	if sprite_height_px <= 0:
		return 0.0
	return _num("sprite", "merc_height_m") * cos(deg_to_rad(pitch_degrees)) / sprite_height_px


## The rail distance at which one texel covers one logical pixel at the look-at point:
## the logical viewport spans 2 × distance × tan(fov / 2) of the image plane.
func rail_distance_m() -> float:
	var half_fov := deg_to_rad(_num("camera", "fov_degrees")) / HALF
	return texel_m() * _num("pixel", "logical_height_px") / (HALF * tan(half_fov))


## The rail sits on the look-at point; the camera hangs rail_distance_m() away along a
## ray pitched pitch_degrees below the horizon, looking back at the rail. The sprite's
## texel and stretch follow the pitch.
func _apply_pitch() -> void:
	var distance := rail_distance_m()
	var pitch := deg_to_rad(pitch_degrees)
	_camera.position = Vector3(0.0, distance * sin(pitch), distance * cos(pitch))
	_camera.rotation_degrees = Vector3(-pitch_degrees, 0.0, 0.0)
	if _merc.texture != null:
		_apply_texel()


func _apply_texel() -> void:
	_merc.pixel_size = texel_m()
	_merc.scale = Vector3(1.0, 1.0 / cos(deg_to_rad(pitch_degrees)), 1.0)


## Shows one frame of a factory sheet (tools/pipeline, schema mercs.sheet/1) with its
## pivot on the ground. Returns false, changing nothing, for an unknown facing or a
## sheet that does not load. The sheet must be rendered at this stage's pitch and height.
func use_sheet(manifest_path: String, facing: String) -> bool:
	var frame := SheetFrame.from_manifest(manifest_path, facing)
	if frame == null:
		return false
	_show_frame(frame)
	_place_merc()
	return true


## Shows a frame with its pivot texel (x from the left, y from the top) on the node's
## origin, so the node's position is the merc's feet. Sprite3D draws y up from offset.y.
func _show_frame(frame: SheetFrame) -> void:
	_merc.texture = frame.texture
	_merc.region_enabled = true
	_merc.region_rect = frame.region
	_merc.centered = false
	_merc.offset = Vector2(-frame.pivot.x, frame.pivot.y - frame.region.size.y)


func _setup_path() -> void:
	var curve := Curve3D.new()
	var points := _floats("sprite", "path_xz")
	for i: int in range(0, points.size() - 1, 2):
		curve.add_point(Vector3(points[i], 0.0, points[i + 1]))
	if curve.point_count > 0:
		curve.add_point(curve.get_point_position(0))
	_path.curve = curve
	_loop_length_m = curve.get_baked_length()
	_walk_speed = _num("sprite", "walk_speed_m_s")
	_walker.loop = true
	_walker.rotation_mode = PathFollow3D.ROTATION_NONE
	_walker.progress = 0.0


func _setup_merc() -> void:
	_merc_height_m = _num("sprite", "merc_height_m")
	var width := int(_num("sprite", "texture_width_px"))
	var fill := _grey_of("sprite", "fill_grey")
	_show_frame(
		SheetFrame.capsule(width, sprite_height_px, fill, _grey_of("sprite", "outline_grey"))
	)
	_apply_texel()
	_merc.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_merc.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_merc.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_merc.shaded = false
	_merc.double_sided = false
	_merc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _grey_of(section: String, key: String) -> Color:
	var g := _num(section, key)
	return Color(g, g, g)


func _apply_pixel_mode() -> void:
	if pixel_mode != PixelMode.WHOLE_SCREEN:
		_camera.current = true
		return
	var scale := int(_num("pixel", "integer_scale"))
	var logical := Vector2i(
		int(_num("pixel", "logical_width_px")), int(_num("pixel", "logical_height_px"))
	)
	var container := SubViewportContainer.new()
	container.name = &"PixelScreen"
	# Sized from the data, not the window, so the logical viewport is 640 × 360 even
	# headless; the window is the same 1920 × 1080 (project.godot).
	container.position = Vector2.ZERO
	container.size = Vector2(logical * scale)
	container.stretch = true
	container.stretch_shrink = scale
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var viewport := SubViewport.new()
	viewport.name = &"LogicalViewport"
	viewport.size = logical
	viewport.handle_input_locally = false
	add_child(container)
	container.add_child(viewport)
	_world.reparent(viewport)
	_camera.current = true


func _place_merc() -> void:
	var feet: Vector3 = _walker.global_position
	if pixel_mode == PixelMode.WHOLE_SCREEN:
		feet = _snap_to_pixel_grid(feet)
	_merc.global_position = feet


## Moves a world point along the camera's view so it lands on a whole pixel of the
## camera's viewport, keeping its depth.
func _snap_to_pixel_grid(point: Vector3) -> Vector3:
	var forward: Vector3 = -_camera.global_transform.basis.z
	var depth: float = (point - _camera.global_position).dot(forward)
	var screen: Vector2 = _camera.unproject_position(point)
	return _camera.project_position(screen.round(), depth)
