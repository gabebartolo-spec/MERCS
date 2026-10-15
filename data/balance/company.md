# company.json — the roster and the experience bar

One line per knob (docs/05_STYLE_CODE.md "Data"). Read by `sim/merc/company.gd` and `sim/merc/merc.gd` (Phase 2 M3).

## roster
- `cap`: the most mercenaries the company can hold (vision: twelve). Every way of adding a merc obeys it; a deployment is smaller (battle.json).

## xp
- `level_xp`: the experience a merc needs to reach each level, cumulative and rising: the first entry is level 1 (0), the second level 2, and so on. The last entry's level is the highest. One bar, filled by fighting and by story (vision, "Growth"); nothing awards experience yet, so first-pass numbers only.

## campaign_end
- `memories_shown`: how many of a fallen merc's own memories the last screen of a campaign lists under their chronicle line (the screen opens when the whole company is dead).
