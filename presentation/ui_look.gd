class_name UiLook
extends RefCounted
## Paints the project theme (ui/theme/base_theme.tres) in look B: soot panels and buttons, bone
## text, a gold bar. Colours come from Palette roles (data/balance/look_ui.json); sizes, margins
## and the font size are left as they are (each box is the default theme's, recoloured), so no
## layout moves. Presentation only; call apply() once when the game starts.

const BUTTON_STATES: Array[String] = ["normal", "hover", "pressed", "disabled", "focus"]
const BUTTON_ROLES: Dictionary = {
	"normal": "button_back",
	"hover": "button_hover",
	"pressed": "button_pressed",
	"disabled": "button_disabled"
}
const TEXT_ROLES: Dictionary = {
	"font_color": "button_text",
	"font_hover_color": "button_text_hover",
	"font_pressed_color": "button_text_pressed",
	"font_hover_pressed_color": "button_text_hover",
	"font_focus_color": "button_text",
	"font_disabled_color": "button_text_disabled"
}


## Recolours `theme` (the project theme when null). True when there was a theme to paint.
static func apply(theme: Theme = null) -> bool:
	var target := theme if theme != null else ThemeDB.get_project_theme()
	if target == null:
		return false
	var fallback := ThemeDB.get_default_theme()
	var panel := _flat(fallback, &"PanelContainer", "panel", "panel_back")
	target.set_stylebox(&"panel", &"PanelContainer", panel)
	target.set_stylebox(&"panel", &"Panel", panel)
	for state: String in BUTTON_STATES:
		target.set_stylebox(StringName(state), &"Button", _button_box(fallback, state))
	for key: String in TEXT_ROLES:
		target.set_color(StringName(key), &"Button", Palette.role(str(TEXT_ROLES[key])))
	target.set_color(&"font_color", &"Label", Palette.role("text"))
	target.set_color(&"font_outline_color", &"Label", Palette.role("text_outline"))
	target.set_stylebox(
		&"background", &"ProgressBar", _flat(fallback, &"ProgressBar", "background", "bar_back")
	)
	target.set_stylebox(
		&"fill", &"ProgressBar", _flat(fallback, &"ProgressBar", "fill", "bar_fill")
	)
	target.set_color(&"font_color", &"ProgressBar", Palette.role("text"))
	target.set_color(&"font_outline_color", &"ProgressBar", Palette.role("text_outline"))
	return true


## The outline width a label drawn straight on the world takes (data "outline_px").
static func outline_px() -> int:
	var width: int = Palette.look().get("outline_px", 0)
	return width


## Gives a label the soot outline that keeps bone text readable on any ground.
static func outlined(label: Label) -> void:
	label.add_theme_constant_override(&"outline_size", outline_px())
	label.add_theme_color_override(&"font_outline_color", Palette.role("text_outline"))


static func _button_box(fallback: Theme, state: String) -> StyleBox:
	if state == "focus":
		var ring := _flat(fallback, &"Button", state, "button_focus")
		ring.bg_color = Palette.CLEAR
		ring.draw_center = false
		ring.border_color = Palette.role("button_focus")
		return ring
	return _flat(fallback, &"Button", state, str(BUTTON_ROLES[state]))


## The default theme's box for this control and slot, as a flat box recoloured to a role: its
## margins and corner shape are kept, so nothing moves.
static func _flat(
	fallback: Theme, type: StringName, slot: String, role_name: String
) -> StyleBoxFlat:
	var source := fallback.get_stylebox(StringName(slot), type)
	var box := source.duplicate() as StyleBoxFlat
	if box == null:
		box = StyleBoxFlat.new()
	box.bg_color = Palette.role(role_name)
	box.border_color = Palette.role("panel_edge")
	box.shadow_color = Palette.CLEAR
	return box
