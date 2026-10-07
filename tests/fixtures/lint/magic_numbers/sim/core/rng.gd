extends RefCounted
# The one sim file allowed raw numbers: generator constants are the algorithm, not balance.

const MULTIPLIER: int = 6364136223846793005
const INCREMENT: int = 1442695040888963407
const SHIFT: int = 33
const MASK: int = 0x7FFFFFFF
