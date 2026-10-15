class_name HubPanel
extends PanelContainer
## The hub's grey-box panel (Phase 2 milestone 6; final UI is out of the baseline, D-067):
## two columns of rows, each row a line of words or a button. It holds no player text and no
## rule of its own: HubDirector words everything (Text.t) and hands over the rows. A pressed
## button emits acted(action, id). Rows: {"kind": "label"|"button", "text", "action", "id",
## "enabled"}; a button is named "<action>_<id>" so a test finds it.

signal acted(action: String, id: String)

const MARGIN_PX := 12
const ROW_GAP_PX := 6
const WIDTH_SHARE := 0.66
const HEIGHT_SHARE := 0.94
const LABEL := "label"
const BUTTON := "button"

var _left := VBoxContainer.new()
var _right := VBoxContainer.new()
var _scroll := ScrollContainer.new()


func _ready() -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", MARGIN_PX * 2)
	for column: VBoxContainer in [_left, _right]:
		column.add_theme_constant_override(&"separation", ROW_GAP_PX)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(column)
	_scroll.add_child(columns)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_scroll)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Shows the two columns of rows (see the class comment).
func show_rows(left: Array[Dictionary], right: Array[Dictionary]) -> void:
	_fill(_left, left)
	_fill(_right, right)
	visible = true
	_fit()


## The button for an action and id, or null.
func button_for(action: String, id: String) -> Button:
	for column: VBoxContainer in [_left, _right]:
		var found := column.get_node_or_null(NodePath("%s_%s" % [action, id])) as Button
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
		if row.get("kind") == BUTTON:
			column.add_child(_button(row))
		else:
			var label := Label.new()
			label.text = str(row.get("text", ""))
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			column.add_child(label)


func _button(row: Dictionary) -> Button:
	var button := Button.new()
	var action := str(row.get("action", ""))
	var id := str(row.get("id", ""))
	button.name = "%s_%s" % [action, id]
	button.text = str(row.get("text", ""))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
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
