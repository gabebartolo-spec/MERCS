class_name LoopPanel
extends PanelContainer
## The grey-box panel the slice's loop example speaks through (docs/specs/art_direction_slice.md
## §2a: UI is grey-box panels, judged only for legibility and fit). A title, a body and one
## button per choice; pressing a button emits chosen(id). Text arrives already worded
## (Text.t); this panel holds no player text of its own.

signal chosen(choice_id: String)

const MARGIN_PX := 12
const WIDTH_SHARE := 0.42
const BUTTON_PREFIX := &"Choice_"

var _title := Label.new()
var _body := Label.new()
var _buttons := VBoxContainer.new()


func _ready() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", MARGIN_PX)
	add_child(column)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title)
	column.add_child(_body)
	column.add_child(_buttons)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Shows a title, a body and choices: [{"id": String, "label": String}], in order.
func present(title: String, body: String, choices: Array[Dictionary]) -> void:
	_title.text = title
	_body.text = body
	_body.visible = not body.is_empty()
	for old: Node in _buttons.get_children():
		_buttons.remove_child(old)
		old.queue_free()
	for choice: Dictionary in choices:
		var button := Button.new()
		var choice_id := str(choice.get("id", ""))
		button.name = String(BUTTON_PREFIX) + choice_id
		button.text = str(choice.get("label", ""))
		button.pressed.connect(chosen.emit.bind(choice_id))
		_buttons.add_child(button)
	visible = true
	_fit()


## The button for a choice id, or null (tests click it with the mouse).
func button_for(choice_id: String) -> Button:
	return _buttons.get_node_or_null(NodePath(String(BUTTON_PREFIX) + choice_id)) as Button


func _fit() -> void:
	var view := get_viewport_rect().size
	custom_minimum_size = Vector2(view.x * WIDTH_SHARE, 0.0)
	reset_size()
	position = Vector2(maxf(MARGIN_PX, view.x - size.x - MARGIN_PX), MARGIN_PX)
