# economy.json — purse, wages, morale, contracts, loot, hiring, the prisoner

One line per knob (docs/05_STYLE_CODE.md "Data"). Read by `sim/economy/` (Phase 2 M6). First numbers; the director tunes them.

## purse
- `start`: the coin the company begins with.

## wages
- `day_by_level`: a mercenary's wage for one day, by his level (first entry level 1; past the end, the last entry). Owed for each mercenary on the roster, every day that ticks (Phase 5 C3, director Q-5: the daily wage is by level). Placeholder numbers.
- `share_pct`: percent of a completed contract's pay owed to the mercs who fought the job, split by level (each cut weighted by his level, rounded down; director Q-3, Q-4). Owed with the wages: a share left unpaid counts as owed wages and costs morale the same way. Placeholder number.
- `grace_days`: days without paying (wages or share) that cost nothing; the day after, morale starts to fall.
- `morale_loss_per_day`: morale lost on each day past the grace while wages stand unpaid.
- `paid_recovery`: morale regained each time the whole debt is paid.

## morale
- `start`: the company's morale at the first day.
- `max`: the ceiling (a floor of 0 is fixed).

## contracts
- `board_min`, `board_max`: how many contracts the hub posts at a time.
- `refresh_days`: days between fresh boards (accepted contracts stay).
- `deadline_min`, `deadline_max`: days a contract gives, counted from posting.
- `reward_min`, `reward_max`: the coin a contract pays.

## loot (by the encounter's type, as in world.json "encounters")
- `coin_min`, `coin_max`: coin looted from a won fight.
- `item_chance`: percent chance of one generic item from `data/equipment.json`.

## recruits
- `offers`: how many unhired recruits the hub shows.
- `cost`: coin to hire one.

## prisoner (the company's reaction to each choice)
- `ransom_coin`: coin a ransom brings.
- `release_morale`, `ransom_morale`, `execute_morale`, `recruit_morale`: morale change for each choice.

## standing (Phase 5 C4: the name with each faction and the grudges; director Q-7, Q-13, Q-15, Q-16)
- `start`: the company's name with a faction it has not yet dealt with.
- `min`, `max`: the floor and ceiling of a name.
- `complete_mend`: name gained with a faction when one of its contracts is completed.
- `fail_dent`: name lost when a contract fails honestly (the job was lost, not walked from).
- `walk_dent`: name lost when an employer walks from an ask pushed too far (C2's terms).
- `abandon_dent`: name lost when the company abandons a contract it took.
- `sizeable_advance`: percent of a contract's pay taken up front at or above which abandoning it grows a grudge (director: "half the pay or more", Q-16).
- `grudge_growth`: how much a faction's grudge grows for each such deal; the hunters it sends grow with it (Q-15).

## terms (Phase 5 C2: the ask, the employer's reply, the step-in; placeholder numbers, whole numbers)
- `base_limit_pct`: the most any employer gives, in percent of the posted reward, before his regard and need.
- `reputation_weight_pct`: percent of the company's name with the faction (standing `min` to `max`) added to his limit.
- `need_weight_pct`: percent of the faction's pressure (data/factions.json) added to his limit.
- `advance_cost_pct`: how much each coin of advance weighs against his limit, in percent of a coin paid on return.
- `counter_band_pct`: how far past his limit (percent of the reward) an ask still gets a counter; beyond it he walks.
- `die_sides`: the step-in check's die.
- `step_in_difficulty`: the step-in succeeds when the roll plus the merc's bargaining reaches this.
- `step_in_shift_pct`: how far a step-in moves the employer's limit (up on success, down on failure), in percent of the reward.
