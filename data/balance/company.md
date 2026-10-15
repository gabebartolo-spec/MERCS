# company.json — the roster and the experience bar

One line per knob (docs/05_STYLE_CODE.md "Data"). Read by `sim/merc/company.gd` and `sim/merc/merc.gd` (Phase 2 M3).

## roster
- `cap`: the most mercenaries the company can hold (vision: twelve). Every way of adding a merc obeys it; a deployment is smaller (battle.json).

## xp
- `level_xp`: the experience a merc needs to reach each level, cumulative and rising: the first entry is level 1 (0), the second level 2, and so on. The last entry's level is the highest. One bar, filled by fighting and by story (vision, "Growth"); nothing awards experience yet, so first-pass numbers only.

## deploy
- `captain_out_morale_dip`: morale the company starts a fight without when the captain sits it out and the field sergeant leads (director Q-F, "no XP, small morale dip"). Battle morale starts at 100 and the company is shaken below 75, so the dip stays small by itself; the pre-fight line shows it before the choice. A captain who leads has no dip.

## campaign_end
- `memories_shown`: how many of a fallen merc's own memories the last screen of a campaign lists under their chronicle line (the screen opens when the whole company is dead).
