class_name BagScreen
extends CanvasLayer

## Сумка [I]. Показывает неэкипированные предметы.
## Нажми на предмет — надеть в соответствующий слот.

var _root: Control
var _item_list: VBoxContainer
var _did_pause: bool = false
var _inventory: Inventory = null


func _ready() -> void:
	add_to_group("bag_screen")
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	var bg := ColorRect.new()
	bg.color = UIStyle.COLOR_OVERLAY_MODAL
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	var panel := Panel.new()
	var pw := 460.0
	var ph := 440.0
	panel.set_anchor(SIDE_LEFT,   0.5); panel.set_anchor(SIDE_RIGHT,  0.5)
	panel.set_anchor(SIDE_TOP,    0.5); panel.set_anchor(SIDE_BOTTOM, 0.5)
	panel.set_offset(SIDE_LEFT,   -pw / 2.0); panel.set_offset(SIDE_RIGHT,   pw / 2.0)
	panel.set_offset(SIDE_TOP,    -ph / 2.0); panel.set_offset(SIDE_BOTTOM,  ph / 2.0)
	panel.add_theme_stylebox_override("panel", UIStyle.panel_style())
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   12)
	margin.add_theme_constant_override("margin_right",  12)
	margin.add_theme_constant_override("margin_top",     8)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "СУМКА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_heading(title, 20)
	vbox.add_child(title)
	vbox.add_child(UIStyle.separator())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_item_list = VBoxContainer.new()
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_list.add_theme_constant_override("separation", 3)
	scroll.add_child(_item_list)

	vbox.add_child(UIStyle.separator())

	var bottom := HBoxContainer.new()
	vbox.add_child(bottom)

	var eq_btn := Button.new()
	eq_btn.text = "Снаряжение  [Tab]"
	eq_btn.pressed.connect(func():
		_close()
		var eq := get_tree().get_first_node_in_group("inventory_screen")
		if eq != null and eq.has_method("open"):
			eq.open()
	)
	UIStyle.apply_btn(eq_btn)
	bottom.add_child(eq_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)

	var hint := Label.new()
	hint.text = "[I] закрыть"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", UIStyle.COLOR_TEXT_DIM)
	bottom.add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I:
			_toggle()
			get_viewport().set_input_as_handled()


func open() -> void:
	_open()


func _toggle() -> void:
	if _root.visible:
		_close()
	else:
		_open()


func _open() -> void:
	_inventory = get_tree().get_first_node_in_group("inventory") as Inventory
	_refresh()
	_root.visible = true
	if not get_tree().paused:
		get_tree().paused = true
		_did_pause = true


func _close() -> void:
	_root.visible = false
	if _did_pause:
		get_tree().paused = false
		_did_pause = false


func _refresh() -> void:
	for child in _item_list.get_children():
		child.queue_free()

	if _inventory == null:
		return

	var bag := _inventory.get_bag()
	if bag.is_empty():
		var lbl := Label.new()
		lbl.text = "Сумка пуста"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", UIStyle.COLOR_TEXT_DIM)
		_item_list.add_child(lbl)
		return

	for item: ItemResource in bag:
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 14)
		btn.text = "%s   %s   [надеть]" % [item.display_name, item.bonus_summary()]
		UIStyle.apply_btn(btn)
		btn.add_theme_color_override("font_color", item.rarity_color())
		var captured := item
		btn.pressed.connect(func():
			if _inventory != null:
				_inventory.equip_item(captured)
				_refresh()
		)
		_item_list.add_child(btn)
