# look_ui.json: look B on screen

Colours are references "ramp:index" into `assets/palette/core.json` or the heartland biome file;
`presentation/palette.gd` is the one lookup. No hex or RGB in GDScript, scenes or theme.

- `biome`: the biome palette file loaded after core (a later biome is a new file).
- `roles`: UI role to palette step: panel and button backs, text, text outline, the bar.
- `outline_px`: width of the soot outline on labels drawn straight on the world (map names, battle strip).
- `contrast_pairs`: each text role and the role it sits on; the look suite measures every pair.
- `min_contrast`: the floor for those pairs (WCAG 2 ratio).
