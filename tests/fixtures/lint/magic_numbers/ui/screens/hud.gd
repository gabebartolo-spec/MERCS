extends Control
# One planted violation per line, marked PLANT <RULE>. Gate item: literal colour in UI.
# Look-alikes: Color(1, 0, 0) in a comment, colour names as types, the kit's own accessors.

var rect: ColorRect = null
var kit_ink: Color = UiKit.INK
var palette: ColorPalette = null
var as_text: String = "Color(1, 0, 0) is only a word here"
var not_hex_word: String = "decade"
var not_hex_short: String = "#12"
var not_hex_five: String = "#12345"
var not_hex_letters: String = "#ggg"
var not_hex_seven: String = "1234567"
var path: String = "res://ui/screens/hud.tscn"

var plain_ctor: Color = Color(1, 0, 0)  # PLANT COLOUR-LITERAL
var bytes_ctor: Color = Color8(255, 0, 0)  # PLANT COLOUR-LITERAL
var named: Color = Color.RED  # PLANT COLOUR-LITERAL
var html_ctor: Color = Color.html("zz")  # PLANT COLOUR-LITERAL
var hsv_ctor: Color = Color.from_hsv(0.5, 0.5, 0.5)  # PLANT COLOUR-LITERAL
var hex_three: String = "#fff"  # PLANT COLOUR-LITERAL
var hex_four: String = "#ffff"  # PLANT COLOUR-LITERAL
var hex_six: String = "#a1b2c3"  # PLANT COLOUR-LITERAL
var hex_eight: String = "#a1b2c3d4"  # PLANT COLOUR-LITERAL
var bare_six: String = "a1b2c3"  # PLANT COLOUR-LITERAL
var bare_eight: String = "a1b2c3d4"  # PLANT COLOUR-LITERAL
var single_quoted: String = '#CC3322'  # PLANT COLOUR-LITERAL
var spaced_ctor: Color = Color (0.2, 0.2, 0.2)  # PLANT COLOUR-LITERAL
var after_hash: String = "k#" + "#00ff00"  # PLANT COLOUR-LITERAL
