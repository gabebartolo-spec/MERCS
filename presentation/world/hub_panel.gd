class_name HubPanel
extends PanelContainer
## The hub's panel (Phase 2 milestone 6; Phase 5 C8 sets it in MERCS Ledger, D-092, in look B's
## soot and bone from the palette roles): two columns of rows, each row a line of words, a
## heading, a button or a line of buttons. It holds no player text and no rule of its own:
## HubDirector and TermsPanel word everything (Text.t) and hand over the rows. A pressed button
## emits acted(action, id). Rows: {"kind": "label"|"heading"|"note"|"button"|"buttons", "text",
## "action", "id", "enabled"}; "buttons" holds its buttons' rows in "items", side by side. A
## button is named "<action>_<id>" so a test finds it.

signal acted(action: String, id: String)

const MARGIN_PX := 12
const ROW_GAP_PX := 6
const WIDTH_SHARE := 0.66
const HEIGHT_SHARE := 0.94
const LABEL := "label"
## A heading: the Display cut of the face, larger.
const HEADING := "heading"
## A quieter line (why a number is what it is): the dim text role.
const NOTE := "note"
const BUTTON := "button"
const BUTTONS := "buttons"
## MERCS Ledger (#116): a 14 px em drawn on whole pixels, so it is set at multiples of 14.
const REGULAR_FONT := "res://assets/fonts/MERCSLedger-Regular.ttf"
const DISPLAY_FONT := "res://assets/fonts/MERCSLedger-Display.ttf"
const BODY_PX := 28
const HEADING_PX := 42

var _left := VBoxContainer.new()
var _right := VBoxContainer.new()
var _scroll := ScrollContainer.new()
var _display: Font = null


func _ready() -> void:
	theme = ledger_theme()
	_display = load(DISPLAY_FONT) as Font
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", MARGIN_PX * 2)
	for column: VBoxContainer in [_left, _right]:
		column.add_theme_constant_override(&"separation", ROW_GAP_PX)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(column)
	var inset := MarginContainer.new()
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		inset.add_theme_constant_override(side, MARGIN_PX)
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_child(columns)
	_scroll.add_child(inset)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_scroll)
	mouse_filter = Control.MOUSE_FILTER_STOP


## The hub's theme: the Ledger Regular cut at body size over the project theme's look B colours.
static func ledger_theme() -> Theme:
	var ledger := Theme.new()
	ledger.default_font = load(REGULAR_FONT) as Font
	ledger.default_font_size = BODY_PX
	return ledger


## A row of words of this kind (LABEL, HEADING or NOTE).
static func line(kind: String, text: String) -> Dictionary:
	return {"kind": kind, "text": text}


## A button row.
static func button_row(action: String, id: String, text: String, enabled: bool) -> Dictionary:
	return {"kind": BUTTON, "action": action, "id": id, "text": text, "enabled": enabled}


## Shows the two columns of rows (see the class comment).
func show_rows(left: Array[Dictionary], right: Array[Dictionary]) -> void:
	_fill(_left, left)
	_fill(_right, right)
	visible = true
	_fit()


## The button for an action and id, or null.
func button_for(action: String, id: String) -> Button:
	for column: VBoxContainer in [_left, _right]:
		var found := column.find_child("%s_%s" % [action, id], true, false) as Button
		if found != null and not found.is_queued_for_deletion():
			return found
	return null


## Every label's words, one per line (what a player reads).
func shown_text() -> String:
	var lines: Array[String] = []
	for column: VBoxContainer in [_left, _right]:
		for node: Node in column.get_children():
			if node is Label and not node.is_queued_for_deletion():
				lines.append((node as Label).text)
	return "\n".join(lines)


func _fill(column: VBoxContainer, rows: Array[Dictionary]) -> void:
	for old: Node in column.get_children():
		column.remove_child(old)
		old.queue_free()
	for row: Dictionary in rows:
		match str(row.get("kind", LABEL)):
			BUTTON:
				column.add_child(_button(row))
			BUTTONS:
				column.add_child(_button_line(row))
			_:
				column.add_child(_label(row))


func _label(row: Dictionary) -> Label:
	var label := Label.new()
	label.text = str(row.get("text", ""))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	match str(row.get("kind", LABEL)):
		HEADING:
			label.add_theme_font_override(&"font", _display)
			label.add_theme_font_size_override(&"font_size", HEADING_PX)
		NOTE:
			label.add_theme_color_override(&"font_color", Palette.role("text_dim"))
	return label


func _button_line(row: Dictionary) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", MARGIN_PX)
	var items: Variant = row.get("items", [])
	if items is Array:
		for item: Variant in items:
			if item is Dictionary:
				var entry: Dictionary = item
				var button := _button(entry)
				button.autowrap_mode = TextServer.AUTOWRAP_OFF
				line.add_child(button)
	return line


func _button(row: Dictionary) -> Button:
	var button := Button.new()
	var action := str(row.get("action", ""))
	var id := str(row.get("id", ""))
	button.name = "%s_%s" % [action, id]
	button.text = str(row.get("text", ""))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.disabled = row.get("enabled", true) != true
	button.pressed.connect(acted.emit.bind(action, id))
	return button


func _fit() -> void:
	var view := get_viewport_rect().size
	var column_width := view.x * WIDTH_SHARE / 2.0 - MARGIN_PX * 3
	_left.custom_minimum_size = Vector2(column_width, 0.0)
	_right.custom_minimum_size = Vector2(column_width, 0.0)
	_scroll.custom_minimum_size = Vector2(view.x * WIDTH_SHARE, view.y * HEIGHT_SHARE)
	reset_size()
	position = Vector2(MARGIN_PX, MARGIN_PX)
