# company.json — the roster and the experience bar

One line per knob (docs/05_STYLE_CODE.md "Data"). Read by `sim/merc/company.gd` and `sim/merc/merc.gd` (Phase 2 M3).

## roster
- `cap`: the most mercenaries the company can hold (vision: twelve). Every way of adding a merc obeys it; a deployment is smaller (battle.json).

## xp
- `level_xp`: the experience a merc needs to reach each level, cumulative and rising: the first entry is level 1 (0), the second level 2, and so on. The last entry's level is the highest. One bar, filled by fighting and by story (vision, "Growth"); fights give most of it (below), storylets a small extra.
- `per_fight`: experience every merc who fights and lives through a fight gets (D-095; a merc who sat out, or died, gets none). With `per_kill` it is tuned so a merc who survives three or four fights and lands a few kills reaches level 2 (10), and level 3 (25) takes about twice as long.
- `per_kill`: extra experience for each enemy that merc put down (the blow that took it to 0 health). The hardest fights, with the most enemies, make the veterans.

## campaign_end
- `memories_shown`: how many of a fallen merc's own memories the last screen of a campaign lists under their chronicle line (the screen opens when the whole company is dead).
