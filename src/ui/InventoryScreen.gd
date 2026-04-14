class_name InventoryScreen
extends CanvasLayer

## Экран снаряжения [Tab]. Показывает 8 слотов.
## Кнопка на слоте — снять предмет обратно в сумку.

const SLOT_NAMES: Array[String] = [
	"Оружие", "Шлем", "Броня", "Перчатки",
	"Сапоги", "Кольцо 1", "Кольцо 2", "Амулет"
]

var _root: Control
var _slot_btns: Array[Button] = []
var _did_pause: bool = false
var _inventory: Inventory = null


func _ready() -> void:
	add_to_group("inventory_screen")
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	var panel := Panel.new()
	var pw := 460.0
	var ph := 420.0
	panel.set_anchor(SIDE_LEFT,   0.5); panel.set_anchor(SIDE_RIGHT,  0.5)
	panel.set_anchor(SIDE_TOP,    0.5); panel.set_anchor(SIDE_BOTTOM, 0.5)
	panel.set_offset(SIDE_LEFT,   -pw / 2.0); panel.set_offset(SIDE_RIGHT,   pw / 2.0)
	panel.set_offset(SIDE_TOP,    -ph / 2.0); panel.set_offset(SIDE_BOTTOM,  ph / 2.0)
	_root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "СНАРЯЖЕНИЕ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	for i in range(8):
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 14)
		var slot_idx := i
		btn.pressed.connect(func(): _on_slot_clicked(slot_idx))
		vbox.add_child(btn)
		_slot_btns.append(btn)

	vbox.add_child(HSeparator.new())

	var bottom := HBoxContainer.new()
	vbox.add_child(bottom)

	var bag_btn := Button.new()
	bag_btn.text = "Сумка  [I]"
	bag_btn.pressed.connect(func():
		_close()
		var bag := get_tree().get_first_node_in_group("bag_screen")
		if bag != null and bag.has_method("open"):
			bag.open()
	)
	bottom.add_child(bag_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)

	var hint := Label.new()
	hint.text = "[Tab] закрыть"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	bottom.add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
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


func _on_slot_clicked(slot: int) -> void:
	if _inventory == null:
		return
	if _inventory.get_equipped_item(slot) != null:
		_inventory.unequip_slot(slot)
		_refresh()


func _refresh() -> void:
	for i in range(8):
		var item: ItemResource = null
		if _inventory != null:
			item = _inventory.get_equipped_item(i)

		var btn: Button = _slot_btns[i]
		var slot_name: String = SLOT_NAMES[i]

		if item == null:
			btn.text     = "%-10s  (пусто)" % slot_name
			btn.disabled = true
			btn.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
		else:
			btn.text     = "%-10s  %s   %s   [снять]" % [slot_name, item.display_name, item.bonus_summary()]
			btn.disabled = false
			btn.add_theme_color_override("font_color", item.rarity_color())
