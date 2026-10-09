class_name StreetGrid
extends RefCounted
## Builds the Phase 1 grey-box street into a GridMap from data/balance/stage.json "street"
## and "shades": a generated MeshLibrary of placeholder boxes (ground tiles one layer down
## with their tops at y = 0, so props never replace a tile), houses, the well, the cart
## and the interior door marker, plus the one grey-box interior room (stage.json "interior",
## built far off the street so the street camera never sees it). walkable_cells() is the
## ground a figure may stand on. Presentation only; nothing here is random.

const ITEM_GROUND := 0
const ITEM_HOUSE := 1
const ITEM_WELL := 2
const ITEM_CART := 3
const ITEM_DOOR := 4
const ITEM_WALL := 5
## A footprint must cover more than this of a cell (metres) to block it.
const FOOTPRINT_SLACK_M := 0.05
const HALF := 2.0


static func build(street: GridMap, data: StageData) -> void:
	var cell := data.num("street", "cell_size_m")
	var library := MeshLibrary.new()
	var thickness := data.num("street", "ground_thickness_m")
	_add_box_item(
		library, ITEM_GROUND, Vector3(cell, thickness, cell), data.grey("shades", "ground")
	)
	# Ground tiles sit one layer down with their top face at y = 0, so props above
	# never replace a tile in its cell.
	library.set_item_mesh_transform(
		ITEM_GROUND, Transform3D(Basis(), Vector3(0.0, cell - thickness / HALF, 0.0))
	)
	_add_box_item(
		library, ITEM_HOUSE, data.vec3("street", "house_size_m"), data.grey("shades", "house")
	)
	_add_box_item(
		library, ITEM_WELL, data.vec3("street", "well_size_m"), data.grey("shades", "well")
	)
	_add_box_item(
		library, ITEM_CART, data.vec3("street", "cart_size_m"), data.grey("shades", "cart")
	)
	var door_size := data.vec3("street", "door_size_m")
	_add_box_item(library, ITEM_DOOR, door_size, data.grey("shades", "door"))
	var door_lift := Vector3(0.0, door_size.y / HALF, data.num("street", "door_offset_z_m"))
	library.set_item_mesh_transform(ITEM_DOOR, Transform3D(Basis(), door_lift))
	var wall := Vector3(cell, data.num("interior", "wall_height_m"), cell)
	_add_box_item(library, ITEM_WALL, wall, data.grey("shades", "interior_wall"))
	street.mesh_library = library
	street.cell_size = Vector3(cell, cell, cell)
	street.cell_center_y = false
	_fill_cells(street, data, cell)


## A box item whose base sits on the cell floor (mesh origin lifted by half its height).
static func _add_box_item(library: MeshLibrary, id: int, size: Vector3, shade: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = shade
	mesh.material = material
	library.create_item(id)
	library.set_item_mesh(id, mesh)
	library.set_item_mesh_transform(id, Transform3D(Basis(), Vector3(0.0, size.y / HALF, 0.0)))


static func _fill_cells(street: GridMap, data: StageData, cell: float) -> void:
	var half_w := int(data.num("street", "width_m") / cell / HALF)
	var half_d := int(data.num("street", "depth_m") / cell / HALF)
	for x: int in range(-half_w, half_w):
		for z: int in range(-half_d, half_d):
			street.set_cell_item(Vector3i(x, -1, z), ITEM_GROUND)
	var houses := data.floats("street", "house_cells_xz")
	for i: int in range(0, houses.size() - 1, 2):
		street.set_cell_item(Vector3i(int(houses[i]), 0, int(houses[i + 1])), ITEM_HOUSE)
	street.set_cell_item(data.cell("street", "well_cell"), ITEM_WELL)
	street.set_cell_item(data.cell("street", "cart_cell"), ITEM_CART)
	street.set_cell_item(data.cell("street", "door_cell"), ITEM_DOOR)
	_fill_interior(street, data)


## The interior: floor tiles over size_cells from origin_cell, walls round the edge, a gap
## in the near wall at exit_cell.
static func _fill_interior(street: GridMap, data: StageData) -> void:
	var origin := data.cell("interior", "origin_cell")
	var size := data.floats("interior", "size_cells")
	if size.size() < 2:
		return
	var exit := data.cell("interior", "exit_cell")
	for x: int in int(size[0]):
		for z: int in int(size[1]):
			var at := origin + Vector3i(x, 0, z)
			street.set_cell_item(at + Vector3i.DOWN, ITEM_GROUND)
			var edge := x == 0 or z == 0 or x == int(size[0]) - 1 or z == int(size[1]) - 1
			if edge and at != exit:
				street.set_cell_item(at, ITEM_WALL)


## Every ground cell (x, z) not covered by a house, the well, the cart or a wall, plus the
## street door cell (stepping on it enters the interior). Footprints come from the item
## sizes, centred on their cells, so a 6 m house blocks the cells it overlaps.
static func walkable_cells(street: GridMap, data: StageData) -> Dictionary:
	var free := {}
	for at: Vector3i in street.get_used_cells_by_item(ITEM_GROUND):
		free[Vector2i(at.x, at.z)] = true
	var sizes := {
		ITEM_HOUSE: data.vec3("street", "house_size_m"),
		ITEM_WELL: data.vec3("street", "well_size_m"),
		ITEM_CART: data.vec3("street", "cart_size_m"),
		ITEM_WALL: Vector3.ONE * data.num("street", "cell_size_m"),
	}
	for item: int in sizes:
		var size: Vector3 = sizes[item]
		for at: Vector3i in street.get_used_cells_by_item(item):
			_block(free, Vector2(at.x, at.z) + Vector2.ONE / HALF, Vector2(size.x, size.z))
	var door := data.cell("street", "door_cell")
	free[Vector2i(door.x, door.z)] = true
	return free


static func _block(free: Dictionary, centre: Vector2, size: Vector2) -> void:
	var low := centre - size / HALF + Vector2.ONE * FOOTPRINT_SLACK_M
	var high := centre + size / HALF - Vector2.ONE * FOOTPRINT_SLACK_M
	for x: int in range(floori(low.x), floori(high.x) + 1):
		for z: int in range(floori(low.y), floori(high.y) + 1):
			free.erase(Vector2i(x, z))
