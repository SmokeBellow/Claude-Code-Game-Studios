class_name SidePanel
extends CanvasLayer

## Боковое меню игрока. Открывается по Tab.
## Вкладки: Атрибуты | Экипировка | Инвентарь | Задания | Навыки

const PANEL_W: float  = 500.0
const PANEL_H: float  = 600.0
const SLOT_SIZE: float = 56.0
const SLOT_COLS: int   = 5
const SLOT_GAP: float  = 4.0

const TAB_ATTRS:  int = 0
const TAB_EQUIP:  int = 1
const TAB_BAG:    int = 2
const TAB_QUESTS: int = 3
const TAB_SKILLS: int = 4

const EQUIP_SLOTS: Array[String] = [
	"Оружие", "Шлем", "Броня", "Перчатки",
	"Сапоги", "Кольцо 1", "Кольцо 2", "Амулет"
]
const ATTR_KEYS: Array[String] = [
	"strength", "dexterity", "endurance",
	"intelligence", "arcana", "luck"
]
const ATTR_NAMES: Dictionary = {
	"strength":      "Сила",
	"dexterity":     "Ловкость",
	"endurance":     "Выносливость",
	"intelligence":  "Интеллект",
	"arcana":        "Аркана",
	"luck":          "Удача",
}

# Маппинг ячеек сетки папердолла → slot ID (-1 = пустая ячейка)
# Сетка 3×4:
#   _      ШЛЕМ(1)   _
#  ОРЖ(0) БРОНЯ(2) ПЕРЧ(3)
#  КЛЬ1(5) АМУ(7) КЛЬ2(6)
#   _      САПОГ(4)  _
const _PAPERDOLL: Array[int] = [
	-1, 1, -1,
	 0, 2,  3,
	 5, 7,  6,
	-1, 4, -1,
]

# ---------------------------------------------------------------------------
# Ссылки на узлы
# ---------------------------------------------------------------------------

var _panel: ColorRect
var _overlay: ColorRect
var _toggle_btn: Button
var _is_open: bool = false
var _did_pause: bool = false
var _current_tab: int = TAB_BAG

var _tab_btns: Array[Button] = []
var _views: Array[Control] = []

# Атрибуты
var _attr_val_labels: Dictionary = {}   # key → Label
var _attr_pts_label: Label

# Экипировка — папердолл
var _equip_btns: Array = []             # size 8, indexed by slot
var _equip_selected_slot: int = -1
var _equip_action_row: HBoxContainer
var _equip_item_lbl: Label

# Инвентарь — квадратные слоты
var _bag_grid: GridContainer
var _bag_slots: Array[Button] = []
var _selected_bag_idx: int = -1
var _bag_action_panel: HBoxContainer
var _bag_info_label: Label
var _bag_equip_btn: Button
var _bag_sell_btn: Button
var _bag_count_label: Label     # "X / 20 предметов"
var _potion_slot_labels: Array[Label] = []  # 4 лейбла с количеством зелий

# Tooltip предмета при наведении
var _tooltip_box: PanelContainer
var _tooltip_name_lbl: Label
var _tooltip_stats_lbl: Label
var _tooltip_sell_lbl: Label

# Задания
var _quest_text: Label

# Навыки — дерево навыков
var _skill_pts_label: Label = null
var _skill_tree_container: VBoxContainer = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	layer = 8
	add_to_group("side_panel")
	process_mode = PROCESS_MODE_ALWAYS
	_equip_btns.resize(8)
	_build_toggle_btn()
	_build_panel()
	_panel.visible = false
	_overlay.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_toggle()
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Публичный API
# ---------------------------------------------------------------------------

func open(tab: int = TAB_BAG) -> void:
	_current_tab = tab
	_refresh_all()
	_panel.visible = true
	_overlay.visible = true
	_toggle_btn.visible = false
	_switch_tab(tab)
	if not get_tree().paused:
		get_tree().paused = true
		_did_pause = true


func close() -> void:
	_panel.visible = false
	_overlay.visible = false
	_toggle_btn.visible = true
	_is_open = false
	if _did_pause:
		get_tree().paused = false
		_did_pause = false

# ---------------------------------------------------------------------------
# Построение UI
# ---------------------------------------------------------------------------

func _build_toggle_btn() -> void:
	# Маленькая подсказка в правом нижнем углу
	_toggle_btn = Button.new()
	_toggle_btn.text = "[Tab] Меню"
	_toggle_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_toggle_btn.offset_left   = -110.0
	_toggle_btn.offset_right  = -8.0
	_toggle_btn.offset_top    = -36.0
	_toggle_btn.offset_bottom = -8.0
	_toggle_btn.pressed.connect(_toggle)
	_toggle_btn.add_theme_font_size_override("font_size", 12)
	UIStyle.apply_btn(_toggle_btn)
	add_child(_toggle_btn)


func _build_panel() -> void:
	# Затемняющий оверлей за панелью
	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	# Центральная панель фиксированного размера
	_panel = ColorRect.new()
	_panel.color = Color(0.09, 0.09, 0.13, 0.97)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left   = -PANEL_W * 0.5
	_panel.offset_right  =  PANEL_W * 0.5
	_panel.offset_top    = -PANEL_H * 0.5
	_panel.offset_bottom =  PANEL_H * 0.5
	_panel.process_mode  = Node.PROCESS_MODE_ALWAYS
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	_panel.add_child(vbox)

	# Заголовок
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 36
	vbox.add_child(header)

	var title := Label.new()
	title.text = "  Меню персонажа"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.pressed.connect(close)
	UIStyle.apply_btn(close_btn)
	header.add_child(close_btn)

	vbox.add_child(UIStyle.separator())

	# Вкладки
	var tab_bar := HBoxContainer.new()
	tab_bar.custom_minimum_size.y = 36
	vbox.add_child(tab_bar)

	var tab_labels: Array[String] = ["Атр.", "Экип.", "Инв.", "Задания", "Навыки"]
	for i in range(5):
		var btn := Button.new()
		btn.text = tab_labels[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_switch_tab.bind(i))
		UIStyle.apply_btn(btn)
		tab_bar.add_child(btn)
		_tab_btns.append(btn)

	vbox.add_child(UIStyle.separator())

	# Контентная область
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)

	# Строим 5 view (только один виден одновременно)
	_views.append(_build_attrs_view(content))
	_views.append(_build_equip_view(content))
	_views.append(_build_bag_view(content))
	_views.append(_build_quests_view(content))
	_views.append(_build_skills_view(content))


# ---------------------------------------------------------------------------
# Вкладка: Атрибуты
# ---------------------------------------------------------------------------

func _build_attrs_view(parent: Control) -> Control:
	var view := VBoxContainer.new()
	view.add_theme_constant_override("separation", 6)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(view)

	var lbl := Label.new()
	lbl.text = "  АТРИБУТЫ"
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	lbl.add_theme_font_size_override("font_size", 14)
	view.add_child(lbl)

	_attr_pts_label = Label.new()
	_attr_pts_label.add_theme_font_size_override("font_size", 12)
	_attr_pts_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	view.add_child(_attr_pts_label)

	view.add_child(UIStyle.separator())

	for key: String in ATTR_KEYS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		view.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = "  " + ATTR_NAMES[key]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(name_lbl)

		var val_lbl := Label.new()
		val_lbl.custom_minimum_size.x = 32
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(val_lbl)
		_attr_val_labels[key] = val_lbl

		var plus_btn := Button.new()
		plus_btn.text = "+"
		plus_btn.custom_minimum_size = Vector2(32, 32)
		plus_btn.pressed.connect(_on_attr_plus.bind(key))
		UIStyle.apply_btn(plus_btn)
		row.add_child(plus_btn)

	return view


# ---------------------------------------------------------------------------
# Вкладка: Экипировка — Папердолл
# ---------------------------------------------------------------------------

func _build_equip_view(parent: Control) -> Control:
	var view := VBoxContainer.new()
	view.add_theme_constant_override("separation", 8)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(view)

	var lbl := Label.new()
	lbl.text = "  ЭКИПИРОВКА"
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	lbl.add_theme_font_size_override("font_size", 14)
	view.add_child(lbl)
	view.add_child(UIStyle.separator())

	# Папердолл — сетка 3×4, центрирована
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	view.add_child(grid)

	for cell_slot: int in _PAPERDOLL:
		if cell_slot < 0:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(72, 82)
			grid.add_child(spacer)
		else:
			grid.add_child(_make_equip_cell(cell_slot))

	view.add_child(UIStyle.separator())

	# Панель действия (скрыта до клика на слот)
	_equip_action_row = HBoxContainer.new()
	_equip_action_row.add_theme_constant_override("separation", 8)
	_equip_action_row.hide()
	view.add_child(_equip_action_row)

	_equip_item_lbl = Label.new()
	_equip_item_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equip_item_lbl.add_theme_font_size_override("font_size", 12)
	_equip_item_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_equip_action_row.add_child(_equip_item_lbl)

	var unequip_btn := Button.new()
	unequip_btn.text = "Снять"
	unequip_btn.custom_minimum_size = Vector2(72, 32)
	unequip_btn.pressed.connect(_on_equip_unequip_selected)
	UIStyle.apply_btn(unequip_btn)
	_equip_action_row.add_child(unequip_btn)

	return view


func _make_equip_cell(slot: int) -> Control:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 3)
	cell.custom_minimum_size = Vector2(72, 82)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(64, 64)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.clip_contents = true
	btn.pressed.connect(_on_equip_slot_clicked.bind(slot))
	_apply_equip_slot_style(btn, null)
	cell.add_child(btn)
	_equip_btns[slot] = btn

	var name_lbl := Label.new()
	name_lbl.text = EQUIP_SLOTS[slot]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	cell.add_child(name_lbl)

	return cell


func _apply_equip_slot_style(btn: Button, item: ItemResource) -> void:
	var base: Color = item.rarity_color() if item != null else Color(0.35, 0.35, 0.4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(base.r * 0.2, base.g * 0.2, base.b * 0.2, 1.0) if item != null \
		else Color(0.11, 0.11, 0.14, 1.0)
	bg.border_color = base
	var bw: int = 2 if item != null else 1
	bg.border_width_left   = bw
	bg.border_width_right  = bw
	bg.border_width_top    = bw
	bg.border_width_bottom = bw
	bg.corner_radius_top_left     = 4
	bg.corner_radius_top_right    = 4
	bg.corner_radius_bottom_left  = 4
	bg.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", bg)

	var hover := bg.duplicate() as StyleBoxFlat
	hover.bg_color = Color(base.r * 0.38, base.g * 0.38, base.b * 0.38, 1.0)
	btn.add_theme_stylebox_override("hover", hover)

	if item != null:
		btn.text = item.display_name.left(8)
		btn.add_theme_color_override("font_color", base)
		btn.add_theme_font_size_override("font_size", 9)
	else:
		btn.text = "—"
		btn.add_theme_color_override("font_color", Color(0.28, 0.28, 0.32))
		btn.add_theme_font_size_override("font_size", 16)


# ---------------------------------------------------------------------------
# Вкладка: Инвентарь (квадратные слоты)
# ---------------------------------------------------------------------------

func _build_bag_view(parent: Control) -> Control:
	var view := VBoxContainer.new()
	view.add_theme_constant_override("separation", 6)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(view)

	# Заголовок + счётчик в одной строке
	var header_row := HBoxContainer.new()
	view.add_child(header_row)

	var lbl := Label.new()
	lbl.text = "  ИНВЕНТАРЬ"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(lbl)

	_bag_count_label = Label.new()
	_bag_count_label.text = "0 / 20"
	_bag_count_label.add_theme_font_size_override("font_size", 12)
	_bag_count_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60))
	_bag_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_row.add_child(_bag_count_label)

	view.add_child(UIStyle.separator())

	# Инфо выбранного предмета
	_bag_info_label = Label.new()
	_bag_info_label.text = ""
	_bag_info_label.add_theme_font_size_override("font_size", 13)
	_bag_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bag_info_label.custom_minimum_size.y = 40
	view.add_child(_bag_info_label)

	# Кнопки действий
	_bag_action_panel = HBoxContainer.new()
	_bag_action_panel.add_theme_constant_override("separation", 8)
	view.add_child(_bag_action_panel)

	_bag_equip_btn = Button.new()
	_bag_equip_btn.text = "Надеть"
	_bag_equip_btn.custom_minimum_size.y = 36
	_bag_equip_btn.pressed.connect(_on_bag_equip)
	UIStyle.apply_btn(_bag_equip_btn)
	_bag_action_panel.add_child(_bag_equip_btn)

	_bag_sell_btn = Button.new()
	_bag_sell_btn.text = "Продать"
	_bag_sell_btn.custom_minimum_size.y = 36
	_bag_sell_btn.pressed.connect(_on_bag_sell)
	UIStyle.apply_btn(_bag_sell_btn)
	_bag_action_panel.add_child(_bag_sell_btn)

	var drop_btn := Button.new()
	drop_btn.text = "Выбросить"
	drop_btn.custom_minimum_size.y = 36
	drop_btn.pressed.connect(_on_bag_drop)
	UIStyle.apply_btn(drop_btn)
	_bag_action_panel.add_child(drop_btn)

	_bag_action_panel.hide()

	view.add_child(UIStyle.separator())

	# Сетка слотов (20 ячеек; пустые отображаются серыми плейсхолдерами)
	_bag_grid = GridContainer.new()
	_bag_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bag_grid.columns = SLOT_COLS
	_bag_grid.add_theme_constant_override("h_separation", int(SLOT_GAP))
	_bag_grid.add_theme_constant_override("v_separation", int(SLOT_GAP))
	view.add_child(_bag_grid)

	view.add_child(UIStyle.separator())

	# Секция зелий — 4 слота (хоткеи 1–4)
	var potion_hdr := Label.new()
	potion_hdr.text = "  ЗЕЛЬЯ  (1–4)"
	potion_hdr.add_theme_color_override("font_color", Color(0.65, 0.85, 0.65))
	potion_hdr.add_theme_font_size_override("font_size", 13)
	view.add_child(potion_hdr)

	var potion_row := HBoxContainer.new()
	potion_row.add_theme_constant_override("separation", 8)
	view.add_child(potion_row)

	_potion_slot_labels.clear()
	for i: int in range(4):
		var slot_box := VBoxContainer.new()
		slot_box.add_theme_constant_override("separation", 2)
		slot_box.custom_minimum_size = Vector2(SLOT_SIZE, 0.0)
		potion_row.add_child(slot_box)

		# Иконка зелья
		var icon_rect := ColorRect.new()
		icon_rect.color = Color(0.12, 0.28, 0.12, 0.9)
		icon_rect.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_box.add_child(icon_rect)

		var icon_lbl := Label.new()
		icon_lbl.text = "🧪"
		icon_lbl.add_theme_font_size_override("font_size", 22)
		icon_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.add_child(icon_lbl)

		# Счётчик
		var count_lbl := Label.new()
		count_lbl.text = "0"
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_lbl.add_theme_font_size_override("font_size", 14)
		count_lbl.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
		slot_box.add_child(count_lbl)
		_potion_slot_labels.append(count_lbl)

		# Клавиша
		var key_lbl := Label.new()
		key_lbl.text = "[%d]" % (i + 1)
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.add_theme_font_size_override("font_size", 11)
		key_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
		slot_box.add_child(key_lbl)

	# Tooltip предмета (появляется при наведении)
	_tooltip_box = PanelContainer.new()
	var tooltip_style := StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.07, 0.07, 0.11, 0.97)
	tooltip_style.border_color = Color(0.35, 0.35, 0.45)
	tooltip_style.set_border_width_all(1)
	tooltip_style.set_corner_radius_all(4)
	_tooltip_box.add_theme_stylebox_override("panel", tooltip_style)
	_tooltip_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tooltip_box.hide()
	view.add_child(_tooltip_box)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	_tooltip_box.add_child(margin)

	var tvb := VBoxContainer.new()
	tvb.add_theme_constant_override("separation", 3)
	margin.add_child(tvb)

	_tooltip_name_lbl = Label.new()
	_tooltip_name_lbl.add_theme_font_size_override("font_size", 14)
	tvb.add_child(_tooltip_name_lbl)

	_tooltip_stats_lbl = Label.new()
	_tooltip_stats_lbl.add_theme_font_size_override("font_size", 12)
	_tooltip_stats_lbl.add_theme_color_override("font_color", Color(0.70, 0.70, 0.75))
	_tooltip_stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tvb.add_child(_tooltip_stats_lbl)

	_tooltip_sell_lbl = Label.new()
	_tooltip_sell_lbl.add_theme_font_size_override("font_size", 11)
	_tooltip_sell_lbl.add_theme_color_override("font_color", Color(0.65, 0.60, 0.35))
	tvb.add_child(_tooltip_sell_lbl)

	return view


# ---------------------------------------------------------------------------
# Вкладка: Задания
# ---------------------------------------------------------------------------

func _build_quests_view(parent: Control) -> Control:
	var view := VBoxContainer.new()
	view.add_theme_constant_override("separation", 6)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(view)

	var lbl := Label.new()
	lbl.text = "  ЗАДАНИЯ"
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	lbl.add_theme_font_size_override("font_size", 14)
	view.add_child(lbl)
	view.add_child(UIStyle.separator())

	_quest_text = Label.new()
	_quest_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_text.add_theme_font_size_override("font_size", 14)
	view.add_child(_quest_text)

	return view


# ---------------------------------------------------------------------------
# Вкладка: Навыки
# ---------------------------------------------------------------------------

func _build_skills_view(parent: Control) -> Control:
	var view := VBoxContainer.new()
	view.add_theme_constant_override("separation", 8)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(view)

	var lbl := Label.new()
	lbl.text = "  НАВЫКИ"
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	lbl.add_theme_font_size_override("font_size", 14)
	view.add_child(lbl)
	view.add_child(UIStyle.separator())

	# Базовый навык — рывок
	var dash_row := HBoxContainer.new()
	dash_row.add_theme_constant_override("separation", 10)
	view.add_child(dash_row)

	var dash_icon := ColorRect.new()
	dash_icon.color = Color(0.3, 0.5, 0.9)
	dash_icon.custom_minimum_size = Vector2(44, 44)
	dash_row.add_child(dash_icon)

	var dash_icon_lbl := Label.new()
	dash_icon_lbl.text = "⚡"
	dash_icon_lbl.add_theme_font_size_override("font_size", 22)
	dash_icon_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dash_icon.add_child(dash_icon_lbl)

	var dash_info := VBoxContainer.new()
	dash_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dash_row.add_child(dash_info)

	var dash_name := Label.new()
	dash_name.text = "Рывок  [Shift]"
	dash_name.add_theme_font_size_override("font_size", 14)
	dash_name.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	dash_info.add_child(dash_name)

	var dash_desc := Label.new()
	dash_desc.text = "Молниеносное перемещение в направлении движения.\nКд: %.1f с  |  Дистанция: %d пкс" % [
		Player.DASH_COOLDOWN, int(Player.DASH_DISTANCE)
	]
	dash_desc.add_theme_font_size_override("font_size", 12)
	dash_desc.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	dash_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dash_info.add_child(dash_desc)

	view.add_child(UIStyle.separator())

	# Раздел: дерево навыков
	var tree_hdr := HBoxContainer.new()
	tree_hdr.add_theme_constant_override("separation", 8)
	view.add_child(tree_hdr)

	var tree_title := Label.new()
	tree_title.text = "  Дерево навыков"
	tree_title.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	tree_title.add_theme_font_size_override("font_size", 13)
	tree_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_hdr.add_child(tree_title)

	_skill_pts_label = Label.new()
	_skill_pts_label.text = "Очков: 0"
	_skill_pts_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_skill_pts_label.add_theme_font_size_override("font_size", 13)
	tree_hdr.add_child(_skill_pts_label)

	_skill_tree_container = VBoxContainer.new()
	_skill_tree_container.add_theme_constant_override("separation", 2)
	_skill_tree_container.process_mode = Node.PROCESS_MODE_ALWAYS
	view.add_child(_skill_tree_container)

	return view


# ---------------------------------------------------------------------------
# Переключение вкладок
# ---------------------------------------------------------------------------

func _toggle() -> void:
	if _is_open:
		close()
	else:
		open(_current_tab)
	_is_open = _panel.visible


func _switch_tab(tab: int) -> void:
	_current_tab = tab
	for i in range(_views.size()):
		_views[i].visible = (i == tab)
	for i in range(_tab_btns.size()):
		_tab_btns[i].button_pressed = (i == tab)
	_refresh_tab(tab)


# ---------------------------------------------------------------------------
# Обновление данных
# ---------------------------------------------------------------------------

func _refresh_all() -> void:
	_refresh_tab(_current_tab)


func _refresh_tab(tab: int) -> void:
	match tab:
		TAB_ATTRS:  _refresh_attrs()
		TAB_EQUIP:  _refresh_equip()
		TAB_BAG:    _refresh_bag()
		TAB_QUESTS: _refresh_quests()
		TAB_SKILLS: _refresh_skills()


func _refresh_attrs() -> void:
	var stats := _get_stats()
	if stats == null:
		for key in ATTR_KEYS:
			_attr_val_labels[key].text = "—"
		_attr_pts_label.text = ""
		return

	_attr_val_labels["strength"].text      = str(int(stats.strength))
	_attr_val_labels["dexterity"].text     = str(int(stats.dexterity))
	_attr_val_labels["endurance"].text     = str(int(stats.endurance))
	_attr_val_labels["intelligence"].text  = str(int(stats.intelligence))
	_attr_val_labels["arcana"].text        = str(int(stats.arcana))
	_attr_val_labels["luck"].text          = str(int(stats.luck))

	if stats.attribute_points > 0:
		_attr_pts_label.text = "  Свободных очков: %d" % stats.attribute_points
	else:
		_attr_pts_label.text = ""


func _refresh_equip() -> void:
	_equip_selected_slot = -1
	if _equip_action_row != null:
		_equip_action_row.hide()
	var inv := _get_inventory()
	for i in range(8):
		var btn = _equip_btns[i]
		if btn == null:
			continue
		var item: ItemResource = inv.get_equipped_item(i) if inv != null else null
		_apply_equip_slot_style(btn, item)


func _refresh_bag() -> void:
	# Очищаем старые слоты
	for child in _bag_grid.get_children():
		child.queue_free()
	_bag_slots.clear()
	_selected_bag_idx = -1
	_bag_action_panel.hide()
	_bag_info_label.text = ""
	if _tooltip_box != null:
		_tooltip_box.hide()

	var inv := _get_inventory()
	var bag: Array[ItemResource] = []
	if inv != null:
		bag = inv.get_bag()
	var max_slots: int = 20  # Inventory.BAG_MAX_SIZE

	# Счётчик заполненности
	var count_color: Color = Color(0.55, 0.55, 0.60)
	if bag.size() >= max_slots:
		count_color = Color(1.0, 0.45, 0.35)   # красный — полная
	elif bag.size() >= max_slots * 0.8:
		count_color = Color(1.0, 0.75, 0.3)    # жёлтый — почти полная
	if _bag_count_label != null:
		_bag_count_label.text = "%d / %d" % [bag.size(), max_slots]
		_bag_count_label.add_theme_color_override("font_color", count_color)

	# Строим все 20 слотов: занятые — с предметом, пустые — серый плейсхолдер
	for i: int in range(max_slots):
		if i < bag.size():
			var slot := _make_bag_slot(bag[i], i)
			_bag_grid.add_child(slot)
			_bag_slots.append(slot)
		else:
			var empty := _make_bag_slot_empty()
			_bag_grid.add_child(empty)
			_bag_slots.append(empty)

	# Обновляем секцию зелий
	for i: int in range(4):
		if i < _potion_slot_labels.size():
			var count: int = PlayerData.potion_slots[i]
			_potion_slot_labels[i].text = str(count)
			var c: Color = Color(0.7, 1.0, 0.7) if count > 0 else Color(0.35, 0.35, 0.35)
			_potion_slot_labels[i].add_theme_color_override("font_color", c)


func _make_bag_slot(item: ItemResource, idx: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	btn.clip_contents = true

	# Фон по редкости — тёмная версия цвета редкости
	var base: Color = item.rarity_color()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(base.r * 0.25, base.g * 0.25, base.b * 0.25, 1.0)
	bg.border_color = base
	bg.border_width_left   = 1
	bg.border_width_right  = 1
	bg.border_width_top    = 1
	bg.border_width_bottom = 1
	btn.add_theme_stylebox_override("normal", bg)

	var hover := bg.duplicate() as StyleBoxFlat
	hover.bg_color = Color(base.r * 0.4, base.g * 0.4, base.b * 0.4, 1.0)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed_style := bg.duplicate() as StyleBoxFlat
	pressed_style.bg_color = base * 0.6
	pressed_style.border_color = Color.WHITE
	pressed_style.border_width_left   = 2
	pressed_style.border_width_right  = 2
	pressed_style.border_width_top    = 2
	pressed_style.border_width_bottom = 2
	btn.add_theme_stylebox_override("pressed", pressed_style)

	# Иконка мусора
	var abbr := item.display_name.left(6)
	if item.is_junk:
		abbr = "🗑" + item.display_name.left(4)
	btn.text = abbr
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", base)

	btn.toggle_mode = true
	btn.pressed.connect(_on_bag_slot_clicked.bind(idx))
	btn.mouse_entered.connect(_on_bag_slot_hovered.bind(idx))
	btn.mouse_exited.connect(_on_bag_slot_hover_end)
	return btn


## Пустой слот сумки — серый плейсхолдер без обработчиков.
func _make_bag_slot_empty() -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_PASS  # не перехватывает события

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.10, 0.12, 1.0)
	bg.border_color = Color(0.20, 0.20, 0.24)
	bg.border_width_left   = 1
	bg.border_width_right  = 1
	bg.border_width_top    = 1
	bg.border_width_bottom = 1
	btn.add_theme_stylebox_override("normal",   bg)
	btn.add_theme_stylebox_override("hover",    bg)
	btn.add_theme_stylebox_override("pressed",  bg)
	btn.add_theme_stylebox_override("disabled", bg)
	btn.add_theme_color_override("font_color", Color(0.22, 0.22, 0.26))
	btn.add_theme_font_size_override("font_size", 18)
	btn.text = "·"
	return btn


func _refresh_skills() -> void:
	_refresh_skill_tree()


func _refresh_skill_tree() -> void:
	if _skill_pts_label == null or _skill_tree_container == null:
		return

	_skill_pts_label.text = "Очков: %d" % PlayerData.skill_points

	# Пересобираем дерево
	for child in _skill_tree_container.get_children():
		child.free()

	# Общая ветка — всегда
	_build_branch_ui("general")

	# Специализации — только когда класс выбран и general >= порога
	if PlayerData.player_class != PlayerData.CLASS_NONE:
		var general_pts: int = int(PlayerData.spent_points.get("general", 0))
		if general_pts >= SkillTree.GENERAL_GATE:
			for branch_key: String in SkillTree.CLASS_BRANCHES.get(PlayerData.player_class, []):
				_build_branch_ui(branch_key)
		else:
			var remaining: int = SkillTree.GENERAL_GATE - general_pts
			var hint := Label.new()
			hint.text = "  Ещё %d очка в «Общие» — откроет специализации" % remaining
			hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			hint.add_theme_font_size_override("font_size", 11)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_skill_tree_container.add_child(hint)
	else:
		var hint := Label.new()
		hint.text = "  Специализации откроются при выборе класса (ур. 3)"
		hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		hint.add_theme_font_size_override("font_size", 11)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_skill_tree_container.add_child(hint)


func _build_branch_ui(branch_key: String) -> void:
	var nodes_data: Array = SkillTree.NODES.get(branch_key, [])
	if nodes_data.is_empty():
		return

	var pts_in: int = int(PlayerData.spent_points.get(branch_key, 0))
	var can_buy: bool = PlayerData.skill_points > 0 and pts_in < nodes_data.size()

	# Заголовок ветки
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	_skill_tree_container.add_child(hdr)

	var branch_name_lbl := Label.new()
	branch_name_lbl.text = "  %s" % _branch_display_name(branch_key)
	branch_name_lbl.add_theme_font_size_override("font_size", 12)
	branch_name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	branch_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(branch_name_lbl)

	var progress_lbl := Label.new()
	progress_lbl.text = "%d / %d" % [pts_in, nodes_data.size()]
	progress_lbl.add_theme_font_size_override("font_size", 11)
	progress_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	hdr.add_child(progress_lbl)

	if can_buy:
		var buy_btn := Button.new()
		buy_btn.text = "+ Купить"
		buy_btn.add_theme_font_size_override("font_size", 11)
		buy_btn.custom_minimum_size = Vector2(78, 22)
		buy_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		UIStyle.apply_btn(buy_btn, Color(0.25, 0.55, 0.25))
		buy_btn.pressed.connect(_on_spend_skill_point.bind(branch_key))
		hdr.add_child(buy_btn)

	# Список узлов ветки
	for i: int in range(nodes_data.size()):
		var nd: Array = nodes_data[i]
		var unlocked: bool = pts_in > i
		var is_next: bool  = pts_in == i

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_skill_tree_container.add_child(row)

		# Статус
		var status_lbl := Label.new()
		if unlocked:
			status_lbl.text = "  ✓"
			status_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 0.35))
		elif is_next:
			status_lbl.text = "  ▷"
			status_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3))
		else:
			status_lbl.text = "  ○"
			status_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		status_lbl.add_theme_font_size_override("font_size", 12)
		status_lbl.custom_minimum_size.x = 28
		row.add_child(status_lbl)

		# Тип узла
		var type_lbl := Label.new()
		match str(nd[0]):
			"passive":  type_lbl.text = "[П]"
			"active":   type_lbl.text = "[А]"
			"ultimate": type_lbl.text = "[У]"
			_:          type_lbl.text = "[?]"
		type_lbl.add_theme_font_size_override("font_size", 10)
		type_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		type_lbl.custom_minimum_size.x = 26
		row.add_child(type_lbl)

		# Название и описание
		var info_col := VBoxContainer.new()
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_col)

		var name_lbl := Label.new()
		name_lbl.text = str(nd[1])
		name_lbl.add_theme_font_size_override("font_size", 12)
		if unlocked:
			name_lbl.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75))
		elif is_next:
			name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		else:
			name_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		info_col.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = str(nd[2])
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_col.add_child(desc_lbl)


func _on_spend_skill_point(branch_key: String) -> void:
	var st := _get_skill_tree()
	if st == null:
		return
	if st.spend_point(branch_key):
		_refresh_skill_tree.call_deferred()


func _get_skill_tree() -> SkillTree:
	var nodes := get_tree().get_nodes_in_group("skill_tree")
	return nodes[0] as SkillTree if not nodes.is_empty() else null


func _branch_display_name(branch_key: String) -> String:
	match branch_key:
		"general":          return "Общие навыки"
		"warrior_berserk":  return "Берсерк"
		"warrior_tank":     return "Танк"
		"warrior_paladin":  return "Паладин"
		"mage_fire":        return "Огонь"
		"mage_ice":         return "Лёд"
		"mage_lightning":   return "Молния"
		"rogue_glass":      return "Стеклянная пушка"
		"rogue_stealth":    return "Стелс"
		"rogue_poison":     return "Яд"
		_:                  return branch_key


func _refresh_quests() -> void:
	var stage: int = PlayerData.quest_stage

	if stage == 0:
		_quest_text.text = "  Нет активных заданий.\n\n  Поговори со Старейшиной в городе."
		return

	if stage == 4:
		_quest_text.text = "  ✓  Все задания выполнены!\n\n  Деревня в безопасности. Награды получены."
		return

	if stage == 1:
		var progress: String = "%d / %d" % [PlayerData.quest_kills, QuestSystem.KILL_TARGET]
		var ready: bool = QuestSystem.is_stage_ready()
		_quest_text.text = "  ◆  [1/3] Зачистка данжа\n\n  Уничтожь %d монстров.\n  Прогресс: %s\n  Награда: %d золотых\n\n%s" % [
			QuestSystem.KILL_TARGET, progress, QuestSystem.REWARD_STAGE_1,
			"  → Вернись к Старейшине!" if ready else ""]
		return

	if stage == 2:
		var status: String = "  Печать: Не найдена" if not PlayerData.quest_has_seal else "  Печать: ✓ Найдена!"
		_quest_text.text = "  ◆  [2/3] Знак элитного стража\n\n  Найди элитного врага (фиолетовый),\n  убей его и подбери Печать.\n  Награда: %d золотых\n\n%s%s" % [
			QuestSystem.REWARD_STAGE_2, status,
			"\n\n  → Вернись к Старейшине!" if PlayerData.quest_has_seal else ""]
		return

	if stage == 3:
		var status: String = "  Страж: Ещё жив" if not PlayerData.quest_boss_killed else "  Страж: ✓ Повержен!"
		_quest_text.text = "  ◆  [3/3] Страж Данжа\n\n  Найди и убей главного босса данжа.\n  Награда: %d золотых\n\n%s%s" % [
			QuestSystem.REWARD_STAGE_3, status,
			"\n\n  → Вернись к Старейшине!" if PlayerData.quest_boss_killed else ""]
		return


# ---------------------------------------------------------------------------
# Обработчики — Экипировка
# ---------------------------------------------------------------------------

func _on_equip_slot_clicked(slot: int) -> void:
	var inv := _get_inventory()
	if inv == null:
		return
	var item: ItemResource = inv.get_equipped_item(slot)
	if item == null:
		_equip_selected_slot = -1
		_equip_action_row.hide()
		return
	_equip_selected_slot = slot
	_equip_item_lbl.text = "[%s]  %s\n%s" % [
		_rarity_name(item.rarity), item.display_name, item.bonus_summary()
	]
	_equip_action_row.show()


func _on_equip_unequip_selected() -> void:
	if _equip_selected_slot < 0:
		return
	var inv := _get_inventory()
	if inv == null:
		return
	inv.unequip_slot(_equip_selected_slot)
	_equip_selected_slot = -1
	_equip_action_row.hide()
	_refresh_equip()
	_refresh_bag()


# ---------------------------------------------------------------------------
# Обработчики — Инвентарь
# ---------------------------------------------------------------------------

func _on_bag_slot_hovered(idx: int) -> void:
	var inv := _get_inventory()
	if inv == null:
		return
	var bag := inv.get_bag()
	if idx >= bag.size():
		return
	var item: ItemResource = bag[idx]
	_tooltip_name_lbl.text = item.display_name
	_tooltip_name_lbl.add_theme_color_override("font_color", item.rarity_color())
	var slot_str: String = EQUIP_SLOTS[item.slot] if not item.is_junk else "Мусор"
	var bonuses: String = item.bonus_summary()
	_tooltip_stats_lbl.text = "%s  •  %s%s" % [
		_rarity_name(item.rarity), slot_str,
		("\n" + bonuses) if not bonuses.is_empty() else ""
	]
	_tooltip_sell_lbl.text = "Продать: %d зол." % item.sell_value()
	_tooltip_box.show()


func _on_bag_slot_hover_end() -> void:
	if _tooltip_box != null:
		_tooltip_box.hide()


func _on_bag_slot_clicked(idx: int) -> void:
	# Снять выделение с предыдущего
	if _selected_bag_idx >= 0 and _selected_bag_idx < _bag_slots.size():
		_bag_slots[_selected_bag_idx].button_pressed = false

	if _selected_bag_idx == idx:
		# Повторный клик — снимаем выделение
		_selected_bag_idx = -1
		_bag_action_panel.hide()
		_bag_info_label.text = ""
		return

	_selected_bag_idx = idx
	_bag_slots[idx].button_pressed = true

	var inv := _get_inventory()
	if inv == null:
		return
	var bag := inv.get_bag()
	if idx >= bag.size():
		return
	var item: ItemResource = bag[idx]

	var sell_price: String = "  Продать: %d зол." % item.sell_value()
	if item.is_junk:
		_bag_info_label.text = "[Мусор]  %s\n%s" % [item.display_name, sell_price]
		_bag_equip_btn.hide()
		_bag_sell_btn.show()
	else:
		_bag_info_label.text = "[%s]  %s\n%s\n%s" % [
			_rarity_name(item.rarity), item.display_name,
			item.bonus_summary(), sell_price
		]
		_bag_equip_btn.show()
		_bag_sell_btn.show()

	_bag_action_panel.show()


func _on_bag_equip() -> void:
	if _selected_bag_idx < 0:
		return
	var inv := _get_inventory()
	if inv == null:
		return
	var bag := inv.get_bag()
	if _selected_bag_idx >= bag.size():
		return
	inv.equip_item(bag[_selected_bag_idx])
	_refresh_bag()
	_refresh_equip()


func _on_bag_sell() -> void:
	if _selected_bag_idx < 0:
		return
	var inv := _get_inventory()
	if inv == null:
		return
	var bag := inv.get_bag()
	if _selected_bag_idx >= bag.size():
		return
	# sell_item_from_bag уже вызывает PlayerData.add_gold() — не дублируем
	inv.sell_item_from_bag(bag[_selected_bag_idx])
	_refresh_bag()


func _on_bag_drop() -> void:
	if _selected_bag_idx < 0:
		return
	var inv := _get_inventory()
	if inv == null:
		return
	var bag := inv.get_bag()
	if _selected_bag_idx >= bag.size():
		return
	inv.drop_item(bag[_selected_bag_idx])
	_refresh_bag()


func _on_attr_plus(key: String) -> void:
	var stats := _get_stats()
	if stats == null:
		return
	stats.spend_points(key)
	_refresh_attrs()


# ---------------------------------------------------------------------------
# Вспомогательные методы
# ---------------------------------------------------------------------------

func _get_inventory() -> Inventory:
	var nodes := get_tree().get_nodes_in_group("inventory")
	return nodes[0] as Inventory if not nodes.is_empty() else null


func _get_stats() -> StatsComponent:
	for p in get_tree().get_nodes_in_group("player"):
		var s := p.get_node_or_null("StatsComponent") as StatsComponent
		if s != null:
			return s
	return null


func _rarity_name(rarity: int) -> String:
	match rarity:
		ItemResource.Rarity.UNCOMMON: return "Необычный"
		ItemResource.Rarity.RARE:     return "Редкий"
		ItemResource.Rarity.EPIC:     return "Эпический"
		_:                             return "Обычный"
