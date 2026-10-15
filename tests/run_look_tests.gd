extends "res://tests/lib/runner.gd"
## Look suite: look B on screen (docs/06_STYLE_ART.md sections 2 and 7). Every colour the game
## draws comes from core + heartland through Palette: no presentation or ui script, scene,
## theme or shader holds a colour that is not in the palette, every colour reference in the
## data files resolves, the painted theme draws only palette colours, and every text role keeps
## the contrast floor on the role it sits on.
##   godot --headless --path . --script tests/run_look_tests.gd

const SCAN_ROOTS: Array[String] = ["res://presentation", "res://ui"]
const SCAN_EXTENSIONS: Array[String] = ["gd", "tres", "tscn", "gdshader", "gdshaderinc"]
## The colour owner: the only file allowed a literal colour (CLEAR, NO_TINT).
const OWNER := "res://presentation/palette.gd"
const COLOUR_DATA: Array[Array] = [
	["res://data/balance/overworld.json", "colours"],
	["res://data/balance/slice.json", "markers"],
	["res://data/balance/stage.json", "shades"],
	["res://data/balance/stage.json", "dusk"],
	["res://data/balance/stage.json", "rain_night"],
	["res://data/balance/stage.json", "rain_night/rain"],
	["res://data/balance/stage.json", "sprite"],
]
## Data keys that hold a palette reference (the others in those blocks are numbers or lights).
const REFERENCE_KEYS: Array[String] = ["sky", "colour", "fill", "outline"]
const WHOLE_BLOCKS: Array[String] = ["colours", "markers", "shades"]
const PALETTE_SIZE := 65  # 44 core + 21 heartland (verdure_mid added 2026-10-16)
const MIN_REFERENCES := 25
const MIN_PAIRS := 6
const WCAG_FLOOR := 4.5
const BYTE := 255.0
const OFF_GREY := 0.5


func suite_name() -> String:
	return "Look"


func run_checks() -> void:
	_check_palette()
	_check_scripts()
	_check_data()
	_check_contrast()
	_check_theme()
	_check_map()


func _check_palette() -> void:
	var all := Palette.all_colours()
	check(
		all.size() == PALETTE_SIZE,
		"core + heartland hold %d colours (%d)" % [PALETTE_SIZE, all.size()]
	)
	check(
		Palette.has("soot:0") and not Palette.has("soot:9") and not Palette.has("nope:1"),
		"references resolve, or are refused"
	)
	check(
		(
			Palette.contains(Palette.colour("verdure:3"))
			and not Palette.contains(Color(OFF_GREY, OFF_GREY, OFF_GREY))
		),
		"contains() knows the palette's colours and no others"
	)


## No colour literal in presentation/ or ui/ outside the colour owner is off the palette.
func _check_scripts() -> void:
	var offences: Array[String] = []
	var scanned := 0
	for path: String in _files():
		if path == OWNER:
			continue
		scanned += 1
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for number: int in lines.size():
			var line := lines[number].strip_edges()
			if line.begins_with("#") or line.begins_with(";"):
				continue
			for found: String in _off_palette(path, line):
				offences.append("%s:%d %s" % [path, number + 1, found])
	for offence: String in offences:
		printerr("OFF-PALETTE: " + offence)
	check(scanned > 0, "the scan reads the presentation and ui files (%d)" % scanned)
	check(
		offences.is_empty(),
		(
			"no presentation/ui script, scene, theme or shader colour is off the palette (%d found)"
			% offences.size()
		)
	)


func _files() -> Array[String]:
	var out: Array[String] = []
	for root_path: String in SCAN_ROOTS:
		_walk(root_path, out)
	return out


func _walk(folder: String, out: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(folder):
		if file.get_extension() in SCAN_EXTENSIONS:
			out.append(folder + "/" + file)
	for sub: String in DirAccess.get_directories_at(folder):
		_walk(folder + "/" + sub, out)


## The off-palette colours one line of code holds: named colours, Color.html, Color8 and
## Color(...) literals not in the palette, hex strings not in it, shader colour defaults.
func _off_palette(path: String, line: String) -> Array[String]:
	var found: Array[String] = []
	var named := RegEx.create_from_string("(?<![\\w.])Color\\.\\w+")
	for hit: RegExMatch in named.search_all(line):
		found.append(hit.get_string())
	found.append_array(_off_calls(line))
	var hex := RegEx.create_from_string("#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6})\\b")
	for hit: RegExMatch in hex.search_all(line):
		if not Palette.contains(Color.html(hit.get_string())):
			found.append(hit.get_string())
	if path.get_extension().begins_with("gdshader"):
		var shader := RegEx.create_from_string("source_color\\s*=\\s*vec[34]\\(")
		for hit: RegExMatch in shader.search_all(line):
			found.append(hit.get_string())
	return found


## Color(r, g, b[, a]) and Color8(...) calls of plain numbers that are not palette colours.
func _off_calls(line: String) -> Array[String]:
	var found: Array[String] = []
	var call := RegEx.create_from_string("(?<![\\w.])(Color8?)\\(([^)]*)\\)")
	for hit: RegExMatch in call.search_all(line):
		var parts := hit.get_string(2).split(",")
		var numbers: Array[float] = []
		for part: String in parts:
			if part.strip_edges().is_valid_float():
				numbers.append(part.strip_edges().to_float())
		if numbers.size() != parts.size() or numbers.size() < 3:
			continue
		var divisor := BYTE if hit.get_string(1) == "Color8" else 1.0
		var alpha := numbers[3] / divisor if numbers.size() > 3 else 1.0
		var literal := Color(
			numbers[0] / divisor, numbers[1] / divisor, numbers[2] / divisor, alpha
		)
		if not Palette.contains(literal):
			found.append(hit.get_string())
	return found


## Every colour reference in the data files names a palette step.
func _check_data() -> void:
	var refs := 0
	var bad: Array[String] = []
	for entry: Array in COLOUR_DATA:
		var data := StageData.load_file(str(entry[0]))
		var block := data.section(str(entry[1]))
		for key: String in block:
			var value: Variant = block[key]
			var is_ref: bool = (
				key in REFERENCE_KEYS or (str(entry[1]) in WHOLE_BLOCKS and value is String)
			)
			if not is_ref:
				continue
			refs += 1
			if not (value is String and Palette.has(str(value))):
				bad.append("%s %s/%s = %s" % [entry[0], entry[1], key, str(value)])
	for line: String in bad:
		printerr("BAD REFERENCE: " + line)
	check(
		refs >= MIN_REFERENCES and bad.is_empty(),
		(
			"every colour in the overworld, slice and stage data is a palette reference (%d checked, %d bad)"
			% [refs, bad.size()]
		)
	)
	var rgb_left := 0
	for path: String in ["res://data/balance/overworld.json", "res://data/balance/slice.json"]:
		rgb_left += FileAccess.get_file_as_string(path).count("_rgb")
	check(rgb_left == 0, "the overworld and slice data hold no raw rgb arrays (%d)" % rgb_left)


## Each text role on its background keeps the contrast floor (listed in look_ui.json).
func _check_contrast() -> void:
	var look := Palette.look()
	var floor_ratio: float = look.get("min_contrast", 0.0)
	var pairs: Array = look.get("contrast_pairs", [])
	var worst := INF
	for pair: Array in pairs:
		var ratio := Palette.contrast(Palette.role(str(pair[0])), Palette.role(str(pair[1])))
		print("contrast %s on %s = %.1f" % [pair[0], pair[1], ratio])
		worst = minf(worst, ratio)
	check(
		floor_ratio >= WCAG_FLOOR and pairs.size() >= MIN_PAIRS,
		"the look file asks for at least 4.5:1 over %d pairs" % pairs.size()
	)
	check(
		worst >= floor_ratio,
		"every text role keeps %.1f:1 on its background (worst %.1f)" % [floor_ratio, worst]
	)
	var roles: Dictionary = look.get("roles", {})
	var unresolved := 0
	for role_name: String in roles:
		unresolved += 0 if Palette.has(str(roles[role_name])) else 1
	check(unresolved == 0, "every UI role names a palette step")


## The painted theme holds only palette colours, and a button is the role's colour.
func _check_theme() -> void:
	var ui_look: GDScript = load("res://presentation/ui_look.gd")
	var theme := Theme.new()
	var applied: bool = ui_look != null and ui_look.call("apply", theme) == true
	check(applied, "UiLook paints a theme")
	var off := _off_theme(theme)
	check(off == 0, "every colour and box in the painted theme is a palette colour (%d off)" % off)
	_check_roles(theme)


## How many colours and boxes in the theme are not palette colours.
func _off_theme(theme: Theme) -> int:
	var off := 0
	for type: String in theme.get_color_type_list():
		for item: String in theme.get_color_list(type):
			off += 0 if Palette.contains(theme.get_color(item, type)) else 1
	for type: String in theme.get_stylebox_type_list():
		for item: String in theme.get_stylebox_list(type):
			var box := theme.get_stylebox(item, type) as StyleBoxFlat
			if box != null:
				var known := (
					Palette.contains(box.bg_color)
					and Palette.contains(box.border_color)
					and Palette.contains(box.shadow_color)
				)
				off += 0 if known else 1
	return off


func _check_roles(theme: Theme) -> void:
	var button := theme.get_stylebox("normal", "Button") as StyleBoxFlat
	check(
		button != null and button.bg_color == Palette.role("button_back"),
		"a button rests on the button_back role"
	)
	var panel := theme.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	check(
		panel != null and panel.bg_color == Palette.role("panel_back") and panel.bg_color.a == 1.0,
		"a panel is opaque panel_back"
	)


## The map and the battle markers draw in palette colours and stay told apart.
func _check_map() -> void:
	var terrain: Array[Color] = []
	for key: String in TileRegion.TERRAIN_KEYS:
		terrain.append(OverworldMap.token_colour(key))
	var distinct := {}
	for colour: Color in terrain:
		distinct[colour.to_rgba32()] = true
	check(
		distinct.size() == terrain.size(),
		"the %d terrains are drawn in %d different colours" % [terrain.size(), distinct.size()]
	)
	var all_known := true
	for colour: Color in terrain:
		all_known = all_known and Palette.contains(colour)
	for key: String in ["band", "ambush", "patrol", "site", "ring", "chase"]:
		all_known = all_known and Palette.contains(OverworldMap.token_colour(key))
	check(all_known, "terrain and token colours are palette colours")
	var chase: Dictionary = OverworldMap.chase_ring()
	var ring_colour: Color = chase["colour"]
	check(
		Palette.contains(ring_colour) and ring_colour != OverworldMap.token_colour("site"),
		"the chase ring is a palette colour no token shares"
	)
