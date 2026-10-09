# 00 — Vision

Revised by the director on 2026-10-09. The earlier version assumed procedurally generated
recruits and a low-fantasy setting; both misread the director's intent. The decisions behind this
revision are in `docs/brainstorms/2026-10-09-merc-roster.md` and in this PR's `D-TBD-*` entries.
Questions it leaves open are Q15–Q22 in `11_OPEN_QUESTIONS.md`.

## One sentence

A grim, grounded fantasy mercenary-collector RPG where the people are the Pokémon: lead a company
drawn from a hand-made cast of mercenaries, each one person with their own look, gear and way of
fighting, across a randomised feudal realm in a 2.5D pixel-on-3D world; fight compact turn-based
battles, make morally costly choices, and watch them promote, scar, bond, betray and die.

## The player fantasy (non-negotiable)

The player looks at a mercenary and feels what Pokémon makes you feel about a creature: *I want
that one.* Every merc is hand-made with a strong visual and gameplay identity, and their look
tells you how they fight before you read a number: a huge, mean orc in plate with a battle axe is
clearly a front-line fighter; a slinking plague doctor clearly is not. Every recruit must be
capable of becoming a story, and every story must be able to end.

## North star test

If one of the hand-made mercs can join the company, become loved or hated inside it, lose an eye
and adapt, earn a promotion, betray or save someone, and die in a way the player remembers, the
game works. Nothing scales until this is true in a playable slice.

## The cast

- **25 hand-made mercs at launch** (scaled down from 75–100 so each can be strong). Each is one
  unique person, not a species: there is one of each in the world. No near-duplicates: never two
  plate-armoured axe orcs.
- **No class labels.** Words like "vanguard" describe how a merc approaches conflict; they never
  guarantee traits or stats. Each merc has a unique playstyle.
- **Appearance shows abilities.** Silhouette, build and gear let the player make a well-informed
  guess at a merc's combat role at a glance.
- **No rarity tiers.** Some mercs carry more gravitas or are unlocked through the story, but every
  one must work as a protagonist.
- **Personality is earned.** A merc's personality grows from the choices, consequences and
  fortunes of their journey.
- **Two reference mercs** (director, 2026-10-09):
  - *The orc:* big, bulky, mean, battle axe, plate armour. Charges in on pure aggression and
    relies on his gear to survive.
  - *The Vampyr:* a regal dark knight whose bestial nature is barely contained by his grandeur
    (tone: cold aristocratic menace; mood only, never a likeness of an existing character).
    Masochism and lifesteal: he spends his own health for combat bonuses, plays cautiously, reads
    the fight and times his all-ins. His health is energy he manipulates.

## Growth

- **Three-stage line.** Every merc promotes twice. Promotion raises wages and grants stronger
  abilities or a bigger role in the party. A promoted merc stays recognisable, with clear,
  thematically fitting changes that make them look superior: tougher, wiser, more beautiful,
  better equipped.
- **One experience bar**, filled by fighting and by story (moral choices, events, quests).
  Chosen as simpler and less gamey than story-gated promotions.
- **Moves.** Mercs learn moves at set levels, like Pokémon, and take up to four into battle. How a
  moveset is changed (trainers, potions or something else) is open (Q17).
- **Bespoke gear lines.** Each merc has their own gear line; no general gear is shared between
  mercs, so a merc's look always matches their abilities.

## Death and return

- **Down is not yet dead.** Any merc can survive being downed. When a mercenary drops, the outcome
  stays uncertain until the fight resolves and triage happens, unless the death was visually
  incontrovertible. Survivors can carry injuries and permanent injuries, as in Battle Brothers.
  Post-battle reveals, desperate surgery and survival stories live here.
- **Mortality is final.** A dead merc stays dead, and their history and personality die with them;
  the company chronicle keeps them.
- **A playstyle can return.** Later, the same gameplay identity can reappear in the hiring pool as
  a new person (for example, found drinking in a tavern). They keep the same silhouette, build
  and gear ("a big orc is still a big orc"), but personal details differ: haircut, tusks, facial
  structure, eye colour, tattoos. They start with no history and grow a new personality from the
  new journey. This is a new person, not a resurrection.

## Genres and lineage

| Genre | What MERCS takes |
|-------|------------------|
| Creature collector (Pokémon B/W, Cassette Beasts, Monster Sanctuary) | a hand-made cast with readable identity at a glance, evolutions as promotion lines, moves learnt by level with a four-move loadout, discovery psychology, team-building, a world that is inviting at first glance, 2D characters living in a perspective 3D world |
| Mercenary tactics (Battle Brothers, Jagged Alliance 3, XCOM 2) | a randomised campaign map, injury, permadeath, contracts, factions, crisis-driven campaigns, wages and upkeep |
| Emergent narrative sim (Wildermyth, RimWorld) | authored storylets cast against the company's mercs; memories as narrative state; personality that grows from what happened; the sim produces facts and the writing interprets them |
| Fail-forward RPG (Baldur's Gate 3, Esoteric Ebb) | visible checks after the player chooses, failure that advances the story, competing obligations instead of good/evil buttons |
| Attrition horror (Darkest Dungeon) | the emotional cost of adventuring; stress, resolve and bodily damage with meaning |
| Tactical clarity (Into the Breach) | rich decisions without UI sludge; every rule explainable |

Tone: grim, grounded feudal fantasy that contains magic. Orcs and vampyrs belong here; tone and
art direction make them sit in a world of succession wars, famine, schism and occupation. The
fantasy is not low, but it is never whimsical or high-gloss. Beauty and warmth exist so brutality
has contrast. Cruelty is not maturity.

## Pillars (the ten tests every feature must pass)

1. **Mercenaries are the collectible content.** Recruitment must feel like discovery, not shopping.
2. **Every mercenary is a potential protagonist**, never a replaceable stat block.
3. **Combat is compact, readable and role-driven.** Five or six deployed; the player knows everyone
   on the field. Counters come from logical combat roles (a front-liner devastates a back-liner),
   never from a type chart.
4. **Resolve and morale are a core resolution system**: every merc has their own themed resolve, and
   psychological warfare is a major theme.
5. **Permanent wounds, scars, mutilation and death create biography and tactical adaptation**, not only subtraction.
6. **Narrative is authored storylets cast against the company's mercs**, driven by memories and
   world state, and emergent: each campaign's story should feel unique. No runtime AI.
7. **Dice resolve uncertain attempts after the player chooses**; failure usually moves the story to a new state.
8. **Authored places on a randomised map**: handmade hubs and legendary sites; the map layout is
   randomised each campaign, as in Battle Brothers.
9. **Contracts come from simulated causes.** Solve the cause and the problem changes.
10. **Visual target: detailed pixel characters inside perspective low-poly 3D**, Pokémon Black/White in structure, Westeros in tone.

## The player is the company (from the Three Pillars brief, 2026-10-08)

There is no immortal protagonist and no invisible commander. The company is the persistent
entity the player plays. One current mercenary holds the **office of captain**: a normal recruit
who can fight, be maimed, retire, betray or die. When the captain dies the campaign continues;
a successor is chosen and the overworld figure becomes the new captain. Succession is a story
event, not a portrait swap: senior mercenaries disagree over who deserves command, a noble may
refuse to serve under a thief, the most famous fighter may be a poor leader.

Deploying the captain is a choice with weight: morale and coordination improve, but the company
is destabilised if the captain falls. A field sergeant commands when the captain stays behind.

**The company chronicle is the permanent collection.** Every member who ever served, living,
retired or dead, keeps a chronicle entry: portrait history, origin and recruitment, battles,
kills, injuries, relationships, titles and deeds, equipment of renown, and the cause and place of
death. Permadeath and collecting are compatible because the collection is the company's history,
not the current roster.

**Retreat is legitimate**: encounters do not scale to the company, scouting and judgement matter,
and a mercenary left behind may survive as a prisoner whose location surfaces later as a rumour.

**Integration test for any mercenary:** if removing them changes nothing but combat power, they
are not yet woven into collection, narrative and combat.

## Economy

- **Upkeep is in, streamlined.** Food, supplies and wages are a lever for keeping the economy in
  check, never micromanagement.
- **Many ways to earn.** Contracts, trade, crafting, gladiator events, looting and banditry should
  all be viable income. Which ship first is open (Q18).

## Core loop

1. Arrive at a hub, settlement or discovered site in the 2.5D overworld.
2. Gather rumours, find and inspect recruits, read faction activity, manage supplies, resolve character events.
3. Choose a contract, trade run, gladiator event, raid, political opportunity, exploration lead or
   personal objective.
4. Travel across the randomised countryside, where the world sim creates ambushes, refugees,
   patrols, weather, shortages and discoveries.
5. Resolve moral and social gates through explicit choices and visible checks by the most
   appropriate mercenary.
6. Fight a compact turn-based battle with five or six deployed mercenaries.
7. Take prisoners, rescue, ransom, release, execute or exchange the defeated.
8. Return with wounds, permanent injuries, loot, experience, reputation changes, memories and altered relationships.
9. Train, equip from each merc's gear line, set movesets, promote, recover, resolve company
   disputes, decide where next.

## Systems summary (detail lives in the roadmap phases and data schemas)

- **Mercenary definition:** each merc is authored in `data/`: their three stage looks, gear line,
  move list by level, stats, resolve and a role description in words. No class label. Personality,
  history and memories grow during the campaign.
- **Progression:** the three-stage promotion line, plus earned identity: epithets and identity
  branches still follow what actually happened (One-Eye, Oathbreaker, Horsebane), and injury can
  open adaptation. Veterans can move to headquarters roles rather than the bin. How earned
  identity sits alongside the fixed promotion line is open (Q19).
- **Combat:** strict turn order with visible initiative and intent; square grid with eight facings
  (Concept Lead recommendation, see 11_OPEN_QUESTIONS Q3); terrain, height, cover, reach,
  formation; up to four learnt moves per merc (whether items or basic weapon actions sit beside
  them is open, Q20); counters from combat roles; morale and resolve as the main non-HP ending;
  synergies that are physical and visible (the shieldman literally stands in front of the archer).
- **Injury ladder:** wound → temporary injury → permanent bodily history → death. Permanent states
  change the sprite overlay, the portrait, the role options and future storylet eligibility.
- **Storylets:** authored scenes with casting rules over character, relationship, memory, world and
  location tags. Memories are concrete sentences the game can reference later ("Cedric dragged me
  from the field at Bracken Ford"), not hidden meters.
- **World:** authored capitals, religious centres, fortress towns, legendary locations and crisis
  frameworks on a randomised map of roads, hamlets, farms, forests, camps, faction pressure, wars
  and shortages. Leaning towards a sandbox campaign with crises, like Battle Brothers (Q15).

## Concept Lead overrides to the original brief (2026-10-08)

These are decisions, recorded in `DECISIONS.md`, where this pack departs from the design brief
the director supplied. The brief remains inspiration, not scripture.

| Topic | Brief said | Pack says | Why |
|-------|------------|-----------|-----|
| Grid | hex "or similarly clear" | square grid, 8 facings, shared with overworld | one sprite facing set instead of two; revisit only if combat feel fails in Phase 3 |
| 3D source characters | Tripo generates/standardises source humans | **SUPERSEDED by the director, 2026-10-09:** the hand-made cast includes non-humans (an orc) and every merc has bespoke stage looks and a gear line, so "one CC0 base body, equipment is the variety" no longer fits. The art pipeline is paused and being refocused (`D-TBD-art-refocus`). | — |
| Tripo | primary 3D gateway | optional prop and equipment concept tool, paid tier only with director approval | free tier is CC-BY (attribution in a commercial game), API wallet is empty, 300 credits already spent on AFL |
| Asset factory proof | eighth build step | second step, paired with the visual proof | it is the largest technical and stylistic risk; everything visual depends on it |
| Three.js animation lab | optional staging environment | deferred to Phase 7 R&D at the earliest | Mixamo library + Blender covers Phase 1–6 motion; a second runtime adds failure modes before the slice exists |
| Generative video (Wan, AnimateDiff) | R&D tool for bespoke 2D motion | parked entirely until the slice passes | 12 GB VRAM makes 14B video impractical; the deterministic pipeline does not need it |
| Qwen-Image 2.1 for concepting | implied by prior use | banned from anything that feeds the product | research-only licence |
| Roster size | "modest reserve" | hard cap of 12 in the slice (6 deployed + 6 reserve) | attachment and permadeath weight; raise only after the success test |

### Additions from the Three Pillars brief (director, 2026-10-08; `docs/source-briefs/`)

| Addition | Where it lands |
|----------|----------------|
| The company is the player; the captain is a mortal office with succession and deploy-or-delegate | this file; roadmap Phases 2, 3, 4, 8; question Q13, Q14 |
| Company chronicle for living, retired and dead members | roadmap Phase 4 and Phase 8 caps |
| Down is not yet dead: post-battle triage | roadmap Phase 4 |
| Retreat is legitimate; encounters do not scale; left-behind mercs can be rescued later | roadmap Phases 3, 6 |
| Regional recruitment pools as the "habitat" layer | roadmap Phase 7; to revisit for the fixed cast (Q21) |
| No rarity labels or coloured borders; rarity is recognised, not announced | guardrail A9 |
| Moral scenes voice one to three relevant mercenaries, never everyone | roadmap Phase 5 |
| Which mercenary attempts a check is itself the roleplay | already pillar 7; Phase 5 deliverable |

## What this game is not

- Not a procedurally generated recruit game. Every merc is hand-made; only the map is randomised.
- Not an open-world sandbox with a huge map. Geography scales last; a Battle Brothers-style
  campaign on a modest randomised map is the lean.
- Not a BG3-scale branching narrative. It borrows the philosophy, not the volume.
- Not a grimdark misery simulator. Warmth, humour and ordinary life are required content.
- Not a number-heavy optimiser. Depth sits behind inspection; moment-to-moment decisions stay readable.
- Not mobile. Design for a 1920×1080 PC monitor at integer pixel scale.
