class_name ShopScreen
extends CanvasLayer

## Экран магазина: покупка и продажа предметов.
## Открывается NPC-торговцем через show_shop().

signal shop_closed

## Список товаров на продажу. Заполняется торговцем перед открытием.
## Формат: Array[Dictionary] { "item": ItemResource, "price": int, "quantity": int (-1 = ∞) }
var _buy_stock: Array[Dictionary] = []

# ---------------------------------------------------------------------------
# UI nodes
# ---------------------------------------------------------------------------

var _panel: ColorRect
var _title_label: Label
var _gold_label: Label
var _buy_list: VBoxContainer
var _sell_list: VBoxContainer
var _tab_buy: Button
var _tab_sell: Button
var _scroll_buy: ScrollContainer
var _scroll_sell: ScrollContainer
var _potions_label: Label

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	layer = 20
	add_to_group("shop_screen")
	_build_ui()
	hide()
	process_mode = PROCESS_MODE_ALWAYS


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Центральная панель через CenterContainer — адаптируется к любому разрешению
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = ColorRect.new()
	_panel.color = Color(0.1, 0.1, 0.15, 0.98)
	_panel.custom_minimum_size = Vector2(700, 500)
	center.add_child(_panel)

	# Корневой VBoxContainer внутри панели
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	_panel.add_child(vbox)

	# Заголовок: строка с названием, данными о золоте/зельях, кнопкой закрытия
	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left",   14)
	header_margin.add_theme_constant_override("margin_right",  8)
	header_margin.add_theme_constant_override("margin_top",    10)
	header_margin.add_theme_constant_override("margin_bottom", 6)
	vbox.add_child(header_margin)

	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	header_margin.add_child(header_hbox)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	header_hbox.add_child(_title_label)

	var economy_vbox := VBoxContainer.new()
	economy_vbox.size_flags_horizontal = Control.SIZE_SHRINK_END
	economy_vbox.add_theme_constant_override("separation", 2)
	header_hbox.add_child(economy_vbox)

	_gold_label = Label.new()
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gold_label.add_theme_font_size_override("font_size", 16)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	economy_vbox.add_child(_gold_label)

	_potions_label = Label.new()
	_potions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_potions_label.add_theme_font_size_override("font_size", 12)
	_potions_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	economy_vbox.add_child(_potions_label)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_btn.size_flags_vertical   = Control.SIZE_SHRINK_BEGIN
	close_btn.pressed.connect(close)
	UIStyle.apply_btn(close_btn)
	header_hbox.add_child(close_btn)

	vbox.add_child(UIStyle.separator())

	# Вкладки
	var tab_margin := MarginContainer.new()
	tab_margin.add_theme_constant_override("margin_left",  8)
	tab_margin.add_theme_constant_override("margin_right", 8)
	tab_margin.add_theme_constant_override("margin_top",   4)
	vbox.add_child(tab_margin)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 6)
	tab_margin.add_child(tab_row)

	_tab_buy = Button.new()
	_tab_buy.text = "Купить"
	_tab_buy.custom_minimum_size = Vector2(120, 36)
	_tab_buy.toggle_mode = true
	_tab_buy.button_pressed = true
	_tab_buy.pressed.connect(_show_buy_tab)
	UIStyle.apply_btn(_tab_buy, UIStyle.COLOR_HEADING)
	tab_row.add_child(_tab_buy)

	_tab_sell = Button.new()
	_tab_sell.text = "Продать"
	_tab_sell.custom_minimum_size = Vector2(120, 36)
	_tab_sell.toggle_mode = true
	_tab_sell.pressed.connect(_show_sell_tab)
	UIStyle.apply_btn(_tab_sell, UIStyle.COLOR_HEADING)
	tab_row.add_child(_tab_sell)

	# Прокрутка покупки
	_scroll_buy = ScrollContainer.new()
	_scroll_buy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_buy.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll_buy)

	_buy_list = VBoxContainer.new()
	_buy_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_buy.add_child(_buy_list)

	# Прокрутка продажи
	_scroll_sell = ScrollContainer.new()
	_scroll_sell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_sell.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll_sell)

	_sell_list = VBoxContainer.new()
	_sell_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_sell.add_child(_sell_list)

	_show_buy_tab()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Открывает магазин с заданным набором товаров.
func show_shop(title: String, stock: Array[Dictionary]) -> void:
	_title_label.text = title
	_buy_stock = stock
	_refresh()
	show()


## Закрывает магазин.
func close() -> void:
	hide()
	shop_closed.emit()


# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _refresh() -> void:
	_gold_label.text = "Золото: %d" % PlayerData.gold
	_potions_label.text = "Зелья [1–4]: %d | %d | %d | %d" % [
		PlayerData.potion_slots[0], PlayerData.potion_slots[1],
		PlayerData.potion_slots[2], PlayerData.potion_slots[3]
	]
	_rebuild_buy_list()
	_rebuild_sell_list()


func _show_buy_tab() -> void:
	_scroll_buy.show()
	_scroll_sell.hide()
	if _tab_buy != null:
		_tab_buy.button_pressed = true
	if _tab_sell != null:
		_tab_sell.button_pressed = false
	_rebuild_buy_list()


func _show_sell_tab() -> void:
	_scroll_buy.hide()
	_scroll_sell.show()
	if _tab_buy != null:
		_tab_buy.button_pressed = false
	if _tab_sell != null:
		_tab_sell.button_pressed = true
	_rebuild_sell_list()


func _rebuild_buy_list() -> void:
	for c in _buy_list.get_children():
		c.queue_free()
	for entry: Dictionary in _buy_stock:
		var item: ItemResource = entry.get("item", null)
		var price: int = entry.get("price", 0)
		var qty: int = entry.get("quantity", -1)
		_add_buy_row(item, price, qty)


func _add_buy_row(item: ItemResource, price: int, qty: int) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := Label.new()
	if item != null:
		name_lbl.text = item.display_name
		name_lbl.add_theme_color_override("font_color", item.rarity_color())
	else:
		name_lbl.text = "Зелье здоровья (+50 HP)"
		name_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	if item != null:
		var bonus_lbl := Label.new()
		bonus_lbl.text = item.bonus_summary()
		bonus_lbl.add_theme_font_size_override("font_size", 12)
		bonus_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		bonus_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bonus_lbl)

	var price_lbl := Label.new()
	price_lbl.text = "%dg" % price
	price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	price_lbl.custom_minimum_size.x = 60
	row.add_child(price_lbl)

	var qty_lbl := Label.new()
	qty_lbl.text = "∞" if qty == -1 else str(qty)
	qty_lbl.custom_minimum_size.x = 30
	row.add_child(qty_lbl)

	var buy_btn := Button.new()
	buy_btn.text = "Купить"
	buy_btn.custom_minimum_size = Vector2(90, 32)
	buy_btn.pressed.connect(_on_buy.bind(item, price, qty_lbl, qty))
	UIStyle.apply_btn(buy_btn, UIStyle.COLOR_SUCCESS)
	row.add_child(buy_btn)

	_buy_list.add_child(row)


func _on_buy(item: ItemResource, price: int, qty_lbl: Label, original_qty: int) -> void:
	if not PlayerData.spend_gold(price):
		return
	if item == null:
		# Зелье здоровья — в первый слот с местом
		PlayerData.add_potions(1)
	else:
		var inv := _get_inventory()
		if inv != null:
			inv.pickup_item(item.duplicate() as ItemResource)
	# Обновить UI
	if original_qty > 0:
		var remaining: int = int(qty_lbl.text) - 1
		if remaining <= 0:
			qty_lbl.get_parent().queue_free()
			return
		qty_lbl.text = str(remaining)
	_refresh()


func _rebuild_sell_list() -> void:
	for c in _sell_list.get_children():
		c.queue_free()
	var inv := _get_inventory()
	if inv == null:
		return
	for item: ItemResource in inv.get_bag():
		_add_sell_row(item)


func _add_sell_row(item: ItemResource) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := Label.new()
	name_lbl.text = item.display_name
	name_lbl.add_theme_color_override("font_color", item.rarity_color())
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var price_lbl := Label.new()
	price_lbl.text = "%dg" % item.sell_value()
	price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	price_lbl.custom_minimum_size.x = 60
	row.add_child(price_lbl)

	var sell_btn := Button.new()
	sell_btn.text = "Продать"
	sell_btn.custom_minimum_size = Vector2(90, 32)
	sell_btn.pressed.connect(_on_sell.bind(item, row))
	UIStyle.apply_btn(sell_btn, UIStyle.COLOR_COOLDOWN)
	row.add_child(sell_btn)

	_sell_list.add_child(row)


func _on_sell(item: ItemResource, row: HBoxContainer) -> void:
	var inv := _get_inventory()
	if inv == null:
		return
	inv.sell_item_from_bag(item)
	row.queue_free()
	_gold_label.text = "Золото: %d" % PlayerData.gold


func _get_inventory() -> Inventory:
	var nodes := get_tree().get_nodes_in_group("inventory")
	if nodes.is_empty():
		return null
	return nodes[0] as Inventory
