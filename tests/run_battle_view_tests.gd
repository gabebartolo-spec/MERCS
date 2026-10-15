extends "res://tests/lib/runner.gd"
## Battle view suite (Phase 4 P6b, director ruling Q-G "at every hit"): a blood splat lies at
## the logged cell of every wound, in the order they happened, and a body at the cell of every
## fighter who fell, and both stay until the fight is cleared; a splat's picture is the same for
## the same hit and differs between hits, uses the core blood ramp only, has no stray pixel and
## no gradient, and darkens (fresh, dark red; no brown) without vanishing; a wounded fighter shows a
## bone-white flash frame and gets its own frame back. The scene checks play the slice's fight
## on the street at 1920x1080 with the player's turns as real clicks.
## Seeded by design: Rng.from_seed with fixed seeds; both sides by BattleAi; no clock.
##   godot --headless --path . --script tests/run_battle_view_tests.gd

const Bodies := preload("res://tests/lib/body_checks.gd")
const Kit := preload("res://tests/lib/battle_view_kit.gd")
const InputKit := preload("res://tests/lib/input_kit.gd")
const Pic := preload("res://tests/lib/splat_pictures.gd")
const WINDOW_SIZE := Vector2i(1920, 1080)
const SEEDS: Array[int] = [1009, 424242]
const MAX_ACTIONS := 300
const MIN_HITS := 3
const FIGHT_FRAMES := 6000
const SETTLE := 40
const BLOOD_REFS: Array[String] = ["blood:0", "blood:1"]
const PIXEL_TOLERANCE := 0.08
const SAMPLE_HITS := 24
const MAX_DAMAGE := 7
const NOWHERE := Vector2i(-1, -1)
const HALF_CELL_M := 0.5
const HALF_ROW_M := 0.85


## What a played fight gave: the battle, every event, the wounds and the falls.
class Played:
	extends RefCounted
	var battle: Battle = null
	var events: Array[Dictionary] = []
	var hits: Array[Dictionary] = []
	var fell: Array[String] = []
	var cells: Array[Vector2i] = []


## What every sampled splat picture satisfied.
class Pictures:
	extends RefCounted
	var square := true
	var ramp := true
	var tones := true
	var specks := true


## What the scene fight showed, frame by frame.
class Seen:
	extends RefCounted
	var flashed := false
	var bone := false
	var nodes := true
	var inside := true
	var texel := true


func suite_name() -> String:
	return "BattleView"


func run_checks() -> void:
	root.size = WINDOW_SIZE
	for seed_value: int in SEEDS:
		_check_model(seed_value)
	_check_pictures()
	_check_pixels()
	await _check_scene()


## Plays the fight to its end with no scene, handing every action's events to the marks.
func _play_model(seed_value: int, marks: BattleMarks) -> Played:
	var played := Played.new()
	played.battle = Kit.fight(seed_value).battle
	for _turn: int in MAX_ACTIONS:
		if played.battle.is_over():
			break
		var action := BattleAi.choose(played.battle, played.battle.current(), Kit.sight())
		var events := played.battle.apply(action)
		played.events.append_array(events)
		marks.record(events, played.battle, {})
	for event: Dictionary in played.events:
		if event.get("type") == "hit":
			played.hits.append(event)
			var cell: Vector2i = event["cell"]
			played.cells.append(cell)
		elif event.get("type") == "down":
			played.fell.append(str(event.get("unit")))
	return played


func _check_model(seed_value: int) -> void:
	var tag := "seed %d" % seed_value
	var marks := BattleMarks.new()
	var played := _play_model(seed_value, marks)
	check(played.hits.size() >= MIN_HITS, "%s: the fight has wounds to mark" % tag)
	check(
		marks.splat_cells() == played.cells, "%s: a splat at every logged hit cell, in order" % tag
	)
	check(
		marks.body_units() == played.fell, "%s: a body for every fighter who fell, in order" % tag
	)
	check(
		_bodies_on_last_blow(marks, played),
		"%s: each body lies where its fighter took the last blow" % tag
	)
	_check_fall(marks, played, tag)
	_check_persistence(marks, played, tag)
	_check_replay(marks, played, tag)
	marks.clear()
	check(
		marks.splats.is_empty() and marks.bodies.is_empty(),
		"%s: clearing the fight clears the field" % tag
	)


func _bodies_on_last_blow(marks: BattleMarks, played: Played) -> bool:
	for body: Dictionary in marks.bodies:
		var last := NOWHERE
		for hit: Dictionary in played.hits:
			if hit["target"] == body["unit"]:
				last = hit["cell"]
		if body["cell"] != last or not played.battle.unit(str(body["unit"])).down:
			return false
	return true


## Each body falls away from the fighter who struck the last blow, the same way every replay.
func _check_fall(marks: BattleMarks, played: Played, tag: String) -> void:
	var away := not marks.bodies.is_empty()
	for body: Dictionary in marks.bodies:
		var killer := played.battle.unit(str(body["by"]))
		var dir: Vector2i = body["dir"]
		var cell: Vector2i = body["cell"]
		var from: Vector2i = body["from"]
		away = away and killer != null
		if cell != from:
			away = away and Vector2(cell - from).dot(Vector2(dir)) >= 0.0
			away = away and absi(dir.x) == 1 and absi(dir.y) == 1
	check(away, "%s: each body lies head away from the fighter who struck it down" % tag)


func _check_persistence(marks: BattleMarks, played: Played, tag: String) -> void:
	var before := marks.splats.size()
	var kept := marks.body_units()
	var none: Array[Dictionary] = []
	for _later: int in MAX_ACTIONS:
		marks.record(none, played.battle, {})
	check(
		marks.splats.size() == before and marks.body_units() == kept,
		"%s: nothing leaves the field while the fight stands, however long (bodies persist)" % tag
	)
	var dry := true
	for splat: Dictionary in marks.splats:
		dry = dry and marks.age_of(splat) == BattleMarks.DRY
	check(dry, "%s: old blood has darkened and stayed" % tag)


func _check_replay(marks: BattleMarks, played: Played, tag: String) -> void:
	var again := BattleMarks.new()
	again.record(played.events, played.battle, {})
	var same := again.splats.size() == marks.splats.size()
	for i: int in mini(again.splats.size(), marks.splats.size()):
		var a := again.splat_image(i, Merc.whole(again.splats[i]["damage"]), BattleMarks.FRESH)
		var b := marks.splat_image(i, Merc.whole(marks.splats[i]["damage"]), BattleMarks.FRESH)
		same = same and a.get_data() == b.get_data()
		same = same and again.splats[i]["jitter"] == marks.splats[i]["jitter"]
	check(same, "%s: the same events draw the same field, pixel for pixel" % tag)


func _check_pictures() -> void:
	var marks := BattleMarks.new()
	var allowed: Array[Color] = []
	for ref: String in BLOOD_REFS:
		allowed.append(Palette.colour(ref))
	var view := StageData.load_file(BattleMarks.DATA_PATH)
	var side := Merc.whole(view.num("splat", "half_px")) * 2 + 1
	var smallest := Merc.whole(view.num("splat", "satellite_min_px"))
	var ok := Pictures.new()
	var varied := {}
	for index: int in SAMPLE_HITS:
		for damage: int in range(1, MAX_DAMAGE + 1):
			for level: int in [BattleMarks.FRESH, BattleMarks.WET, BattleMarks.DRY]:
				var image := marks.splat_image(index, damage, level)
				ok.square = ok.square and image.get_size() == Vector2i(side, side)
				var tones := Pic.tones(image, allowed)
				ok.ramp = ok.ramp and tones >= 0
				ok.tones = ok.tones and tones >= 1 and tones <= 2
				ok.specks = ok.specks and Pic.smallest_clump(image) >= smallest
				if level == BattleMarks.FRESH:
					varied[image.get_data().hex_encode()] = true
	check(ok.square, "a splat's picture is a small odd square of whole pixels")
	check(ok.ramp, "every splat pixel is one of the blood ramp's two reds (no brown), fully opaque")
	check(ok.tones, "a splat is a fill and a shadow edge only: no gradient")
	check(ok.specks, "no splat has a clump smaller than the data's minimum: no speckle")
	check(
		varied.size() > SAMPLE_HITS * 4, "different hits make different blots (%d)" % varied.size()
	)


func _check_pixels() -> void:
	var fall := BattleMarks.new()
	var here := Vector2i(3, 3)
	var turned := (
		fall.fall_dir(here, here + Vector2i(-1, -1), 0) == Vector2i(1, 1)
		and fall.fall_dir(here, here + Vector2i(1, 1), 0) == Vector2i(-1, -1)
		and fall.fall_dir(here, here + Vector2i(1, -1), 0) == Vector2i(-1, 1)
		and fall.fall_dir(here, here + Vector2i(-1, 1), 0) == Vector2i(1, -1)
		and fall.fall_dir(here, here + Vector2i.LEFT, 0).x == 1
		and fall.fall_dir(here, here + Vector2i.UP, 0).y == 1
	)
	check(
		turned,
		"a body falls to the diagonal of its cell pointing away from where the blow came from"
	)
	var marks := BattleMarks.new()
	var fresh := marks.splat_image(3, 4, BattleMarks.FRESH)
	var dry := marks.splat_image(3, 4, BattleMarks.DRY)
	check(fresh.get_data() != dry.get_data(), "old blood is a darker colour than fresh")
	check(
		Pic.lum(dry) < Pic.lum(fresh),
		"darker means older: the old splat is darker than the fresh one"
	)
	var big := marks.splat_image(3, MAX_DAMAGE, BattleMarks.FRESH)
	var small := marks.splat_image(3, 1, BattleMarks.FRESH)
	check(Pic.solid(big) > Pic.solid(small), "a harder blow leaves a bigger splat")


## The fight on the street with the player's turns as real clicks: nodes follow the log.
func _check_scene() -> void:
	var mounted := Kit.mount(self, SEEDS[0])
	var view := mounted.view
	var seen := Seen.new()
	for _frame: int in FIGHT_FRAMES:
		if view.battle.is_over():
			break
		var actor := view.battle.current()
		if actor.side == BattleUnit.COMPANY:
			await _company_turn(mounted, BattleAi.choose(view.battle, actor, Kit.sight()))
		else:
			await process_frame
		_look(mounted, seen)
	check(view.battle.is_over(), "the scene fight is played to its end by clicks")
	_check_drawn(mounted, seen)
	await InputKit.frames(self, SETTLE)
	check(view.fx.active() == 0, "every flash has ended and given the frame back")
	_check_bodies(mounted)
	var marks := view.marks
	var kept := marks.bodies.size()
	await InputKit.frames(self, SETTLE)
	check(
		marks.bodies.size() == kept and marks.node_of(marks.bodies[0]) != null,
		"bodies persist after the fight ends"
	)
	view.clear()
	check(marks.splats.is_empty() and marks.bodies.is_empty(), "clearing the view clears its field")
	Kit.unmount(mounted)


func _check_drawn(mounted: Kit.Mounted, seen: Seen) -> void:
	var wounds := 0
	for entry: Dictionary in mounted.view.battle.log:
		if entry.get("type") == "hit":
			wounds += 1
	var drawn := mounted.view.marks.splats.size()
	check(
		wounds > 0 and drawn == wounds, "the view drew one splat per wound in the log (%d)" % wounds
	)
	check(seen.nodes, "every splat has its node on the street")
	check(seen.inside, "every splat node lies inside the cell of its logged hit")
	check(
		seen.texel and mounted.stage.screen_scale() >= 1,
		"splats are one logical pixel per texel at a whole-number screen scale"
	)
	check(seen.flashed, "a wounded fighter showed its flash frame")
	check(seen.bone, "the flash frame is the fighter's own silhouette in bone, nothing else")


## Notes what one frame of the scene shows: a flash, and each splat's node and place.
func _look(mounted: Kit.Mounted, seen: Seen) -> void:
	var view := mounted.view
	seen.flashed = seen.flashed or view.fx.active() > 0
	if not seen.bone:
		seen.bone = _flash_is_bone(mounted)
	var marks := view.marks
	for splat: Dictionary in marks.splats:
		var node := marks.node_of(splat)
		seen.nodes = seen.nodes and node != null
		if node == null:
			continue
		var logged: Vector2i = splat["cell"]
		seen.inside = seen.inside and _within(node.position, view.world_point(logged))
		seen.texel = seen.texel and is_equal_approx(node.pixel_size, mounted.stage.texel_m())


## Whether a flashing fighter's sprite now draws only bone-white pixels (its own silhouette).
func _flash_is_bone(mounted: Kit.Mounted) -> bool:
	var bone := Palette.colour(BattleFx.FLASH_REF)
	for fighter: BattleUnit in mounted.view.battle.units:
		if not mounted.view.fx.is_flashing(fighter.id):
			continue
		var sprite := mounted.stage.extra_mercs[mounted.view.battle.units.find(fighter)]
		var material := sprite.material_override as ShaderMaterial
		var texture: Texture2D = material.get_shader_parameter(&"albedo_texture")
		var image := texture.get_image().get_region(Rect2i(sprite.region_rect))
		var solid := 0
		for y: int in image.get_height():
			for x: int in image.get_width():
				var c := image.get_pixel(x, y)
				if c.a >= 1.0 and c != bone:
					return false
				solid += 1 if c.a >= 1.0 else 0
		return solid > 0
	return false


## Whether a world point lies over a cell: in its column, and nearer its row's centre than
## half a row (the rows stand a figure's height apart since the readable battle screen).
func _within(point: Vector3, centre: Vector3) -> bool:
	return absf(point.x - centre.x) < HALF_CELL_M and absf(point.z - centre.z) < HALF_ROW_M


func _check_bodies(mounted: Kit.Mounted) -> void:
	var view := mounted.view
	var marks := view.marks
	var on_field := marks.bodies.size() > 0
	var gone := true
	for body: Dictionary in marks.bodies:
		var node := marks.node_of(body)
		var fighter := view.battle.unit(str(body["unit"]))
		on_field = on_field and node != null and node.is_inside_tree() and node.visible
		on_field = on_field and fighter.down
		on_field = on_field and body["cell"] == _last_hit_cell(view.battle, fighter.id)
		var sprite := mounted.stage.extra_mercs[view.battle.units.find(fighter)]
		gone = gone and not sprite.visible
	check(on_field, "each fallen fighter's body is on the field at the end of the fight")
	check(gone, "a fallen fighter's standing sprite has gone, the body stays")
	_check_footing(mounted)


## Bodies fit their cell and keep off standing feet; only the living keep a base ring.
func _check_footing(mounted: Kit.Mounted) -> void:
	var view := mounted.view
	var marks := view.marks
	var inside := not marks.bodies.is_empty()
	var clear := true
	var full := true
	var pooled := true
	var texel := mounted.stage.texel_m()
	for body: Dictionary in marks.bodies:
		inside = inside and Bodies.outside(marks, body, texel) == 0
		clear = clear and Bodies.clear_of_feet(marks, body, view.battle)
		full = full and Bodies.full_size(marks, body, texel)
		pooled = pooled and Bodies.pool_under_torso(marks, body)
	check(inside, "every body lies inside its own cell's footprint")
	check(clear, "no body is drawn over a standing fighter's feet")
	check(full, "a body keeps the living figure's full scale (pixel size and pixel count)")
	check(pooled, "each death pool spreads from under its body's torso, below the body")
	var living := 0
	for fighter: BattleUnit in view.battle.units:
		living += 0 if fighter.down else 1
	check(
		Pic.rings_shown(mounted.stage.world()) == living,
		"a base ring under every living fighter and none under the dead"
	)
	check(_one_pixel_scale(mounted), "ground marks and figures show the same pixel size on screen")


## A ground texel (along the width and along the depth) and a figure's texel cover the same
## screen distance, so there is one pixel scale on screen.
func _one_pixel_scale(mounted: Kit.Mounted) -> bool:
	var marks := mounted.view.marks
	var camera := mounted.stage.camera()
	for splat: Dictionary in marks.splats:
		if not Pic.same_pixels(camera, marks.node_of(splat), PIXEL_TOLERANCE):
			return false
	return true


func _last_hit_cell(battle: Battle, unit_id: String) -> Vector2i:
	var cell := NOWHERE
	for entry: Dictionary in battle.log:
		if entry.get("type") == "hit" and entry.get("target") == unit_id:
			cell = entry["cell"]
	return cell


func _company_turn(mounted: Kit.Mounted, action: Dictionary) -> void:
	var kind := str(action.get("type", ""))
	if kind == Battle.ACTION_MOVE:
		var to: Vector2i = action.get("to", Vector2i.ZERO)
		mounted.view.click_cell(mounted.origin + to)
		await process_frame
		return
	var choice_id := Battle.ACTION_WAIT
	if kind == Battle.ACTION_ATTACK:
		choice_id = "%s:%s" % [Battle.ACTION_ATTACK, action.get("target")]
	await InputKit.click(self, mounted.panel.button_for(choice_id))
