class_name BattleImpact
extends RefCounted
## How a blow lands on screen (director, 2026-10-16; P6c): blood thrown from the struck fighter
## along the blow (BattleSpray), and a hit-stop that holds the picture for a few frames on a big
## hit. Presentation only. The battle view runs its animation and effects on the visual clock
## this hands back (step), so a hit-stop freezes the flash, the flying blood and the pause before
## the enemy's next turn, and nothing else: the sim is never paused, slowed or asked anything, and
## Engine.time_scale is never touched, so the battle log is the same with hit-stop on or off; only
## the presentation timeline grows. The threshold, frame count and on/off are data
## (data/balance/battle_view.json "hit_stop"); the player's toggle is the Settings autoload's
## hit_stop (default on). Frames, not seconds: a hit-stop is the same length on every machine.

const DATA_PATH := "res://data/balance/battle_view.json"
const SETTINGS_PATH := ^"/root/Settings"
const SETTINGS_KEY := &"hit_stop"

## The blood in the air and where it lands.
var spray := BattleSpray.new()
## Whether big hits hold the picture: data "on" and the player's toggle both.
var hit_stop_on := true
## Frames the picture is still held for.
var held := 0
## Frames stepped since the fight began, and how many of them were held (the timeline).
var frames := 0
var held_total := 0
## Visual seconds the effects have been given (held frames give none).
var visual_s := 0.0

var _data: StageData = StageData.load_file(DATA_PATH)


## Draws on this stage (see BattleMarks.begin); reads the player's toggle from the Settings
## autoload when the view is in a tree that has one (default on).
func begin(stage: StreetStage, ground: Callable, view: Node) -> void:
	spray.begin(stage, ground)
	var on: Variant = _data.section("hit_stop").get("on", true)
	hit_stop_on = on is bool and on == true and _player_wants(view)
	held = 0
	frames = 0
	held_total = 0
	visual_s = 0.0


## Takes one applied action's events: blood for every hit, landing on its splat in marks, and a
## hold on the biggest. Call after marks.record (the splats must exist); sprites are the
## fighters' figures by id (the blood leaves the struck one's picture).
func play(
	events: Array[Dictionary], battle: Battle, marks: BattleMarks, sprites: Dictionary = {}
) -> void:
	spray.launch(events, battle, marks, sprites)
	if not hit_stop_on:
		return
	for event: Dictionary in events:
		if str(event.get("type", "")) == BattleMarks.EVENT_HIT and is_big(event, battle):
			held = maxi(held, int(_data.num("hit_stop", "frames")))


## Whether a hit is big enough to hold the picture: damage at least min_damage, or at least
## max_hp_share of the target's full health (either knob at 0 is unused).
func is_big(hit: Dictionary, battle: Battle) -> bool:
	var damage := Merc.whole(hit.get("damage", 0))
	var least := int(_data.num("hit_stop", "min_damage"))
	if least > 0 and damage >= least:
		return true
	var share := _data.num("hit_stop", "max_hp_share")
	var target := battle.unit(str(hit.get("target", "")))
	return share > 0.0 and target != null and damage >= share * target.max_hp


## One rendered frame: the seconds the battle's animation and effects should move by (0 while a
## hit-stop holds), with the blood in the air moved on by them.
func step(delta: float) -> float:
	frames += 1
	if held > 0:
		held -= 1
		held_total += 1
		return 0.0
	visual_s += delta
	spray.tick(delta)
	return delta


## Whether a hit-stop is holding the picture now.
func holding() -> bool:
	return held > 0


## Takes the blood in the air off the field (the fight is over and its figures are cleared).
func clear() -> void:
	spray.clear()
	held = 0


func _player_wants(view: Node) -> bool:
	if view == null or not view.is_inside_tree():
		return true
	var settings := view.get_node_or_null(SETTINGS_PATH)
	if settings == null:
		return true
	var wanted: Variant = settings.get(SETTINGS_KEY)
	return wanted if wanted is bool else true
