# 11 — Open questions for the director

Phrased per the question protocol: one decision each, the recommended option first, the game
impact in plain words. Visual questions (Q4–Q9) will be re-asked by the Art agent with labelled
images in Phase 1; they are listed here so the director knows they are coming. Answers go into
`DECISIONS.md`.

## Answered 2026-10-08 (kept for the record; decisions D-010..D-015)

Q1 PC first. Q2 private, yes. Q3 squares. Q10 twelve, agreed. Q11 Tripo has 25,000 credits;
ask before spending more than 500 in a session; other spend still needs a yes. Q12 delete, yes.

## Decisions needed before Phase 0 starts (answered above)

**Q1. Platform.** Is MERCS a PC game played with mouse and keyboard on a monitor?
- **Yes, PC first (recommended).** The UI can use hover, right-click inspect and dense-but-readable
  battle information. Steam is the store.
- PC and Steam Deck. Adds controller navigation to every screen from day one; small cost now,
  large later.
- Mobile too. Changes the UI rules, the pixel scale and the battle layout. Not recommended for
  this design.

**Q2. Repo privacy.** May the Merge & CI agent make `gabebartolo-spec/MERCS` private now?
- **Yes (recommended).** Design docs and generated assets of a commercial game stay out of
  public view.
- No, keep it public. Then nothing commercially sensitive or licence-bound goes in it.

**Q3. Battle grid.** Squares or hexes?
- **Squares, eight directions (recommended).** One set of sprite facings serves exploring and
  fighting; diagonal movement and flanking still exist. Combat looks like the overworld.
- Hexes. Prettier for tactics and no diagonal ambiguity, but needs six extra facings rendered for
  every equipment layer (about 75 % more sprite work) or a visible mismatch between how a merc
  stands in town and in battle.

**Q10. Roster size in the slice.** Six deployed plus six reserve (twelve total)?
- **Twelve (recommended).** Every death matters; the inspect screen stays personal.
- Larger reserve. Softens permadeath, which weakens the core fantasy; the brief warned against it.

**Q11. Money for tools.** Are you willing to consider any of the following if the team shows a
measured need, or should they be treated as unavailable for planning purposes?
- Tripo paid tier (removes attribution and grants full rights to generated props).
- A cloud GPU hour here and there for LoRA training if 12 GB proves too tight.
- GitHub LFS overage if committed binaries pass 10 GiB.
The pack assumes **none of these** until you say otherwise.

**Q12. Disk cleanup.** May the Art agent delete the banned Qwen-Image 2.1 files (27 GB) and
Realistic Vision (2 GB), and may the four unused Unity installs be removed to recover space on
C:? Nothing is deleted without this answer.

## Visual decisions the Art agent will bring with labelled images in Phase 1

**Q4. Camera pitch.** 30° / 35° / 40° down. Lower feels like Pokémon town streets and shows more
building faces; higher reads the battle grid more clearly. Recommendation: 35°.

**Q5. Character height on screen.** 40 / 48 / 56 pixels for an average man at 1×. Smaller shows
more of the street and more fighters; larger shows scars, heraldry and equipment detail.
Recommendation: 48.

**Q6. Pixel mode.** Whole screen pixelated (everything crunchy and unified, like Octopath) or crisp
3D world with pixel characters (sharper buildings, characters stand out as "the art"). Both are
authentic; they feel different. Recommendation: whole screen, because it hides seams between 3D
and sprites and is cheaper to keep consistent.

**Q7. Palette size.** 48 or 64 colours. Fewer colours is a stronger identity and easier
consistency; more gives skin and cloth subtlety. Recommendation: 56.

**Q8. Portrait style.** Pixelated portraits (same material as the sprites) or painterly portraits
(the close-up payoff is richer, but they can clash with the world). Recommendation: pixelated at
256×320, because consistency is the whole battle.

**Q9. Fonts.** Two OFL faces from a labelled sheet: one for UI, one serif for names and titles.

## Added 2026-10-08 from the Three Pillars brief — answered the same day

Q13: you appoint, the company reacts (D-025). Q14: inherit a small company with a
sitting captain (D-024). Kept below for the record.

**Q13. How is the next captain chosen when the captain dies or steps down?**
- **You appoint, the company reacts (Recommended).** You pick any living member; one to three
  mercenaries object or approve from their traits and memories, with real morale and loyalty
  consequences, and an unpopular choice can cause a departure. Cost: the reaction scenes are
  Phase 5 content.
- Seniority or rank decides automatically. Cheapest; removes a decision you would enjoy.
- The company votes. Dramatic, but you lose control of your own company at its worst moment.
- No answer: the Dev Lead builds "you appoint" behind a data flag in Phase 2; reactions land in
  Phase 5.

**Q14. Does the campaign start with a company you inherit, or with a captain you create?**
- **Inherit a small company with a sitting captain (Recommended).** You get people and their
  history from day one, and the first death can be the captain's. Cost: a short authored opening.
- Create the captain. Stronger ownership, but it quietly recreates a protagonist the player will
  never risk.

## Raised by the vision revision (director, 2026-10-09)

From `docs/brainstorms/2026-10-09-merc-roster.md`. Where the director stated a lean it is listed
first; otherwise the Concept Lead adds a recommendation before the question is asked.

**Q15. Sandbox or guided story?** Leaning: a sandbox campaign with large crises, like Battle
Brothers, where the story emerges from play and feels unique to each run. Alternative: a guided
narrative spine with sandbox stretches.

**Q16. Does the Vampyr get a last-ditch escape** (bat or shadow form to dodge a killing blow)?
Director: only if it is thematic, true to his identity, and proves balanced and fun. Options:
his own version of surviving being downed; a separate move; cut.

**Q17. How is a moveset changed** outside level-ups? Trainers, potions, or another in-game
mechanism.

**Q18. Which income systems ship first?** Contracts, trade, crafting, gladiator events, looting
and banditry are all wanted; each needs its own rules, UI and balancing.

**Q19. How do earned epithets and identity branches (One-Eye, Oathbreaker) sit alongside the
fixed three-stage promotion line?** Branches inside a stage, cosmetic and storylet-only, or
replaced by the promotion line.

**Q20. What sits beside the four learnt moves in battle?** Basic weapon actions, an item slot, or
nothing. And does equipment physics (plate resists cuts, axes break shields) still apply inside
each merc's gear line?

**Q21. With a fixed cast of 25, how does recruitment stay a discovery, and where do prisoners
fit?** Phase 6 currently recruits surrendered enemies and Phase 7 has regional recruitment pools.
Options include: cast members can appear as enemies and be won over; cast members are found in
the world (taverns, story gates); captured enemies are ransomed or released but never recruited.

**Q22. How many of the 25 are in the vertical slice?** The slice roster cap is 12. Art cost is
about 3 stage looks per merc plus personal-detail variants for a returning playstyle.

## Design questions the Dev Lead will raise during their phases

- Phase 3: how much of the enemy's equipment should be visible before a fight begins (it changes
  how much planning is possible)?
- Phase 4: should a surgeon's failed roll be able to kill (harsher, more memorable) or only maim?
- Phase 5: do storylets pause the game as a full-screen scene, or play in a side panel while the
  camp is visible?
- Phase 7: do contracts show their simulated cause ("the mine dispute") on the board, or does the
  player discover it?
