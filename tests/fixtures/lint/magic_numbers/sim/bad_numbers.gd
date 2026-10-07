extends RefCounted
# Look-alikes that stay silent: 0, 1, -1 and 100 in every spelling, digits inside
# identifiers, numbers in comments (12 monkeys) and numbers inside strings.
# One planted violation per line, marked PLANT <RULE>.

const ZERO: int = 0
const ONE: int = 1
const MINUS_ONE: int = -1
const HUNDRED: int = 100
const MINUS_HUNDRED: int = -100
const ONE_F: float = 1.0
const ZERO_F: float = 0.0
const HUNDRED_F: float = 100.0
const HEX_ONE: int = 0x01
const BIN_ZERO: int = 0b0
const UNDERSCORED: int = 1_00
const EXPONENT_HUNDRED: float = 1e2
const PLUS_ONE: int = +1
var vector2_count: int = 0
var node_3d: int = 1
var grid: Vector2i = Vector2i(0, 1)
var label: String = "12 monkeys and 3.5 apples, 0xFF, 1e9"
var wrapped: int = vector2_count % 100

const BAD_INT: int = 12  # PLANT MAGIC-NUMBER
const BAD_FLOAT: float = 0.35  # PLANT MAGIC-NUMBER
const BAD_NEGATIVE: int = -7  # PLANT MAGIC-NUMBER
const BAD_HEX: int = 0xFF  # PLANT MAGIC-NUMBER
const BAD_BINARY: int = 0b1010  # PLANT MAGIC-NUMBER
const BAD_UNDERSCORE: int = 1_000  # PLANT MAGIC-NUMBER
const BAD_EXPONENT: float = 2.5e-3  # PLANT MAGIC-NUMBER
const BAD_LEADING_DOT: float = .5  # PLANT MAGIC-NUMBER
const BAD_TRAILING_DOT: float = 5.  # PLANT MAGIC-NUMBER
var table: Array = [0, 1, 2]  # PLANT MAGIC-NUMBER
var after_hash: String = "x#" + str(9)  # PLANT MAGIC-NUMBER

const DOC: String = """
Number 42 inside a doc string is not code.
"""
var after_doc: int = 7  # PLANT MAGIC-NUMBER


func scale(value: int) -> int:
	return value * 3 / 2  # PLANT MAGIC-NUMBER
