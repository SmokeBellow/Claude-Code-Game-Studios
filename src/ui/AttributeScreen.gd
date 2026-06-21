class_name AttributeScreen
extends CanvasLayer

## Экран прокачки атрибутов. Появляется при level up.
## UI генерируется программно — не нужно настраивать в редакторе.
## [br]
## Добавь как дочерний узел main.tscn и заполни [member stats] и [member player].

var stats: StatsComponent

# Названия атрибутов для отображения.
const ATTR_LABELS: Dictionary = {
	"strength":     "Сила",
	"dexterity":    "Ловкость",
	"endurance":    "Выносливость",
	"intelligence": "Интеллект",
	"arcana":       "Аркана",
	"luck":         "Удача",
}

var _points_label: Label
var _value_labels: Dictionary = {}  # attr_name → Label
var _root: Control  # скрываем Control, а не CanvasLayer

func _ready() -> void:
	add_to_group("attribute_screen")
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Находим StatsComponent игрока автоматически.
	for p in get_tree().get_nodes_in_group("player"):
		stats = p.get_node_or_null("StatsComponent") as StatsComponent
		if stats != null:
			break
	_build_ui()


## Возвращает true если экран прокачки сейчас открыт.
func is_open() -> bool:
	return _root != null and _root.visible


## Вызывается из Main.gd при level up.
func show_level_up(new_level: int, points: int) -> void:
	if stats == null:
		return
	stats.add_attribute_points(points)
	_refresh()
	_root.visible = true
	get_tree().paused = true


# ---------------------------------------------------------------------------
# Построение UI
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# Корневой Control — его скрываем/показываем (CanvasLayer не имеет visible).
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	# Затемнение фона.
	var bg := ColorRect.new()
	bg.color = UIStyle.COLOR_OVERLAY_MODAL
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	# Центральная панель — центрируем через якоря + отступы.
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel_style())
	var pw: float = 320.0
	var ph: float = 420.0
	panel.set_anchor(SIDE_LEFT,   0.5)
	panel.set_anchor(SIDE_RIGHT,  0.5)
	panel.set_anchor(SIDE_TOP,    0.5)
	panel.set_anchor(SIDE_BOTTOM, 0.5)
	panel.set_offset(SIDE_LEFT,   -pw / 2.0)
	panel.set_offset(SIDE_RIGHT,   pw / 2.0)
	panel.set_offset(SIDE_TOP,    -ph / 2.0)
	panel.set_offset(SIDE_BOTTOM,  ph / 2.0)
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   14)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Заголовок.
	var title := Label.new()
	title.text = "Повышение уровня!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", UIStyle.COLOR_HEADING)
	vbox.add_child(title)

	# Счётчик очков.
	_points_label = Label.new()
	_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_points_label.add_theme_font_size_override("font_size", 15)
	_points_label.add_theme_color_override("font_color", UIStyle.COLOR_SUCCESS)
	vbox.add_child(_points_label)

	vbox.add_child(UIStyle.separator())

	# Строки атрибутов.
	for attr_name in ATTR_LABELS.keys():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vbox.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = ATTR_LABELS[attr_name]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_color_override("font_color", UIStyle.COLOR_TEXT)
		row.add_child(name_lbl)

		var val_lbl := Label.new()
		val_lbl.custom_minimum_size = Vector2(32, 0)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val_lbl)
		_value_labels[attr_name] = val_lbl

		var btn := Button.new()
		btn.text = "+"
		btn.custom_minimum_size = Vector2(32, 32)
		btn.pressed.connect(_on_plus_pressed.bind(attr_name))
		UIStyle.apply_btn(btn)
		row.add_child(btn)

	vbox.add_child(UIStyle.separator())

	# Кнопка подтвердить.
	var confirm := Button.new()
	confirm.text = "Подтвердить"
	confirm.custom_minimum_size.y = 36
	confirm.pressed.connect(_on_confirm)
	UIStyle.apply_btn(confirm)
	vbox.add_child(confirm)


func _refresh() -> void:
	if stats == null:
		return
	_points_label.text = "Очки атрибутов: %d" % stats.attribute_points
	_value_labels["strength"].text    = str(int(stats.strength))
	_value_labels["dexterity"].text   = str(int(stats.dexterity))
	_value_labels["endurance"].text   = str(int(stats.endurance))
	_value_labels["intelligence"].text = str(int(stats.intelligence))
	_value_labels["arcana"].text      = str(int(stats.arcana))
	_value_labels["luck"].text        = str(int(stats.luck))


# ---------------------------------------------------------------------------
# Обработчики
# ---------------------------------------------------------------------------

func _on_plus_pressed(attr_name: String) -> void:
	if stats == null:
		return
	stats.spend_points(attr_name)
	_refresh()
	# Автозакрытие когда все очки потрачены.
	if stats.attribute_points <= 0:
		_on_confirm()


func _on_confirm() -> void:
	_root.visible = false
	get_tree().paused = false
