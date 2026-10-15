class_name CompanyPanel
extends PanelContainer
## The thin inspect screen's grey-box panel (Phase 2 milestone 3; final UI is out of the
## baseline, D-067): the roster as a column of buttons on the left, the picked merc's
## details on the right (a header, lines of words, the experience bar) and one button to give
## them the captain's office. It holds no player text of its own: CompanyDirector words
## everything (Text.t, data/mercs.json) and hands it over. Pressing a roster row emits
## picked(id), the office button appoint_requested(id).

signal picked(merc_id: String)
signal appoint_requested(merc_id: String)

const MARGIN_PX := 12
const WIDTH_SHARE := 0.55
const ROSTER_WIDTH_SHARE := 0.2
const ROW_PREFIX := &"Merc_"
const APPOINT_NAME := &"Appoint"

var _title := Label.new()
var _rows := VBoxContainer.new()
var _header := Label.new()
var _lines := Label.new()
var _bar := ProgressBar.new()
var _bar_text := Label.new()
var _appoint := Button.new()
var _shown := ""


func _ready() -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", MARGIN_PX)
	add_child(columns)
	var left := VBoxContainer.new()
	left.add_theme_constant_override(&"separation", MARGIN_PX)
	left.add_child(_title)
	left.add_child(_rows)
	columns.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override(&"separation", MARGIN_PX)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bar.show_percentage = false
	_appoint.name = String(APPOINT_NAME)
	_appoint.pressed.connect(func() -> void: appoint_requested.emit(_shown))
	for node: Control in [_header, _lines, _bar, _bar_text, _appoint]:
		right.add_child(node)
	columns.add_child(right)
	mouse_filter = Control.MOUSE_FILTER_STOP


## The title and the roster rows: [{"id": String, "label": String}], in order.
func show_roster(title: String, rows: Array[Dictionary]) -> void:
	_title.text = title
	for old: Node in _rows.get_children():
		_rows.remove_child(old)
		old.queue_free()
	for row: Dictionary in rows:
		var button := Button.new()
		var merc_id := str(row.get("id", ""))
		button.name = String(ROW_PREFIX) + merc_id
		button.text = str(row.get("label", ""))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(picked.emit.bind(merc_id))
		_rows.add_child(button)
	visible = true
	_fit()


## The picked merc, already worded: {"id", "header", "lines": Array[String], "bar_value",
## "bar_max", "bar_text", "appoint_label" ("" hides the button)}.
func show_detail(detail: Dictionary) -> void:
	_shown = str(detail.get("id", ""))
	_header.text = str(detail.get("header", ""))
	var lines: Array = detail.get("lines", [])
	_lines.text = "\n".join(lines.map(func(line: Variant) -> String: return str(line)))
	_bar.max_value = float(Merc.whole(detail.get("bar_max", 0)))
	_bar.value = float(Merc.whole(detail.get("bar_value", 0)))
	_bar_text.text = str(detail.get("bar_text", ""))
	var label := str(detail.get("appoint_label", ""))
	_appoint.text = label
	_appoint.visible = label != ""
	_fit()


## The merc whose details are on show ("" before a pick).
func shown_id() -> String:
	return _shown


func row_for(merc_id: String) -> Button:
	return _rows.get_node_or_null(NodePath(String(ROW_PREFIX) + merc_id)) as Button


func appoint_button() -> Button:
	return _appoint


func bar() -> ProgressBar:
	return _bar


func header_text() -> String:
	return _header.text


func lines_text() -> String:
	return _lines.text


func _fit() -> void:
	var view := get_viewport_rect().size
	custom_minimum_size = Vector2(view.x * WIDTH_SHARE, 0.0)
	_rows.custom_minimum_size = Vector2(view.x * ROSTER_WIDTH_SHARE, 0.0)
	reset_size()
	position = Vector2(MARGIN_PX, MARGIN_PX)
