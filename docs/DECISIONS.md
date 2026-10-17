# Decisions log

Cap: 400 lines; oldest roll to `docs/archive/`. One decision per entry, newest first. A decision
that is not here does not exist. Format: date · id · who decided · the decision · why · what it
changes.

## 2026-10-16 · D-117 · Director · Cast r7 rejected; the cast is redone by hand
Words: "both look awful. both of their heads are featureless stumps and their postures are bizarre and unnatural" (orc and Vampyr, #118 r7); yes to downloading about 12 free-licence reference photos for the critics (reference only, never in the game).
Why: Seven rounds of colour and metric fixes never judged whether the head reads as a face or the stance as a person.
Changes: #118 is a draft on hold, not synced. Render-based studies failed lead QC twice, so the orc is hand-painted pixel by pixel (D:/MERCS-vault/renders/cast_paint_2026-10-16/, round 6 paused); critics judge the read against photos first.

## 2026-10-16 · D-116 · Director · Mercs 3-6 picked; bargaining traits; grass B
Words: slot 3 "Wren", slot 4 "Gauda Kettle", slot 5 "Ser Ambrose Vell", slot 6 "Yaro Sedlak" (as drafted); traits as drafted (Hungry, Shrewd, Flatterer, Gambler), Orc "Hard bargain" and Vampyr "Silver tongue" kept; grass "B: new grass" (darker, greener) as the overworld reference.
Changes: Names and sex in `data/mercs.json` (#145); grass B and `verdure_mid` #40501d, palette 65 colours (#151).

## 2026-10-16 · D-115 · Director · Lethality, dead men's wages, kept advances
Words: "Downed die 1 in 3"; a dead merc's unpaid wages "Forfeit"; a kept advance on abandon gives the mercs "No share"; the lead may make the death-roll data edit a builder was refused.
Changes: triage bands 30/52/67, named deaths 0.30 -> 0.88 per 4 fights (#154); wages forfeit on burial and on loading old saves (#153, #155).

## 2026-10-16 · D-114 · Director · Walk out, no more advances
Words: "Walk out, no more advances": after the company abandons a job, that faction pays nothing up front until the company finishes a job for it.
Why: With the #152 economy, taking advances and walking away covered 87-162% of the bills.
Changes: #155 (farm 17-32%), terms screen line and buttons off (#157). Reopen loop still farms up to 56-110% of the bill (upper bound): for his playtest.

## 2026-10-16 · D-113 · Director · Contract screens ship as working panels; names drafted for him
Words: contract screens "Merge as working panels" (styled look later, own look gate); faction and place names "You draft, I pick".
Changes: #145 merged; drafts in MERCS-builds/faction_place_candidates_2026-10-16.md. Lead (not director): baseline tune #152 (income 119% of the bill, sergeant + 4 patrol from day 8).

## 2026-10-16 · D-112 · Lead (not director) · Lead calls made overnight, for the director's veto
Calls: P1c ranged lines (walls block arrows and spears, fighters block neither, range 6 in data); #127 placeholder gear retuned to keep the slice at 89-109 wins in 200; orc skin option A (the golden's grass remapped to verdure, #118 r4, needs his golden decision before merge); P6c impact (deterministic, no physics raycasts, hit-stop is presentation only, #133); C0 split behind a facade with the five campaign routes pinned (#132); the orc head size (#118).
Why: Each was the simplest option that kept a director ruling intact; none is a taste ruling.
Changes: Data and presentation knobs only. Open for veto in the morning.

## 2026-10-16 · D-111 · Director · Art that passes the critics is wired in; mercs 3-6 drafted for him; rabble kinds; subtle hit-stop; orc priority
Words: grass "Darken to match golden" (one in-between verdure step, grass luma about 71); wire-in "Yes, wire it in"; mercs 3-6 "I draft, you pick" (3 candidates per slot; he chooses or rewrites); rabble kinds: peasant mobs, deserters, cultists, starving brigands (all four); hit-stop "Subtle, a few frames" (no shake); orc fix "Bulk and green-grey skin" (hulking frame, mossy grey-green apart from grass).
Changes: Hit-stop in #133. Cast, tiles and palette PRs follow their critic loops (#118 open). Drafts: MERCS-builds/merc_candidates_2026-10-16.md.

## 2026-10-16 · D-110 · Director · Contracts plan answers (Q-1 to Q-15 of #130)
Words: Q-1 "enemies up to 12 or even 16 if theyre rabble" (rabble a separate weak kind, proper soldiers 4-8); Q-2 up to 6 deploy, 2 in reserve; Q-3 share of contract pay only; Q-4 share splits BY LEVEL; Q-5 daily wage by level; Q-6 split = advance vs on return; Q-7 reputation PER FACTION; Q-8 a bargaining trait per merc that he names (placeholders until then); Q-9 job win/lose as proposed; Q-10 towns buy and sell; Q-11 worn = one point weaker, worth less; Q-12 recruiting a prisoner "Not until you design it" (left out of contracts); Q-13 hunters only "if you took a sizeable amount of upfront money and abandon the job"; Q-14 one named death per 4 fights; Q-15 hunters grow with the grudge.
Changes: `docs/plans/phase5_contracts.md` "Decided". C0 #132 and C4 reputation half #134 merged; C3 wages #135 and C2 negotiation #136 open; C1 in review.

## 2026-10-16 · D-109 · Director · Contracts: four types, negotiated pay, failure has a cost
Words: all four contract types (clear bandits, escort, hold a place, hunt a man); wages a daily wage plus a share; pay terms are negotiated ("you must negotiate"): the employer accepts, counters or walks by reputation and need, and a merc may step in once using traits; push too hard and he walks, name dented; failure or abandon costs reputation and grudges (badly broken deals send men after you).
Changes: Plan #130; C4 #134 merged; C2 #136 open.

## 2026-10-16 · D-108 · Director · After combat: prisoners, loot, armour cost, lethality, company size
Words: prisoners "ransom, recruit, release, execute (all four)" (recruiting later set aside by Q-12, D-110); loot "yes, worn (battered) gear from fallen enemies"; armour strong but costly, the cost being slower to act plus price and upkeep (not fatigue, not movement); lethality a named-merc death every few fights; company cap 8; a typical fight roughly even, 4-8 enemies.
Changes: Slower-to-act plate in #127. Prisoner, loot and upkeep work sits in Phase 5.

## 2026-10-16 · D-107 · Director · Order of work: combat merges, art lands, then a playtest; then Contracts and the road
Words: next playtest after combat merges AND art lands (cast, blood, tiles pass the critics); next depth pass after combat: Contracts and the road.
Changes: Plan #130. Combat is merged except P1c ranged (in progress).

## 2026-10-16 · D-106 · Director · Art: tiles by method B' (Claude-painted); heather three muted purples; orc skin grey-olive
Words: tiles "method B'" (Claude-painted); heather "add 3 muted purples"; orc skin shifts to grey-olive, apart from the grass.
Changes: Tile boards and cast #118 are in critic loops; the palette PR follows a SHIP.

## 2026-10-16 · D-105 · Director · Bows are built next (P1c); spears get real two-cell reach
Words: "build ranged (P1c) next"; "Spears: real 2-cell reach".
Changes: P1c in progress (claude/p4-p1c-ranged).

## 2026-10-16 · D-104 · Director · Hover odds show a percentage; MERCS Ledger ships B
Words: hover odds show a PERCENTAGE ("Hit 40%"); Ledger "ship B" (grittier headings).
Changes: Ledger B in #116. Battle.odds() in #127; the hover readout itself is P7, not built.

## 2026-10-16 · D-103 · Director · The captain's fall breaks about half the company; sat-out dip stays 10; sergeant is the most-XP merc
Words: the captain's fall breaks "ABOUT HALF" the company (steady veterans hold; shaky ones and recruits run); the sit-out dip stays 10; sergeant = most-XP merc; Vampyr blood-price frequency: "leave it".
Changes: Placeholder resolves 4/5/6/6 in #123; sit-out and sergeant in #124.

## 2026-10-15 · D-102 · Director · Blood at every hit; bodies stay
Words: Q-G "At every hit": splashes on every wound, fading over the fight; bodies stay.
Changes: #129 (blood, flash frame, bodies), #133 (spray along the blow, stains, hit-stop).

## 2026-10-15 · D-101 · Director · The captain may sit out: no XP, a small morale dip
Words: Q-F "No XP, small morale dip" (a field sergeant leads; the cost is shown before the fight).
Changes: #124; XP in #125 (D-095).

## 2026-10-15 · D-100 · Director · Withdraw: position decides
Words: Q-E "Position decides": whoever reaches the map edge escapes; those engaged or too far back are left behind, captured or killed by a seeded roll on its own Rng stream.
Changes: Rule in the combat plan (#114); no merged PR yet.

## 2026-10-15 · D-099 · Director · The captain's death is a large morale fall
Words: Q-D "Large morale fall": every unit on that side loses a big chunk of resolve at once; veterans can hold, shaky ones break (sharpened by D-103).
Changes: #123.

## 2026-10-15 · D-098 · Director · Surrender when cornered or the leader is down
Words: Q-C "Cornered or leader down": a broken side runs if it has a way out; it surrenders, giving prisoners, when surrounded or pinned or its leader is down. Position decides.
Changes: #123 (the non-psychic enemy that acts on it is #122).

## 2026-10-15 · D-097 · Director · Armour is leather, mail, plate
Words: Q-B "Leather, mail, plate": even the lightest is real armour; mail stops slashes not thrusts; plate turns cuts, is slow, and maces dent it.
Changes: #127 (armour soaks, plate slow).

## 2026-10-15 · D-096 · Director · Weapons are sword, axe, spear, mace, bow; each fighter has one weapon action plus four moves
Words: Q-B "Sword, axe, spear, mace, bow" (axes break shields, maces beat plate, spears reach 2 cells, swords all-round, bows ranged); Q-A "1 weapon + 4 moves" (one weapon action from gear, four learnt moves, no item slot until items exist; 10 actions total cap).
Changes: #121, #126 (weapon action replaces attack), #127 (shields, axes split them).

## 2026-10-15 · D-095 · Director · XP from fights: surviving plus kills
Changes: #125. Director 2026-10-15; his exact words are not recorded in the PR.

## 2026-10-15 · D-094 · Director · Levels matter: small growth and new moves per level
Changes: #120. Director 2026-10-15; his exact words are not recorded in the PR.

## 2026-10-15 · D-093 · Director · UI and map colours are look B palette references
Why: The director approved the look B colours on the real screens (D-085).
Changes: #115 (one Palette lookup, `look_ui.json`, enforced by the look suite).

## 2026-10-15 · D-092 · Director · MERCS gets its own pixel typeface
Words: "yeah better to make a unique one" (after "consider using the same font my afl game uses"); grit in headings.
Changes: MERCS Ledger, Regular + Display, original and owned (#116). `06_STYLE_ART.md` §7 still names two OFL faces and is due a wording fix.

## 2026-10-15 · D-091 · Director · Combat depth is the first depth pass
Why: Combat is where the mercs are seen; weapons, armour, morale, surrender and blood come before more systems.
Changes: `docs/plans/phase4_combat.md` (#114); the combat rulings are D-096..D-102; the non-psychic enemy is #122.

## 2026-10-15 · D-090 · Director · Parallel Godot runs allowed; more builders when work is independent
Words: "use as many godots as you want dont bottleneck yourself"; "build faster ... summon more builders if you need". Earlier the same night: "STOP OPENING GODOT", lifted with "OK GODOT is all yours".
Why: Speed; one Godot per agent was the bottleneck.
Changes: Each Godot run keeps its own APPDATA, offscreen, killed by PID; a stop order stops every run at once. The four-coder cap (D-072) is not a ceiling for independent work.

## 2026-10-15 · D-089 · Director · Heartland gets a water ramp; no slop in any art we make
Words: "add water colours"; "if you're making the art yourself you gotta be aboslutely brutal with your QA, NO SLOP will be tolerated, desloppify"; "you need to become the worlds leading expert on what constitutes AI SLOP ART".
Why: The palette had no second water tone; agent-made art needs a hard bar.
Changes: Water ramp water_deep #1c2a33, water_low #2e3e48, water_high #42565d, water_glint #a3b7ad (proposal, lands with the palette dedupe PR). Bar: skill ai-slop-art (scanner slop_scan.py); SHIP/FIX verdicts by a fresh critic. The look-B golden's 1-px dither and palette near-duplicates are being re-rendered for his A/B.

## 2026-10-15 · D-088 · Director · Texel Studio may be installed locally for the tile trial
Words: answer "Allow the install" (self-hosted engine at github EYamanS/texel-studio cde7bdd, local Ollama, no spend).
Why: Third column of the terrain-tile trial (D-080); register row CLEARED for self-hosted internal use.
Changes: Installed under D:/MERCS-vault/tools/texel-studio (venv), not in the repo. Cloud texel.studio stays uncleared (Pro = spend).

## 2026-10-15 · D-087 · Director · Ironman is an option at campaign start; default On (lead's pick)
Words: answer "Ironman as an option" to "How strict should saving be?".
Why: Quitting and reloading undid deaths; Ironman closes it, Off keeps manual saves.
Changes: #103: autosave at fight start, fight end and Continue; a mid-fight quit reloads the same fight. Optional save key "ironman"; old saves load as Off.

## 2026-10-15 · D-086 · Director · The palette is core ramps plus one set per biome/kingdom
Words: "the game has scope for multiple colour pallettes in the future to differentiate different biomes/kingdoms/landscapes"
Why: One look across the game, with regions told apart by their biome set.
Changes: #100: `assets/palette/core.*` (44) + `assets/palette/biomes/heartland.*`; validators read core + biome. `06_STYLE_ART.md` §2.

## 2026-10-15 · D-085 · Director · Look target B "Peat and Ochre"; lighting 5% brighter; final fidelity much higher
Words: "peat and ochre probably has the most atmosphere"; "the colour looks good though. the lighting could stand to be 5% brighter"; "the end fidelity would have to be much higher though in terms of the art"; pick: "B Peat and Ochre".
Why: The look target fixes palette, light and texel density for every later asset.
Changes: #100 goldens `assets/golden/{street_day,street_rain_night,overworld_map}.png`; B is biome "heartland". Fidelity rises in final art, not in the target.

## 2026-10-15 · D-084 · Director · Full-loop playtest passed
Words: "playtest was good carry on"
Why: Walk, encounter, battle, triage, hub and storylet run as one loop.
Changes: Phase 2 gate pack (#97) and gap fixes (#101) follow.

## 2026-10-15 · D-083 · Director · The campaign ends when the whole company is dead
Words: answer "Campaign ends".
Why: Mortality is final (rule 5); no free restart of a wiped company.
Changes: #98: last screen, save marked ended.

## 2026-10-15 · D-082 · Director · Retro Diffusion: US$10 prepaid, private, for the terrain-tile trial
Words: answers "Licence check, then trial", "Small paid plan, private", "US$10"; then "$10 is in".
Why: Trial an AI pixel tool against the Blender rig on the locked look.
Changes: Spend cap US$10; more needs a new yes. Trial 2026-10-15 used US$1.02 (17 images). Outputs stay in the vault until he picks a method.

## 2026-10-15 · D-081 · Director · Agents talk tersely to one another
Words: "you guys should use concise language when you speak to one another so that we use less context and tokens on messages"
Why: Fewer tokens per message.
Changes: Agent briefs and messages: short, one line where possible.

## 2026-10-15 · D-080 · Director · Texel Studio trial for terrain tiles after the look-target pick: local Ollama, no diffusion step, licensing row first
Words: Answer to the director's question on how to establish one consistent aesthetic ("how are we going to establish an aesthetic and stick to it with consistent style?"); trial follows his look-target pick.
Why: Consistency from one target; no diffusion keeps D-002 and rule 1 intact.
Changes: `docs/10_LICENSING_REGISTER.md` row CLEARED before any file enters `assets/` or `tools/`.

## 2026-10-15 · D-079 · Director · Worktree forced removal is allowed for finished worktrees
Words: Standing permission for Merge & CI and builders to `git worktree remove --force` a worktree whose PR merged.
Why: Stops the permission refusals that left stale worktrees.
Changes: Never for unmerged work.

## 2026-10-15 · D-078 · Director · Overworld is walked manually at map scale; towns cut to street scale; parties are visible; regions are procedural with hand-made locations, events and towns
Words: "i want to clarify a design goal, moving around the world should be done manually, not in a menu, our band will navigate an overworld just like pokemon, procedurally generated maps like battle brothers with bespoke hand crafted locations and events and towns". His answers: smaller map scale with a cut to street scale; visible parties.
Why: The menu map (#75) proved structure; the vision is a walked world.
Changes: Branch claude/p2-overworld-walk; `docs/08_ROADMAP.md` Phase 2 to be revisited by the Concept Lead.

## 2026-10-15 · D-077 · Director · Letter keys replace every function key (M map, C company, L loop, H help)
Words: "remove the F2 stuff, function buttons dont work on my keyboard / replace with alternatives"
Why: His keyboard has no working function keys.
Changes: #86; open branches bind through SliceKeys.

## 2026-10-15 · D-076 · Director · 4K display rule: the game must fill a 4K TV and its text must be readable
Words: "the game needs to display on a 4k tv, i cant read any of the text its too small"
Why: Text was unreadable on his TV.
Changes: #83: fullscreen, 2x stretch, 24 px base.

## 2026-10-15 · D-075 · Director · Milestone 2 playtest passed
Words: "milestone 2 playtest is a success. clearly limited by the lack of combat infrastructure but it works"
Why: Combat depth comes from milestone 4 (#85).
Changes: STATUS.md Phase 2 item 2 DONE (#80).

## 2026-10-15 · D-074 · Director · Art resumes on the look target first
Words: Director: "Keep Art paused", then "Yes, look target first" (answer to how to keep one aesthetic).
Why: Style before cast art.
Changes: Art row in STATUS.md; branch claude/art-look-target. Amends D-051/D-065 pause.

## 2026-10-15 · D-073 · Director · Milestone 1 passed
Words: "milestone 1 is played. its good"
Why: Carry on to milestone 2.
Changes: STATUS.md Phase 2 item 1 DONE (#75).

## 2026-10-15 · D-072 · Director · Coder subagent cap raised from 2 to 4
Words: "4 coders"
Why: More parallel builders in Phase 2.
Changes: Amends D-071 (Project Architect 3.0).

## 2026-10-14 · D-071 · Director · Project Architect 3.0 adopted as the team structure for Phase 2
Why: coder subagents own edit/build/test loops, retriever subagents handle reads over 300 lines, a fixed short return contract, a scripted merge-eligibility check, restart from handoff at about 150k. Rejected: keep-warm, critic agent, per-tool hooks, memory-file sprawl, Haiku.
Changes: `agent-briefs/DEV_LEAD_OPUS.md`, `agent-briefs/MERGE_CI_AGENT.md`.

## 2026-10-14 · D-070 · Director · The roadmap rewrite (board item 18, reshaped) is assigned to the Concept Lead
Why: director, 2026-10-14, after the horizontal-slice interview. Done in #74.
Changes: `docs/08_ROADMAP.md`.

## 2026-10-14 · D-069 · Director · Phase 9 (vertical slice and success test) stays as the depth gate after the horizontal slice
Why: the old Phases 2 to 7 are depth passes after Phase 2, in the order the director sets at the Phase 2 gate.
Changes: `docs/08_ROADMAP.md`.

## 2026-10-14 · D-068 · Director · No art credits spent this session (2026-10-14)
Why: content and architecture first.

## 2026-10-14 · D-067 · Director · Left out of the baseline: promotion lines and stage looks; trade, crafting, gladiator events; weather, rain and night; portraits and the final UI

## 2026-10-14 · D-066 · Director · Phase 2 caps
Why: 6 mercs at stage 1; one region, one hub, two or three hamlets, two or three procedural sites, two factions; wages and supplies as drain, contracts and loot (coin, supplies, generic equipment equipped for stats in a few slots, sprite and portrait unchanged) as income, amending the vision's "no general gear is shared between mercs" while the look rule holds; combat skeleton plus one terrain feature; the whole injury ladder, one of each, triage, death, chronicle; hire at the hub plus one prisoner choice (release, ransom, execute, recruit), captain's office and succession; one storylet plus the memory system; a player-effect fixture is the entry condition of every milestone.
Changes: `docs/08_ROADMAP.md` Phase 2, `docs/00_VISION.md` gear-line bullet, Q18, Q21, Q22.

## 2026-10-14 · D-065 · Director · Phase 2 starts now on placeholder sprites, in parallel with Phase 1; the look gate is signed when art lands
Why: the cast is not needed to prove structure. Amends the roadmap's phase-order rule for Phase 1 only.

## 2026-10-14 · D-064 · Director · One breadth phase (Phase 2) replaces the sequential proofs
Why: dependency order; the director plays each milestone build and says carry on or wrong; one formal gate at the end (structural audit plus one play). Seams (save, tick, schemas, sim boundary) are only tested when every system talks to the others.
Changes: `docs/08_ROADMAP.md` Phase 2; old Phases 2 to 7 become depth passes 3 to 8.

## 2026-10-14 · D-063 · Director · Two goals: the vertical slice (the look) short term; the horizontal slice (a playable baseline, structurally sound, thin, not visually complete) medium term
Why: "a playable baseline of the game ... structurally sound for us to build on".
Changes: `docs/08_ROADMAP.md` shape.

## 2026-10-09 · D-062 · Director · Permanent injuries are considered for all spritework
Why: director: "permanent injuries must be considered for all spritework". Injuries are separate layers on every stage, facing and clip.
Changes: the sprite contract (Art, P1-ART-SLICE-CAST).

## 2026-10-09 · D-061 · Director · Gear visibility: the sprite changes only at promotion, plus one signature piece
Why: director: "Sprite changes only at promotion, plus one signature piece". Relayed by the Lead from Art's session.
Changes: gear lines (D-053) show on the sprite per stage only.

## 2026-10-09 · D-060 · Director (relayed, PENDING the director's written confirmation) · Tripo may be used for any part, characters included; the ask threshold would rise from 500 to 2,000 credits per session
Why: director, relayed by the Lead from Art's session: "we can always get more Tripo credits. Use it whenever it would achieve the most beautiful and functional result". Inputs stay ours (blockouts and text, never diffusion images). Buying credits still needs a written yes (hard rule 8). Because this loosens a spend rule, the 500-credit threshold in D-014 and `CLAUDE.md` stays in force until the director confirms this entry in writing. The licensing register row is widened in Art's first PR.
Changes: amends D-014 once confirmed.

## 2026-10-09 · D-059 · Director · Art route A: one skeleton contract with per-merc bone lengths; one body per merc kept across its 3 stages; a gear kit per stage
Why: director: "go with option A" (P1-ART-REFOCUS). Retarget, clips, pixelate, palette, normals, packing and validators carry over; `build_body.py`, the 3 builds and shared equipment are retired. Supersedes D-002 fully.
Changes: art pipeline (Art, P1-ART-SLICE-CAST).

## 2026-10-09 · D-058 · Director · Economy
Upkeep is in and streamlined; contracts, trade, crafting, gladiator events, looting and banditry should all be viable income.
Changes: `00_VISION.md` and `CLAUDE.md` (#63).

## 2026-10-09 · D-057 · Director · Role counters
No type chart; counters come from combat roles; every merc has themed resolve; psychological warfare is a major theme.
Changes: `00_VISION.md` and `CLAUDE.md` (#63).

## 2026-10-09 · D-056 · Director · Downed survival
Any merc can survive being downed; injuries and permanent injuries apply.
Changes: `00_VISION.md` and `CLAUDE.md` (#63).

## 2026-10-09 · D-055 · Director · Returning playstyle (hard rule 5)
A dead merc stays dead. Their playstyle may return as a new, different-looking person with a fresh history. This is not a resurrection.
Changes: `00_VISION.md` and `CLAUDE.md` (#63).

## 2026-10-09 · D-054 · Director · Movesets
Moves are learnt at set levels; up to 4 are taken into battle (Q17 is how they change).
Changes: `00_VISION.md` and `CLAUDE.md` (#63).

## 2026-10-09 · D-053 · Director · Gear lines
Each merc has their own gear line; no general gear is shared between mercs.
Changes: `00_VISION.md` and `CLAUDE.md` (#63).

## 2026-10-09 · D-052 · Director · Promotion lines
Three-stage line per merc (two promotions), one experience bar fed by combat and story; promotion raises wages and abilities; promoted looks stay recognisable.
Changes: `00_VISION.md` and `CLAUDE.md` (#63).

## 2026-10-09 · D-051 · Director · Art refocus
The art pipeline is interrupted. Base-body, build, socket and shared-equipment work stops. Camera, light, pixel post, palette, packing and validators stand; the rule that diffusion never produces a sprite frame stands. Supersedes D-002 and the vision's "3D source characters" override. P1-ART-REFOCUS is assigned.
Changes: `00_VISION.md` and `CLAUDE.md` (#63).

## 2026-10-09 · D-050 · Director · CLAUDE.md wording
The `CLAUDE.md` Philosophy line now reads "makes one of the hand-made mercs more memorable".
Changes: `00_VISION.md` and `CLAUDE.md` (#63).

## 2026-10-09 · D-049 · Director · Tone
Grim, grounded feudal fantasy that contains magic. Non-humans such as orcs and vampyrs belong; tone and art direction make them fit. "Low fantasy" is withdrawn.
Changes: `00_VISION.md` and `CLAUDE.md` (#63).

## 2026-10-09 · D-048 · Director · Hand-made cast
25 hand-made mercs at launch, each a unique person with a strong visual and gameplay identity; no class labels; appearance shows abilities; no near-duplicates; no rarity tiers. Only the map layout is randomised (Battle Brothers-style). Supersedes the procedural recruit generation in Phase 2; `MercGen` does not start.
Changes: `00_VISION.md` and `CLAUDE.md` (#63).

## 2026-10-09 · D-047 · Director · Vision revision
The director replaces `00_VISION.md` with the hand-made-cast vision. The earlier procedural-recruit and low-fantasy framing misread the director's intent. Director, 2026-10-09: "the vision document is mistaken and misunderstood my intent, change it to our new vision"; "I never said the fantasy would be low, but it can still be grim and grounded and contain magic".
Changes: `00_VISION.md` and `CLAUDE.md` (#63).

## 2026-10-09 · D-046 · Lead (technical, same game) · Engine sprite sheets under `assets/sprites/` are plain git, not LFS; large binaries stay in LFS
Why: CI and the build check out without LFS, so LFS pointers were read as PNGs (#55's red CI). Sheets are small.
Changes: `.gitattributes`, `build.yml` comment (#56).

## 2026-10-09 · D-045 · Director · Sprites are rendered at a 45 degree sprite pitch inside the 55 degree world camera, at the same px per metre (about 82.27 px/m at 1x)
Why: chosen from labelled 4K street captures (Lead QC passed). The camera stays at 55 degrees (D-037).
Changes: `camera_rig.json`, `proportions.json` (#52); stage defaults (#57).

## 2026-10-09 · D-044 · Director · Merc pixel density is 84 px standing, on a 960x540 logical screen (x2 at 1080p, x4 at 4K); realistic proportions
Why: picked from the realistic density samples (B: 84 px) and the labelled street captures. Resolves D-042's open density; supersedes D-036 (56 px) and D-038 (proportion C).
Changes: rig freeze (#52); stage defaults (#57).

## 2026-10-09 · D-043 · Director · The Phase 1 gate is played in a playable "art direction slice" that includes a one-pass example of the core loop
Why: the director wants to test and assess the art direction before bulk assets and content. The question: "is this the look, and does it hold up in play?" Bulk assets and content wait for the gate. Lead note: the loop example is a sketch, shallow on systems and inside the hard rules; it does not pass the Phase 2 to 6 gates, which are still proved separately.
Changes: `docs/specs/art_direction_slice.md`, roadmap pointer (#51); slice M1 and M2 (#53, #54).

## 2026-10-09 · D-042 · Director · Proportion C is reversed: realistic proportions, a 4k pixel art look; pixel density stays open until the director picks from samples (density resolved by D-044)
Why: the director said "I don't like the big head, lets go for a realistic, 4k pixel art look." Supersedes D-038 (proportion C) and reopens D-036 (56 px standing height): the merc density candidates are 56, 84 or 112 px, picked from samples. D-037 (55 degree pitch) is not touched by this entry.
Changes: capture support `--logical=WxH` (#44); Art renders realistic density samples at 56 / 84 / 112 px; `06_STYLE_ART.md` follows the pick.

## 2026-10-08 · D-041 · Director · Authorisation: the Dev Lead may do what it thinks is best on making the re-rendered good fixture the stage's default merc
Why: the director said "go", then "do what you think is best" (recorded in #39). Scope is that item only; it is not a general authorisation for look or design calls.
Changes: captures default to the good sheet (#39).

## 2026-10-08 · D-040 · Lead (pending) · Sprites are camera-facing billboards, not Y-axis billboards
Why: upright Y billboards lean at the 55 degree pitch, which produces mixels (D-035).
Changes: the stage; `01_ENGINE_DECISION.md` (#36).

## 2026-10-08 · D-039 · Director · Testing cadence: major testing and audits only at milestones
Why: avoid heavy testing and audits between milestones. Per PR: run the existing suites and lints with one capture; new exhaustive suites, planted-defect rounds and audits wait for milestones. Narrows the amount of proof under `CLAUDE.md` rule 9, not the rule (#29; its suite was built before this).

## 2026-10-08 · D-038 · Director · Proportion is C pushed further, chosen as C: head 1.8x, hands 1.3x, thighs 0.85x, refit to 1.78 m (about 4.5 heads)
Why: chosen from `crop_p55_h56.png`; variant D (head 2.3x, about 3.5 heads) stays in the samples as the rejected option. Follow-up (needs assigning): freeze the look into the rig.
Changes: nothing yet (#28).

## 2026-10-08 · D-037 · Director · Game camera pitch is 55 degrees
Why: steep, as in the reference. `06_STYLE_ART.md` §3 and `camera_rig.json` (35 degrees, 48 px, 64 cell) change in a follow-up PR; spec §3's 30-40 degree range is superseded.
Changes: nothing yet (#28).

## 2026-10-08 · D-036 · Director · Standing figure height is 56 px at 1x
Why: chosen from review_p35/review_p55 and the 2x crops (#28).
Changes: nothing yet; rig follow-up.

## 2026-10-08 · D-035 · Director · Any art containing mixels is an automatic failure and must be fixed: one texel size per image or view
Why: director rule (#28). `contact_sheet.py` and the review sheets now draw text at the art's zoom; the 1x strip is a separate image.
Changes: `tools/pipeline/` (#28).

## 2026-10-08 · D-034 · Lead (pending) · Sprite normal maps: `normal_image`, camera-facing tangent space, OpenGL convention
Why: the factory and the engine must agree on one normal format (#26).
Changes: lit sprites, `stage_light` suite.

## 2026-10-08 · D-033 · Dev Lead as lead (pending) · The stage's rail distance is derived from pitch and figure height so one texel is one logical pixel at the look-at point
Why: a fixed rail stretched the sprite about 1.5x. Supersedes the spec's fixed 12 m rail and 160 x 90 crop; `docs/specs/phase1_visual_proof.md` §2 should say so (spec owner's edit).
Changes: `street_stage.gd`, `data/balance/stage.json` (#24).

## 2026-10-08 · D-032 · Director · Sprite scale is constant: one texel is one logical pixel anywhere; sprites never resample; distance shows by position
Why: answered from the sample set 2 depth sheet and clips.
Changes: stage default `depth_scale` (#25).

## 2026-10-08 · D-031 · Director · Pixel mode is A, whole screen: 640 x 360 SubViewport x3, sprites snapped
Why: answered from the sample set 2 pixel-mode sheet and clips.
Changes: node setup in `01_ENGINE_DECISION.md` (#25).

## 2026-10-08 · D-030 · Director · Merge & CI is autonomous for routine repository administration
Why: the director was being asked to run routine git and GitHub commands, and the merge brief contradicted itself on branch ownership, board commits and permissions, so a green, eligible PR (#19) sat unmerged. Rulings: (1) green + eligible = merge, without asking; (2) a routine git or GitHub permission refusal is a configuration bug fixed in `.claude/settings.json` by PR, never a command handed to the director; (3) the branch owner syncs and repairs their own branch, Merge & CI names the exact conflict once and never pushes to another agent's branch; (4) `docs/STATUS.md` and `docs/DECISIONS.md` change only through a docs-only board PR by Merge & CI after each merge (`main` is protected for admins too, so there is no direct commit); (5) GitHub settings match the docs: squash only, no merge commits, no rebase merges, no auto-merge; (6) routine merge-agent messages are one line. The director is reached only for look and design gates, spend, credentials and sign-ins, destructive recovery with real risk, permissions GitHub reserves for a human, and genuinely ambiguous policy.
Changes: `agent-briefs/MERGE_CI_AGENT.md` rewritten; `.claude/settings.json` (routine git allowed; force push, hard reset, forced branch deletion, admin merge and protection edits denied); `CLAUDE.md`; `03_TEAM_WORKFLOW.md`; `04_GUARDRAILS.md` C3, C5; `09_REPO_AND_HOSTING.md`; `mercs-pr`, `mercs-handoff`; PR template gains "Board and log". Amends D-021: a feature PR no longer writes `D-TBD` into `DECISIONS.md`; the decision text travels in the PR body.

## 2026-10-08 · D-029 · Director · The Art agent may drive mixamo.com in a browser session the director has signed in to
Why: fourteen Mixamo clips are needed for Phase 1 and the account is the director's. The agent never enters credentials; the director signs in, the agent downloads to `D:\MERCS-vault\clips`.
Changes: STATUS.md "Waiting on the director".

## 2026-10-08 · D-028 · Director · Mercs are men and women: two base bodies (male and female) share one skeleton
Why: recruits can be either; one skeleton keeps every clip shared. Logged after the merge of #13 (its body called it D-026, which was taken).
Changes: `tools/pipeline/bodies/bodies.json`. Phase 1 proves `average_m` first; `average_f` follows on the same skeleton. Every equipment piece is fit-checked on both bodies.

## 2026-10-08 · D-027 · Concept Lead · Phase 0 gate: PASS WITH NOTES
Why: 12 of 16 planted violations rejected by CI (PR #10); clean PR #11 green; build artefact launches. Four gaps (floor lowering, gitleaks test key, safetensors tripwire, file length) are machine-enforceable and become Phase 0 items 10–12 plus item 8, required before Phase 1 code merges. Full table in `docs/audits/phase0_gate_result.md`.
Changes: STATUS.md Phase 0 items 10–12 added; Art Factory may start Phase 1 rig freeze and samples now.

## 2026-10-08 · D-026 · Concept Lead · Only the Merge & CI agent edits STATUS.md and DECISIONS.md, in one commit to main after each merge
Why: seven first-day PRs all edited the same two files, causing conflicts, rebases and colliding decision ids; the director found the GitHub flow confusing. PRs now state board and log changes in a "Board and log" body section instead.
Changes: `CLAUDE.md`, `03_TEAM_WORKFLOW.md`, `HANDOFF_TEMPLATE.md`, `MERGE_CI_AGENT.md`; the merge agent needs a direct-push exception for those two files on `main` (branch protection currently requires a PR; the Merge & CI agent proposes the smallest change).

## 2026-10-08 · D-025 · Director · The player appoints the next captain and the company reacts (Q13)
Why: director's answer. Reaction scenes (one to three voices from traits and memories, with morale and loyalty consequences; an unpopular pick can cause a departure) are Phase 5 content; the appointment flag ships in Phase 2.
Changes: `08_ROADMAP.md` Phases 2, 4, 5; `data/balance/captaincy.json` when created.

Older entries (D-001 to D-024, 2026-10-08) are in `docs/archive/decisions_001_024.md`.
