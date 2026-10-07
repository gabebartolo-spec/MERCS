# 01 — Engine decision: Godot 4.7.2

**Decision:** Godot 4.7.2 stable (the build already on this PC), GDScript with static typing
enforced by CI, Forward+ renderer, Windows desktop export. Unity (2022.3 and 6000.x are installed)
is not used.

## The comparison that matters for an AI-built game

| Criterion | Godot 4.7.2 | Unity 6 | Weight for MERCS |
|-----------|-------------|---------|------------------|
| Licence | MIT, no revenue tier, no splash, no account | Free under US$200k revenue/funding, then US$2,310/yr/seat; the 2023 runtime fee was cancelled in Sept 2024 | High: zero licence risk is worth more than any feature |
| Agent-friendliness | Text scenes (`.tscn`), text resources, one `project.godot`, headless CLI (`--headless --script`, `--import`, `--export-release`), diffs are readable | YAML scenes and prefabs with GUIDs, meta files, Editor required for most verification, batchmode is slow and fragile | High: every PR is reviewed and tested by agents, not people |
| 2.5D sprites-in-3D | `Sprite3D` / `AnimatedSprite3D`, billboard modes, pixel snapping, `SubViewport` low-res pipelines are standard | Fully capable (Octopath is Unity) but needs URP setup and more bespoke code | Medium: both can do it; Godot's path is shorter |
| Proven on this PC | 956 commits, 35 headless test suites, sharded CI, capture tooling and seven skills already exist from the AFL project | Nothing built | High: the team starts with a working playbook |
| Language for LLM coding | GDScript is compact and Python-like; static typing catches most hallucinated APIs at parse time; C# available if a hot loop needs it | C# excellent, but Editor-bound compile cycle | Medium |
| Turn-based tactics and sim | No engine dependency needed; plain RefCounted classes run headless in tests | Same, but harder to run without the Editor | Medium |
| Headless CI cost | ~100 MB binary, runs on free GitHub Actions minutes | Editor install per CI run, licence activation in CI | High for a free CI budget |
| Risks | Smaller ecosystem for middleware (no Wwise-class audio out of the box); C# web export still experimental (irrelevant, PC only) | Ecosystem richer, but each paid asset adds licence review | Low |

Godot wins on licence, agent-friendliness, CI cost and existing team tooling. Unity would win only
if the game needed console-grade middleware or a very large third-party asset ecosystem, and it
does not: MERCS builds its own assets by design.

## Language: GDScript, statically typed

- Every variable, parameter and return is typed. `gdlint` and `gdformat` from `gdtoolkit` (MIT)
  run in CI; an untyped declaration fails the build (`untyped-declaration` warning as error in
  `project.godot`).
- C# is permitted later, by decision, for one isolated module if profiling shows GDScript cannot
  hold a budget (the world simulation tick is the only candidate). Nobody introduces it on a hunch.

## Rendering plan (confirmed in Phase 1, not before)

- Forward+ renderer, 1920×1080 target, integer pixel scale.
- Characters are `Sprite3D` billboards (Y-axis) inside real low-poly 3D geometry; the perspective
  camera pitch matches the pitch the sprites were rendered at.
- Pixel stability is solved in Phase 1 with one of two documented options, chosen by the director
  from labelled captures: (a) the whole scene rendered through a low-resolution `SubViewport`
  (everything crunchy, like Octopath), or (b) crisp 3D with pixel characters and snapped sprite
  positions. Phase 1 is not done until this is chosen.

## Export and distribution

- Windows x86_64 export preset committed from day one; a build is produced by CI on every merge to
  `main` so "it runs outside the editor" is never a surprise.
- Steam is the target store (Steamworks SDK terms accepted by the director when the store page is
  made, not before). GOG/itch are secondary and need no engine change.

## Things already on this PC the team reuses

- `C:\Users\DANTE\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
- The Tripo Godot bridge add-on (optional, only if Tripo is approved for props).
- AFL tooling to port: `tools/run_tests.sh`, `tools/check_ci_shards.sh`, `tests/tap.gd` is not
  needed (no touch), the capture scripts, the sharded CI pattern with per-suite check floors.
