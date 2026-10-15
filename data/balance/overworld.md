# overworld.json — the walkable overworld on screen

One line per knob (docs/05_STYLE_CODE.md "Data"). Read by `presentation/world/overworld_map.gd`
and `presentation/world/overworld_director.gd`. Placeholder look (D-067: final UI is out); the
director judges it in play.

## map
All in logical pixels: the map is drawn at 1x on the same texel grid as the street (data/balance/stage.json "pixel", 960 x 540 shown x2 at 1080p) with nearest filtering, never scaled (D-035).
- `tile_px`: the side of one map tile.
- `band_radius_px`: the band's token (a gold disc with a dark ring).
- `party_radius_px`: a party's token, coloured by its type (a pale second ring outside it while it is chasing the band).
- `site_radius_px`: a site's marker on its entrance tile.
- `ring_width_px`: the width of the thin dark outline round the band's token.
- `chase_ring_gap_px`: the clear gap between a chasing party's token and its chase ring.
- `chase_ring_width_px`: the width of the chase ring (wider than the outline, so it reads at 4K).

## walk
- `first_repeat_s`: a held walking key takes its first step at once and its second after this long.
- `repeat_s`: then one step per this many seconds while the key stays down.

## colours
Colours of the look-B palette.
- Every colour here is a palette reference "ramp:index" (core.json or the heartland biome; presentation/palette.gd), never RGB.
- `plain`, `road`, `forest`, `hill`, `water`, `town`: each terrain's tile.
- `void`: what shows past the region's edge (a dark soot frame, not a terrain).
- `band`: the band's token (the company's colour on the street's battle rings).
- `ambush`, `patrol`: bandits' and a patrol's tokens, by encounter type.
- `camp`, `raiders`, `quarry`, `charge`: a job's party (Phase 5 C1): the first three are bandits (the ambush's colour), an escort's charge walks with the band (the band's colour). Placeholders until the hub's look pass (C8).
- `site`: a site's marker.
- `ring`: the outline round the band.
- `chase`: the chase ring round a party that has seen the band (heraldry white, a colour no token, marker or outline shares).
