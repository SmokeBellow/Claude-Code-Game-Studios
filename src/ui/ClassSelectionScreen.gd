class_name ClassSelectionScreen
extends CanvasLayer

## Экран выбора класса. Показывается при достижении 3-го уровня (если класс не выбран).
## Устанавливает PlayerData.player_class, применяет бонусы и разблокирует первое умение.

# ---------------------------------------------------------------------------
# Данные классов
# ---------------------------------------------------------------------------

const CLASS_DATA: Array[Dictionary] = [
	{
		"id":    PlayerData.CLASS_WARRIOR,
		"name":  "Воин",
		"icon":  "⚔",
		"color": Color(0.95, 0.45, 0.3),
		"desc":  "Прочный боец ближнего боя.\nПрибавляет Силу +5 и Выносливость +4.",
		"abilities": ["[R] Оглушение — станит ближних врагов",
					  "[F] Мощный удар — следующая атака ×3",
					  "[G] Укрепление — временный запас HP"],
	},
	{
		"id":    PlayerData.CLASS_MAGE,
		"name":  "Маг",
		"icon":  "✦",
		"color": Color(0.4, 0.6, 1.0),
		"desc":  "Дальний урон и контроль.\nПрибавляет Интеллект +5 и Аркану +5.",
		"abilities": ["[R] Огненный шар — AOE взрыв",
					  "[F] Ледяная стрела — замедление",
					  "[G] Магический щит — поглощение урона"],
	},
	{
		"id":    PlayerData.CLASS_ROGUE,
		"name":  "Плут",
		"icon":  "◆",
		"color": Color(0.3, 0.85, 0.6),
		"desc":  "Скорость и уклонение.\nПрибавляет Ловкость +5 и Удачу +3.",
		"abilities": ["[R] Дымовая бомба — снижает точность врагов",
					  "[F] Веер клинков — 5 снарядов в дуге",
					  "[G / ПКМ] Парирование"],
	},
]

# ---------------------------------------------------------------------------
# Сигналы
# ---------------------------------------------------------------------------

## Испускается после выбора класса.
signal class_chosen(player_class: int)

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	layer = 20
	process_mode = PROCESS_MODE_ALWAYS
	_build()
	visible = false


# ---------------------------------------------------------------------------
# Публичный API
# ---------------------------------------------------------------------------

## Показывает экран и ставит игру на паузу.
func show_selection() -> void:
	visible = true
	get_tree().paused = true

# ---------------------------------------------------------------------------
# Построение UI
# ---------------------------------------------------------------------------

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.78)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 18)
	outer.custom_minimum_size.x = 660
	center.add_child(outer)

	# Заголовок
	var title := Label.new()
	title.text = "Выбери класс"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	outer.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Это решение необратимо. Первое умение откроется сразу."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	outer.add_child(subtitle)

	# Карточки
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	outer.add_child(row)

	for data: Dictionary in CLASS_DATA:
		row.add_child(_make_card(data))


func _make_card(data: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 1.0)
	var c: Color = data["color"]
	style.border_color = c
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left   = 12.0
	style.content_margin_right  = 12.0
	style.content_margin_top    = 12.0
	style.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	# Иконка
	var icon_lbl := Label.new()
	icon_lbl.text = data["icon"]
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 40)
	icon_lbl.add_theme_color_override("font_color", c)
	vbox.add_child(icon_lbl)

	# Название
	var name_lbl := Label.new()
	name_lbl.text = data["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", c)
	vbox.add_child(name_lbl)

	vbox.add_child(UIStyle.separator())

	# Краткое описание (бонусы стата)
	var desc_lbl := Label.new()
	desc_lbl.text = data["desc"]
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(desc_lbl)

	vbox.add_child(UIStyle.separator())

	# Умения
	var abilities_lbl := Label.new()
	var lines: PackedStringArray = []
	for ab: String in data["abilities"]:
		lines.append(ab)
	abilities_lbl.text = "\n".join(lines)
	abilities_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	abilities_lbl.add_theme_font_size_override("font_size", 11)
	abilities_lbl.add_theme_color_override("font_color", Color(0.55, 0.8, 0.55))
	vbox.add_child(abilities_lbl)

	vbox.add_child(UIStyle.separator())

	# Кнопка выбора
	var btn := Button.new()
	btn.text = "Выбрать — %s" % data["name"]
	btn.custom_minimum_size.y = 36
	btn.add_theme_font_size_override("font_size", 13)
	UIStyle.apply_btn(btn, c)
	btn.pressed.connect(_on_class_chosen.bind(data["id"]))
	vbox.add_child(btn)

	return card

# ---------------------------------------------------------------------------
# Обработчики
# ---------------------------------------------------------------------------

func _on_class_chosen(player_class: int) -> void:
	PlayerData.player_class = player_class

	# Применяем бонусы к StatsComponent игрока
	for p: Node in get_tree().get_nodes_in_group("player"):
		var stats := p.get_node_or_null("StatsComponent") as StatsComponent
		if stats != null:
			PlayerData.apply_class_stats(stats)
			break

	class_chosen.emit(player_class)
	get_tree().paused = false
	queue_free()
