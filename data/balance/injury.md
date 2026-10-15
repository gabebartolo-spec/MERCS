# injury.json - wounds, triage, death, succession knobs

One line per knob (docs/05_STYLE_CODE.md "Data"). Read by `sim/merc/` (Phase 2 M5). First thin pass; the lead tunes.

## triage
Each downed merc is resolved by one roll of 1..`die_sides` on the Rng "injury" stream. A roll up to `wound_upto` is a wound (back on their feet), up to `temporary_upto` a temporary injury, up to `permanent_upto` a permanent injury; anything higher is death (final).
- `die_sides`: the die the triage rolls.
- `wound_upto`: highest roll that is only a wound.
- `temporary_upto`: highest roll that is a temporary injury.
- `permanent_upto`: highest roll that is a permanent injury; above it the merc dies.

## succession
The living comrades ranked by resolve (ties by id), best first.
- `successor_rank`: the rank that becomes captain when the captain dies (0 is the highest resolve).
- `dissent_rank`: the rank of the one comrade who voices dissent (1 is the runner-up).
