# Art direction slice: the playable Phase 1 gate build

> **Director, 2026-10-09 (`D-TBD-art-refocus`):** the merc on this slice was the shared `average`
> human body with swappable equipment looks. The revised vision replaces that with hand-made mercs
> (an orc and a Vampyr are the reference pair), each with their own gear line. The street, stage,
> camera, lighting, weather and loop sketch stand; the "Merc" and "Looks" rows and milestone M4
> wait for P1-ART-REFOCUS and will be rewritten from it.

Owner: Dev Lead (build, controls, stage) and Art Factory (sheets, kit, effects). Signer: the director.
Set by the director on 2026-10-09: "a playable vertical slice that I can test and assess the art
direction before we develop bulk assets and content". This spec makes the Phase 1 gate in
`08_ROADMAP.md` ("walks the street with a merc in the build ... says 'this is the game's look'")
concrete and playable, and (director, same day) "includes an example of the core gameplay loop".
Its question is "is this the look, and does the look hold up while I play the game?", answered
before any bulk asset or content work starts. The loop example is a **sketch**: one short scripted
pass through the nine steps of `00_VISION.md` "Core loop", deep enough to see every kind of screen
and moment the art must carry (street, recruit, choice, battle, aftermath, camp), shallow on
systems. It is not Phase 8's vertical slice, and it does not pass any Phase 2–6 gate: those systems
are still proved separately. Sketch code follows every hard rule (seeded sim, presentation reads
events, content in `data/`), so later phases deepen it instead of replacing it.

## 1. What the director does (about ten minutes, exported Windows build)

1. Double-click `MERCS.exe` (the `build.yml` artifact). The game opens straight into the street at
   overcast day, with no menu, in a full-screen window at the monitor's resolution (1080p or 4K).
2. Walk one merc around the street with WASD or the arrow keys, or by clicking the ground. The
   camera follows on its 55° rail, and the pixels never swim or shimmer.
3. Pass other mercs, the well, the cart and the houses: the merc sorts correctly, hides behind
   things and stays lit wherever it stands.
4. Press 1 / 2 / 3 to swap the three equipment looks and E for the eye-patch.
5. Press T to step the time of day (day, dusk, night) and R to toggle rain. Torches light at dusk.
6. Walk through the interior door into the one building interior and back out.
7. F1 shows or hides a one-line key help, and F3 shows the frame time.
8. Play the loop example (§2a, about fifteen minutes; F5 restarts it with the same seed).
9. Answer one question: "Is this the game's look?" (yes / yes with changes / no, with why).

## 2a. The loop example (one pass, scripted, seeded)

| Vision step | In the sketch | What the art must carry |
|---|---|---|
| 1 Arrive | the company (3 mercs) walks into the street hub | the street, crowd, light |
| 2 Gather | talk to an innkeeper (one rumour) and inspect one recruit (sheet: name, background, two traits, one scar); hire or pass | a recruit card, the UI font, a portrait placeholder |
| 3 Choose | one contract on a notice board: "bandits on the mill road" | the notice-board panel |
| 4 Travel | a short scripted walk out of town to the mill road (same kit, edge of the street) at dusk, rain starting | weather and dusk in motion |
| 5 Gate | a bandit lookout: talk him down (visible check by the most fitting merc) or fight | the choice panel, a visible dice check |
| 6 Battle | a compact turn-based fight on the street grid: your 3–4 vs 4 bandits; move, attack, one ability each; hits, a wound, a death possible | battle readability: who is whose, turn order, hit and wound feedback, the grid at 55° |
| 7 Defeated | the last bandit yields: spare, recruit, ransom or execute | the aftermath choice |
| 8 Return | back in town: one permanent injury or memory line on a merc's sheet | how a scar reads on the sprite (eye-patch overlay) and the sheet |
| 9 Camp | one screen: rest, swap equipment look, "where next" (ends the sketch) | the camp or management panel |

Depth caps: one recruit, one contract, one gate, one battle map, one enemy type, one ability per
merc, one aftermath, one injury. UI is grey-box panels in the picked fonts: the slice judges the
world and sprite art, and the UI only for legibility and fit.

## 2. Contents (all inside the Phase 1 caps)

| Area | In the slice | Owner |
|------|--------------|-------|
| Merc | realistic `average` body at the director's density and sprite pitch (pending samples, D-042); idle and walk clips in 8 facings | Art |
| Looks | three equipment combinations (Art proposes, Lead QCs, director picks from labelled sheets) plus the eye-patch overlay | Art |
| Crowd | 4–6 mercs on fixed, seeded loops or idling (crossing, occlusion, light) | Dev |
| Street | the 40 × 20 m street in the real modular kit (timber, wattle, stone, mud, well, cart, fences); one interior | Art + Dev |
| Light | overcast day, dusk and night key lights; torches with flicker; shadows | Dev |
| Weather and particles | rain (streaks, ground splashes, wet darkening), torch embers, chimney smoke. Each is seeded and pixel-snapped to the logical grid | Dev |
| Controls | WASD / arrows and click-to-move on the grid; camera follow snapped to whole logical pixels | Dev |
| Text | the F1 help line in the UI font pick (Q9), or a placeholder OFL face until then | Dev |

Not in the slice: polished UI art, painted portraits (Phase 2), sound, saves, more than one pass of
the loop, a second street, any weather beyond rain (fog, snow, storm and wind are world-phase items: ask first), and
any diffusion-made frame.

## 3. Milestones (director checkpoints; heavy testing only at these)

| # | Milestone | Done when | Owner |
|---|-----------|-----------|-------|
| M1 | **Playable grey-box** | the exported build opens into the street; the merc is controllable (keys and click); the camera follows pixel-snapped; the crowd walks; T/R/F1/F3 work; the interior door works with grey boxes; today's sheet stands in for the merc | Dev |
| M2 | **Body in motion** | density and sprite pitch picked and frozen; idle + walk clips play in 8 facings while moving; the merc QC passes (lead) | Art + Dev |
| M3 | **Street and weather** | modular kit and interior replace the grey boxes; dusk, night, rain, splashes, embers and smoke | Art + Dev |
| M4 | **Looks** | three equipment looks plus the eye-patch, swappable in game, aligned on every facing and frame | Art + Dev |
| M5 | **Loop example** | §2a playable start to end from one seed: recruit, contract, gate, battle (attack, hit, wound clips: Art), aftermath, camp; a seeded replay gives the same run | Dev + Art |
| Gate | **"Is this the look?"** | the director plays §1 and answers; golden images committed (`assets/golden/`) | Director |

The director can play M1 as soon as it lands, to judge camera, scale and feel early. Each later
milestone ships as a new build of the same exe.

## 4. Acceptance (machine-checked where a machine can check it)

| Check | Pass condition |
|-------|----------------|
| Boot | the exported build reaches the street with zero errors in its log (`build.yml` smoke run) |
| Loop | a scripted run of §2a from a fixed seed reaches the camp screen; the same seed gives the same battle log; the sim decides every outcome (presentation only reads events) |
| Control | a seeded input script (keys, then a click) moves the merc to the expected cell; a test, not a handler call |
| Pixel stability | while the camera follows, every sprite and world texel lands on the logical grid (stage suites); no mixels in any capture |
| Sorting | a merc behind the well is occluded; crossing mercs sort near over far; a merc against a wall is lit like one in the open (#42) |
| Weather | rain, embers and smoke are seeded: two captures with the same seed are identical |
| Performance | median frame time under 16.6 ms at 1080p and 4K on the director's PC during rain at night with the full crowd (F3 readout) |
| Art QC | every sheet, kit piece and effect passed the lead's QC (`art-qa-critic`) before the director sees it |
| Rebuild | the factory rebuilds the slice's sheets from clean (Phase 1 factory acceptance, `phase1_visual_proof.md` §6) |

## 5. Dependencies and open director questions

- **Density** (56 / 84 / 112 px) and **sprite pitch** (55° or a flatter 45° render in the 55° world):
  samples in lead QC now. These block M2, not M1.
- **Walk and idle clips:** Mixamo needs the director's Adobe sign-in (D-029). If it is still blocked
  when M1 lands, the lead asks once: wait, or Art keys a simple walk in Blender (CC0, slower to make).
- **Equipment looks, palette size (Q7), fonts (Q9), head and hair layer:** each comes as one labelled
  question when Art's samples pass lead QC.

## 6. Order of work

Dev starts M1 at once (it needs no art decision), then the M5 skeleton (loop flow, battle grid and
turns with today's sheet) in parallel with Art's M2–M4. Art finishes the density samples and then the clip
route. Every milestone lands as ordinary PRs with evidence; the lead plays the build and runs the
art QC before telling the director a checkpoint is ready.
