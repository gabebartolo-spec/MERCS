# overworld.json — the walkable overworld on screen

One line per knob (docs/05_STYLE_CODE.md "Data"). Read by `presentation/world/overworld_map.gd`
and `presentation/world/overworld_director.gd`. Placeholder look (D-067: final UI is out); the
director judges it in play.

## map
- `tile_px`: the side of one map tile on screen, in the game's 1920 x 1080 logical pixels.
- `band_radius_px`: the band's token (a gold disc with a dark ring).
- `party_radius_px`: a party's token, coloured by its type (a dark ring while it is chasing the band).
- `site_radius_px`: a site's marker on its entrance tile.
- `ring_width_px`: the width of the rings round the band and round a chasing party.

## walk
- `first_repeat_s`: a held walking key takes its first step at once and its second after this long.
- `repeat_s`: then one step per this many seconds while the key stays down.

## colours
Placeholder colours, as red, green, blue from 0 to 1.
- `plain_rgb`, `road_rgb`, `forest_rgb`, `hill_rgb`, `water_rgb`, `town_rgb`: each terrain's tile.
- `band_rgb`: the band's token (the company's colour on the street's battle rings).
- `ambush_rgb`, `patrol_rgb`: bandits' and a patrol's tokens, by encounter type.
- `site_rgb`: a site's marker.
- `ring_rgb`: the rings round the band and round a chasing party.
