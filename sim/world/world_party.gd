class_name WorldParty
extends RefCounted
## One party walking the overworld (Phase 2): bandits or a patrol, by encounter type. It
## wanders near its home tile until it can see the band (its sight in the balance), then
## walks toward it; it never knows where the band is otherwise (the AI is not psychic).
## Time reaches it as units (the band's steps and rests); it spends them on the terrain it
## walks. A party the band has dealt with is away until its return day, then back home.
## A plain record that WorldSim and PartyMoves fill; to_dict() and from_dict() carry it.

var id := ""
## The encounter type it raises on contact (data/encounters.json "type").
var type := ""
var tile := Vector2i.ZERO
var home := Vector2i.ZERO
## Units saved up toward its next step.
var budget := 0
## The day it walks the map again after the band dealt with it (0: it never left).
var away_until := 0
## Whether it saw the band on its last move (presentation marks a chasing party).
var chasing := false


static func make(party_id: String, party_type: String, at: Vector2i) -> WorldParty:
	var party := WorldParty.new()
	party.id = party_id
	party.type = party_type
	party.tile = at
	party.home = at
	return party


## On the map on this day (not away).
func active(day: int) -> bool:
	return day >= away_until


## Off the map until `day`, then back at its home tile, unaware of the band.
func send_away(day: int) -> void:
	away_until = day
	tile = home
	budget = 0
	chasing = false


func to_dict() -> Dictionary:
	return {
		"id": id,
		"type": type,
		"x": tile.x,
		"y": tile.y,
		"home_x": home.x,
		"home_y": home.y,
		"budget": budget,
		"away_until": away_until,
		"chasing": chasing,
	}


## Rebuilds the record; JSON turns every number into a float, so each is read back whole.
static func from_dict(saved: Dictionary) -> WorldParty:
	var party := WorldParty.new()
	party.id = str(saved.get("id", ""))
	party.type = str(saved.get("type", ""))
	party.tile = Vector2i(_num(saved, "x"), _num(saved, "y"))
	party.home = Vector2i(_num(saved, "home_x"), _num(saved, "home_y"))
	party.budget = _num(saved, "budget")
	party.away_until = _num(saved, "away_until")
	party.chasing = saved.get("chasing", false) == true
	return party


static func _num(block: Dictionary, key: String) -> int:
	var value: Variant = block.get(key, 0)
	if value is int:
		return value
	if value is float:
		var number: float = value
		return roundi(number)
	return 0
