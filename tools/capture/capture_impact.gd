extends SceneTree
## Captures one big hit of the slice's fight (Phase 4 P6c): the hit-stop frame, the blood in the
## air, the drops landing and the stain they leave, as full frames of the street's logical image
## shown at a whole-number scale and 2x crops around the struck fighter. Runs with a window (not
## --headless); the fight is played by BattleAi with the player's turns sent as the panel's
## choices, so the captures are the same fight every run. The view's processing is paused while
## a picture is read back, so the four stages are the visual times named below.
##
##   APPDATA=<scratch> godot --path . --fixed-fps 60 --resolution 1920x1080 \
##     --script tools/capture/capture_impact.gd -- --out=<dir> [--seed=1009] [--hit=1]
##
## Writes <dir>/1_hold.png, 2_flight.png, 3_landing.png, 4_stain.png and the same with _crop.

const Kit := preload("res://tests/lib/battle_view_kit.gd")
const DEFAULT_SEED := 1009
const WINDOW_SIZE := Vector2i(1920, 1080)
const DEFAULT_HIT := 1
const UHD_WIDTH := 3840
const CROP_HALF_PX := 110
## The crop centres this far above the struck fighter's feet (about mid-figure).
const CROP_LIFT_M := 0.9
const CROP_ZOOM := 2
const FIGHT_FRAMES := 20000
## Frames run after the hit-stop ends before each later picture (60 fps).
const FLIGHT_FRAMES := 8
const LANDING_FRAMES := 10
const STAIN_FRAMES := 40

var _args: Dictionary = {}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		_args[parts[0]] = parts[1] if parts.size() > 1 else "1"
	_run.call_deferred()


func _run() -> void:
	root.size = WINDOW_SIZE
	await process_frame
	var out := str(_args.get("out", "user://impact"))
	DirAccess.make_dir_recursive_absolute(out)
	var mounted := Kit.mount(self, int(str(_args.get("seed", DEFAULT_SEED))))
	var view := mounted.view
	var wanted := int(str(_args.get("hit", DEFAULT_HIT)))
	var seen := 0
	for _frame: int in FIGHT_FRAMES:
		if view.battle.is_over():
			break
		mounted.stage.focus_on(view.centre())
		var actor := view.battle.current()
		if actor.side == BattleUnit.COMPANY and not view.impact.holding():
			_company_turn(mounted, BattleAi.choose(view.battle, actor, Kit.sight()))
		if view.impact.holding():
			seen += 1
			if seen == wanted:
				await _shoot(out, mounted)
				break
			while view.impact.holding():
				await process_frame
		await process_frame
	quit(0)


## The four pictures of the hit now being held.
func _shoot(out: String, mounted: Kit.Mounted) -> void:
	var view := mounted.view
	var splat: Dictionary = view.marks.splats[-1]
	var target := view.battle.unit(str(splat["unit"]))
	var feet := view.world_point(target.cell) + Vector3.UP * CROP_LIFT_M
	print("big hit: %s on %s, damage %s" % [splat["by"], splat["unit"], splat["damage"]])
	await _save(out, "1_hold", mounted, feet)
	while view.impact.holding():
		await process_frame
	await _run_frames(FLIGHT_FRAMES)
	await _save(out, "2_flight", mounted, feet)
	await _run_frames(LANDING_FRAMES)
	await _save(out, "3_landing", mounted, feet)
	await _run_frames(STAIN_FRAMES)
	await _save(out, "4_stain", mounted, feet)


func _run_frames(count: int) -> void:
	for _i: int in count:
		await process_frame


## The street's own logical image at a whole-number scale to 4K width, and a 2x crop around
## the struck fighter; the view is paused while it is read back.
func _save(out: String, name: String, mounted: Kit.Mounted, feet: Vector3) -> void:
	mounted.view.set_process(false)
	await RenderingServer.frame_post_draw
	var holder := mounted.stage.find_child("LogicalViewport", true, false) as SubViewport
	holder.get_texture().get_image()  # the first read of a texture can return an old frame
	await RenderingServer.frame_post_draw
	var logical := holder.get_texture().get_image()
	mounted.view.set_process(true)
	var scale := maxi(1, UHD_WIDTH / logical.get_width())
	var big := logical.duplicate() as Image
	big.resize(logical.get_width() * scale, logical.get_height() * scale, Image.INTERPOLATE_NEAREST)
	big.save_png(out.path_join(name + ".png"))
	var at := Vector2i(mounted.stage.camera().unproject_position(feet))
	var half := Vector2i(CROP_HALF_PX, CROP_HALF_PX)
	var area := Rect2i(at - half, half * 2).intersection(Rect2i(Vector2i.ZERO, logical.get_size()))
	var crop := logical.get_region(area)
	var zoom := scale * CROP_ZOOM
	crop.resize(crop.get_width() * zoom, crop.get_height() * zoom, Image.INTERPOLATE_NEAREST)
	crop.save_png(out.path_join(name + "_crop.png"))
	print("%s: logical %s, crop %s at x%d" % [name, logical.get_size(), area, zoom])


func _company_turn(mounted: Kit.Mounted, action: Dictionary) -> void:
	var kind := str(action.get("type", ""))
	if kind == Battle.ACTION_MOVE:
		var to: Vector2i = action.get("to", Vector2i.ZERO)
		mounted.view.click_cell(mounted.origin + to)
		return
	var choice_id := Battle.ACTION_WAIT
	if kind == Battle.ACTION_ATTACK:
		choice_id = "%s:%s" % [Battle.ACTION_ATTACK, action.get("target")]
	mounted.panel.chosen.emit(choice_id)
