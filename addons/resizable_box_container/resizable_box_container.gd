@tool
extends BoxContainer
class_name ResizableBoxContainer

## Always use this separation instead of the theme's separation
@export var separation:int = 3:
	set(value):
		separation = value
		for sep in _separators:
			sep.add_theme_constant_override("separation", value)
@export var separator_theme:Theme:
	set(value):
		separator_theme = value
		for sep in _separators:
			sep.theme = value
@export var minimum_child_size:Vector2:
	set(value):
		minimum_child_size = value
		reorder_children.call_deferred()

var children:Array[Node]
var _separators:Array[Separator]
var _is_reordering = false
var _reorder_pending:bool = false
var _is_holding_separator:bool = false

func _set(property: StringName, value: Variant) -> bool:
	if property == &"vertical":
		vertical = value
		reorder_children.call_deferred()
	return false

func _enter_tree() -> void:
	child_order_changed.connect(_on_child_order_changed)

func reorder_children() -> void:
	_is_reordering = true
	children = get_actual_children()
	_remove_separators()
	_add_separators()
	for child in children:
		if child is Control:
			child.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if vertical else Control.SIZE_EXPAND_FILL
			child.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if not vertical else Control.SIZE_EXPAND_FILL
			if vertical:
				child.custom_minimum_size.y = minimum_child_size.y
			else:
				child.custom_minimum_size.x = minimum_child_size.x

	children.back().size_flags_vertical = Control.SIZE_EXPAND_FILL
	children.back().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reorder_pending = false
	_is_reordering = false

func _on_child_order_changed() -> void:
	if _is_reordering: return
	if _reorder_pending: return

	reorder_children.call_deferred()
	_reorder_pending = true

func get_actual_children() -> Array[Node]:
	var _children:Array[Node]
	for child in get_children():
		if child is Separator:
			continue
		_children.append(child)
	return _children

func _add_separators() -> void:
	if children.size() <= 1: return
	var i:int = 0
	while i < children.size() - 1:
		var sep:Separator
		if vertical: sep = HSeparator.new()
		else: sep = VSeparator.new()
		sep.mouse_default_cursor_shape = CURSOR_HSPLIT if sep is VSeparator else CURSOR_VSPLIT
		sep.add_theme_constant_override("separation", separation)
		sep.gui_input.connect(_on_separator_gui_input.bind(sep))
		add_child(sep)
		move_child(sep, children[i].get_index() + 1)
		_separators.append(sep)
		i += 1

func _remove_separators() -> void:
	for sep in _separators:
		remove_child(sep)
		sep.queue_free()
	_separators.clear()

func _on_separator_mouse_move(separator:Separator, amount:Vector2) -> void:
	var child_before = get_child(separator.get_index()-1)
	child_before.custom_minimum_size.x = max(minimum_child_size.x, child_before.size.x)
	child_before.custom_minimum_size.y = max(minimum_child_size.y, child_before.size.y)
	var child_after = get_child(separator.get_index()+1)
	if child_before is Control and child_after is Control:
		if vertical:
			var new_size:float = child_before.custom_minimum_size.y + amount.y
			var max_size:float = child_before.size.y + child_after.size.y
			child_before.custom_minimum_size.y = clampf(new_size, 0, max_size)
		else:
			var new_size:float = child_before.custom_minimum_size.x + amount.x
			var max_size:float = child_before.size.x + child_after.size.x
			child_before.custom_minimum_size.x = clampf(new_size, 0, max_size)

func _on_separator_gui_input(event:InputEvent, sep:Separator) -> void:
	if event is InputEventMouseMotion and _is_holding_separator:
		_on_separator_mouse_move(sep, event.relative)
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_holding_separator = true
			else:
				_is_holding_separator = false
			return
