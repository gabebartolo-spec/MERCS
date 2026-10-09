# Brainstorm: the merc roster (2026-10-09, big)

Run with the director-brainstorm skill. Tested against `CLAUDE.md` during the session and against
`docs/00_VISION.md` afterwards (see "Vision check" below).

> **For agents:** the director has applied these decisions. `docs/00_VISION.md` was rewritten to
> match (conflicts 1 and 2 below), the art pipeline is paused for refocus (conflict 3), and
> conflicts 4–7 are open questions Q19–Q21 in `docs/11_OPEN_QUESTIONS.md`.

## The idea (director's words)

No generic templates like "rogue", "knight", "archer". Each merc should have a unique playstyle
and identity. Their appearance should testify to their abilities: I should be able to look at
their appearance and gear and make a well-informed guess at their basic combat role. Mercs should
be hand-made like Pokémon. Everything hand-crafted, but the general layout of the map can be
randomised like in Battle Brothers.

## The moment in play

**The orc:** big, bulky, mean-looking, battle axe, plate armour. He charges in and starts
attacking, relying on pure aggression and his gear for survivability.

**The Vampyr:** a regal, dark knight whose bestial nature is barely contained by the grandeur of
his appearance (tone reference: "an undead Tywin Lannister"; mood only, not likeness). He can
sacrifice his own health to gain combat bonuses. He toes a more cautious line, reads the play and
attacks at opportune moments to maximise the impact of his all-ins (cadence reference: Vladimir in
League of Legends). His health is a source of energy he can manipulate.

## Decided

**Roster and identity**
- 25 hand-made mercs at launch, each with particularly strong visual and gameplay identities:
  scaled down from 75–100 to keep it achievable.
- Each merc is one unique person, not a species.
- No class templates. Words like "vanguard" describe how a merc approaches conflict; they do not
  guarantee any traits or stats.
- Appearance and gear show how a merc fights.
- No near-duplicate mercs (for example, never two plate-armoured axe orcs).
- No rarity or power tiers. Some mercs can carry more gravitas or be narrative-gated, but every
  merc should feel like a viable protagonist.
- Personality comes from the choices made along the journey and the consequences and fortunes of
  the merc's escapades.

**Promotion**
- Every merc has two promotions: a three-stage line, like Pokémon evolutions.
- A promoted merc costs more in wages and gains stronger abilities or a bigger role in the party.
- A promoted merc stays recognisable as their earlier stage, with clear, thematically fitting
  changes that make them look superior: tougher, wiser, more beautiful, better equipped, etc.
- Promotion comes from one shared experience bar, filled by fighting and by story (moral choices,
  events, quests): simpler and less gamey.

**Gear and moves**
- Each merc has their own bespoke gear line; no general gear shared between mercs. This keeps
  appearance tied to abilities, and is simpler.
- Mercs learn moves at set levels, like Pokémon.
- A merc takes up to 4 moves into battle. Movesets can be changed through an in-game mechanism
  (to be decided: trainers, potions, etc.).

**Death and injury**
- Every merc has a chance to survive being downed in battle. Survivors can carry injuries and
  permanent injuries, as in Battle Brothers.
- A dead merc stays dead, along with their history and personality. Their playstyle can return
  later as a new person found in the hiring pool (for example, drinking at a tavern).
- The returning merc keeps the same silhouette, build and gear ("a big orc is still a big orc"),
  but personal details differ: haircut, tusks, facial structure, eye colour, tattoos, etc. They
  start fresh, so their personality grows from the new journey.

**Combat and world**
- No type chart ("fire beats grass"). Counters come from logical combat roles: a front-liner
  devastates a back-liner, and so on.
- Every merc has unique, thematically fitting resolve stats. Psychological warfare is a big theme.
- Upkeep (food, supplies, wages) is in, but streamlined and low-hassle: a lever for managing the
  economy, not micromanagement.
- Contracts are not the only way to earn: trade, crafting, gladiator events, looting and banditry
  should all be viable income.
- Map layout is randomised, as in Battle Brothers.

## Rejected and why

- **75–100 mercs at launch:** too much hand-made content; scaled down to 25 by the director.
- **Procedurally generated mercs:** the director wants every merc hand-made.
- **Mercs as species (several copies of one merc):** each merc is one person.
- **Promotion needing both experience and a story gate** (prompt from the session): the director
  chose the single shared bar as simpler and less gamey.
- **The story choosing which way a merc promotes** (prompt from the session): not chosen.
- **Rarity or legendary tiers:** every merc must be a viable protagonist.
- **Pokémon-style elemental type chart:** replaced by combat-role counters.

## Open questions for the director

1. **Sandbox or guided story.** Leaning toward a sandbox with large crises, like Battle Brothers,
   where the story emerges from play and feels unique to each run. Not final.
2. **The Vampyr's last-ditch escape** (bat or shadow form to avoid a killing blow). Only if it
   fits the theme and his identity and proves balanced and fun. It may also become his version of
   surviving being downed rather than a separate mechanic.
3. **How movesets are changed:** trainers, potions or something else.
4. **Which income systems ship first.** Six are listed (contracts, trade, crafting, gladiator
   events, looting, banditry); each needs its own rules, UI and balancing.
5. **Art workload.** 25 mercs × 3 stages = 75 stage looks, plus swappable personal details for
   returning mercs. This is the largest content cost.
6. **Resolve the vision conflicts** below, then revise `docs/00_VISION.md`.
7. **Psychological warfare** deserves its own session, as a major theme.

## Vision check (against `docs/00_VISION.md`, done after the session)

**Conflicts that need a director call:**

1. **Procedural vs hand-made mercs.** The vision is built on procedural people: the one-sentence
   pitch, the north star test ("If a procedural mercenary can be captured..."), "procedural recruits
   with backgrounds" (lineage table), pillar 6 "authored storylets with procedural casting", the
   identity layers (background, aptitudes, traits, culture, signature quality) and regional
   recruitment pools. A fixed cast of 25 replaces most of that.
2. **Tone and species.** The vision says "grim low-fantasy", "grounded feudal political fantasy
   ... not high fantasy", "Westeros in tone", with a scarred hedge knight as the player fantasy.
   An orc and a Vampyr move toward higher fantasy. Is MERCS still low fantasy?
3. **Art pipeline.** The Concept Lead override sets "one canonical CC0 base body (MakeHuman/MPFB),
   3 body types ... equipment is the variety". Non-human builds (orc), per-merc gear lines and 75
   bespoke stage looks don't fit that pipeline. This is the biggest practical conflict.
4. **Gear as type chart and re-roling.** The vision makes "equipment the type chart" (plate
   resists cuts, axes break shields) and says "the role is what the equipment and training
   currently make possible", with re-roling in the core loop. Fixed per-merc gear lines remove
   free re-roling; the gear "type chart" could still work inside each line.
5. **Combat kit.** The vision's kit is "weapon actions + trained technique + personal ability +
   item"; the session chose Pokémon-style learnt moves, up to 4 in battle. These need reconciling.
6. **Progression.** The vision has epithets and identity branches that follow what actually
   happened (One-Eye, Oathbreaker), and injuries that open new roles. A fixed 3-stage line can sit
   alongside that, but which one leads?
7. **Discovery.** Pillar 1, "Recruitment must feel like discovery", is weaker once players know
   the 25 by heart across runs.

**Director's answers (2026-10-09):**
1. "The vision document is mistaken and misunderstood my intent, change it to our new vision."
   Done: `00_VISION.md` rewritten.
2. "I never said the fantasy would be low, but it can still be grim and grounded and contain
   magic." Orcs and vampyrs stay; tone and art direction make them fit.
3. "Let's interrupt and refocus the art pipeline." Done: base-body work paused; P1-ART-REFOCUS.
4–7. Not yet answered: now Q19 (progression), Q20 (kit, equipment physics), Q21 (discovery,
   prisoners); re-roling was dropped from the core loop in favour of promotion.

**Consistent with the vision:** no class labels; morale and resolve as core; "down is not yet
dead" and injuries; permadeath with a company chronicle (the chronicle suits a returning
playstyle well); no rarity labels (guardrail A9); every merc a potential protagonist (pillar 2);
Battle Brothers-style crisis campaigns. The vision's "Not an open-world sandbox with a huge map"
is compatible with a Battle Brothers-style sandbox, as long as the map stays modest.

## Board and log

For the Merge & CI agent to log. These are the director's decisions, ready to paste into a PR body:

- DECISION: Mercs are hand-made, not procedurally generated. 25 at launch, each one unique person
  with a strong visual and gameplay identity. Map layout stays randomised.
- DECISION: Update `CLAUDE.md` Philosophy. "Every system is judged by whether it makes a
  procedurally generated person more memorable" should refer to hand-made mercs (exact wording for
  the director to approve).
- DECISION: Each merc has a three-stage line (two promotions), driven by one experience bar fed by
  combat and story. Promotion raises wages and abilities; visual upgrades stay recognisable.
- DECISION: Each merc has their own gear line; no gear shared between mercs.
- DECISION: Moves are learnt at set levels; up to 4 moves are taken into battle.
- DECISION (relates to hard rule 5, "Mortality is final"): A dead merc stays dead. Their
  playstyle may return later as a new, different-looking person with a fresh history and
  personality. This is not a resurrection.
- DECISION: Any merc can survive being downed; injuries and permanent injuries apply.
- DECISION: No type chart; counters come from combat roles. Every merc has themed resolve.
- DECISION: Upkeep is in and streamlined. Several income sources are viable beyond contracts.
- DECISION: No rarity tiers; every merc must be a viable protagonist.
- STATUS: Open: sandbox vs guided story (leaning sandbox), Vampyr escape, how movesets are
  changed, which income systems ship first, art workload.
- STATUS: Vision revised; art pipeline paused for refocus (see the vision PR).
