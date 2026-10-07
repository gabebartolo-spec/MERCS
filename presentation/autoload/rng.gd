extends Node
## Rng autoload: will hand out the named random streams (battle, world, merc_gen),
## each derived from the save's seed and a counter held in the save (05_STYLE_CODE.md
## "Randomness"). Empty in Phase 0. sim/ never calls an autoload: a stream reaches sim
## code as an argument.
