# 00 — Vision

## One sentence

A grim low-fantasy mercenary-collector RPG where the people are the Pokémon: explore a
procedurally changing feudal realm in a 2.5D pixel-on-3D world, recruit and train a small company
of distinctive mercenaries, fight compact turn-based battles, make morally costly choices, and watch
bodies, relationships, reputations and grudges accumulate over years of campaigning.

## The player fantasy (non-negotiable)

The player looks at a scarred, half-ruined hedge knight and feels what Pokémon makes you feel
about a rare creature: *I want that guy.* Every recruit must be capable of becoming a story, and
every story must be able to end.

## North star test

If a procedural mercenary can be captured as an enemy prisoner, become loved or hated inside the
company, lose an eye, adapt tactically, earn a title, betray or save someone, and die in a way the
player remembers, the game works. Nothing scales until this is true in a playable slice.

## Genres and lineage

| Genre | What MERCS takes |
|-------|------------------|
| Creature collector (Pokémon B/W, Cassette Beasts, Monster Sanctuary) | discovery psychology, readable identity at a glance, team-building, a world that is inviting at first glance, 2D characters living in a perspective 3D world |
| Mercenary tactics (Battle Brothers, Jagged Alliance 3, XCOM 2) | procedural recruits with backgrounds, equipment as the "type chart", injury, permadeath, contracts, factions, crisis-driven campaigns, personalised soldiers |
| Emergent narrative sim (Wildermyth, RimWorld) | authored storylets cast against procedural people; memories as narrative state; the sim produces facts and the writing interprets them |
| Fail-forward RPG (Baldur's Gate 3, Esoteric Ebb) | visible checks after the player chooses, failure that advances the story, competing obligations instead of good/evil buttons |
| Attrition horror (Darkest Dungeon) | the emotional cost of adventuring; stress and bodily damage with meaning |
| Tactical clarity (Into the Breach) | rich decisions without UI sludge; every rule explainable |

Tone reference is grounded feudal political fantasy (succession wars, famine, schism, occupation),
not high fantasy. Beauty and warmth exist so brutality has contrast. Cruelty is not maturity.

## Pillars (the ten tests every feature must pass)

1. **Mercenaries are the collectible content.** Recruitment must feel like discovery, not shopping.
2. **Every mercenary is a potential protagonist**, never a replaceable stat block.
3. **Combat is compact, readable and equipment-driven.** Five or six deployed; the player knows everyone on the field.
4. **Morale and surrender are a core resolution system**, and the bridge into prisoners and recruitment.
5. **Permanent wounds, scars, mutilation and death create biography and tactical adaptation**, not only subtraction.
6. **Narrative is authored storylets with procedural casting**, driven by memories and world state. No runtime AI.
7. **Dice resolve uncertain attempts after the player chooses**; failure usually moves the story to a new state.
8. **Authored islands in a procedural sea**: handmade hubs and legendary sites inside simulated countryside.
9. **Contracts come from simulated causes.** Solve the cause and the problem changes.
10. **Visual target: detailed pixel characters inside perspective low-poly 3D**, Pokémon Black/White in structure, Westeros in tone.

## Core loop

1. Arrive at a hub, settlement or discovered site in the 2.5D overworld.
2. Gather rumours, inspect recruits, read faction activity, manage supplies, resolve character events.
3. Choose a contract, political opportunity, exploration lead or personal objective.
4. Travel through procedurally assembled countryside where the world sim creates ambushes,
   refugees, patrols, weather, shortages and discoveries.
5. Resolve moral and social gates through explicit choices and visible checks by the most
   appropriate mercenary.
6. Fight a compact turn-based battle with five or six deployed mercenaries.
7. Take prisoners, rescue, recruit, ransom, release, execute or exchange the defeated.
8. Return with wounds, permanent injuries, loot, reputation changes, memories and altered relationships.
9. Train, equip, recover, re-role, resolve company disputes, decide where next.

## Systems summary (detail lives in the roadmap phases and data schemas)

- **Mercenary identity layers:** background, aptitudes (strength, reflexes, nerve, perception,
  learning, endurance), traits and convictions, culture and faction origin, a rare signature
  quality, history and memories, equipment and training. No class label; the role is what the
  equipment and training currently make possible.
- **Progression is earned identity.** Epithets and identity branches follow what actually happened
  (One-Eye, Oathbreaker, Horsebane). Injury can open adaptation (left-handed retraining, scouting,
  mentoring, command, camp roles). Veterans transition to headquarters roles rather than the bin.
- **Combat:** strict turn order with visible initiative and intent; square grid with eight facings
  (Concept Lead recommendation, see 11_OPEN_QUESTIONS Q3); terrain, height, cover, reach,
  formation; compact kit of weapon actions + trained technique + personal ability + item; equipment
  as the type chart (plate resists cuts, blunt beats armour, shields answer arrows, axes break
  shields, spears control reach, daggers find gaps); morale as the main non-HP ending; synergies
  that are physical and visible (the shieldman literally stands in front of the archer).
- **Injury ladder:** wound → temporary injury → permanent bodily history → death. Permanent states
  change the sprite overlay, the portrait, the role options and future storylet eligibility.
- **Storylets:** authored scenes with casting rules over character, relationship, memory, world and
  location tags. Memories are concrete sentences the game can reference later ("Cedric dragged me
  from the field at Bracken Ford"), not hidden meters.
- **World:** authored capitals, religious centres, fortress towns, legendary locations and crisis
  frameworks; procedural roads, hamlets, farms, forests, camps, faction pressure, wars, shortages.

## Concept Lead overrides to the original brief (2026-10-08)

These are decisions, recorded in `DECISIONS.md`, where this pack departs from the design brief
the director supplied. The brief remains inspiration, not scripture.

| Topic | Brief said | Pack says | Why |
|-------|------------|-----------|-----|
| Grid | hex "or similarly clear" | square grid, 8 facings, shared with overworld | one sprite facing set instead of two; revisit only if combat feel fails in Phase 3 |
| 3D source characters | Tripo generates/standardises source humans | one canonical CC0 base body (MakeHuman/MPFB), 3 body types, hand-tuned once | removes per-character generation, cost and licence exposure; equipment is the variety |
| Tripo | primary 3D gateway | optional prop and equipment concept tool, paid tier only with director approval | free tier is CC-BY (attribution in a commercial game), API wallet is empty, 300 credits already spent on AFL |
| Asset factory proof | eighth build step | second step, paired with the visual proof | it is the largest technical and stylistic risk; everything visual depends on it |
| Three.js animation lab | optional staging environment | deferred to Phase 7 R&D at the earliest | Mixamo library + Blender covers Phase 1–6 motion; a second runtime adds failure modes before the slice exists |
| Generative video (Wan, AnimateDiff) | R&D tool for bespoke 2D motion | parked entirely until the slice passes | 12 GB VRAM makes 14B video impractical; the deterministic pipeline does not need it |
| Qwen-Image 2.1 for concepting | implied by prior use | banned from anything that feeds the product | research-only licence |
| Roster size | "modest reserve" | hard cap of 12 in the slice (6 deployed + 6 reserve) | attachment and permadeath weight; raise only after the success test |

## What this game is not

- Not an open-world sandbox with a huge map. Geography scales last.
- Not a BG3-scale branching narrative. It borrows the philosophy, not the volume.
- Not a grimdark misery simulator. Warmth, humour and ordinary life are required content.
- Not a number-heavy optimiser. Depth sits behind inspection; moment-to-moment decisions stay readable.
- Not mobile. Design for a 1920×1080 PC monitor at integer pixel scale.
