class_name DialogueScreen
extends CanvasLayer

## Экран диалога в стиле визуальной новеллы.
## Показывает портрет персонажа, имя, текст и кнопки выбора.
## Использует дерево диалогов: Dictionary { "text", "speaker", "portrait_color", "choices" }
## choices — Array[Dictionary] с ключами "label" и "next" (имя следующего узла или "").

signal dialogue_ended

## Дерево диалогов: node_id -> Dictionary
var _tree: Dictionary = {}
var _current_node: String = ""

# ---------------------------------------------------------------------------
# Узлы (созданы в _ready через код, без .tscn)
# ---------------------------------------------------------------------------

var _panel: Panel
var _portrait: ColorRect
var _speaker_label: Label
var _text_label: RichTextLabel
var _choices_container: VBoxContainer
var _continue_button: Button

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	layer = 25
	add_to_group("dialogue_screen")
	_build_ui()
	hide()
	process_mode = PROCESS_MODE_ALWAYS


func _build_ui() -> void:
	# Затемняющий фон
	var bg := ColorRect.new()
	bg.color = UIStyle.COLOR_OVERLAY_MODAL
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Панель диалога — нижние 35% экрана через якоря, без пиксельных размеров
	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", UIStyle.panel_style())
	_panel.set_anchor(SIDE_LEFT,   0.0)
	_panel.set_anchor(SIDE_RIGHT,  1.0)
	_panel.set_anchor(SIDE_TOP,    0.65)
	_panel.set_anchor(SIDE_BOTTOM, 1.0)
	_panel.set_offset(SIDE_LEFT,   0.0)
	_panel.set_offset(SIDE_RIGHT,  0.0)
	_panel.set_offset(SIDE_TOP,    0.0)
	_panel.set_offset(SIDE_BOTTOM, 0.0)
	add_child(_panel)

	# Горизонтальный корневой контейнер — заполняет панель с отступами
	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left",   16)
	root_margin.add_theme_constant_override("margin_right",  16)
	root_margin.add_theme_constant_override("margin_top",    10)
	root_margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(root_margin)

	var root_hbox := HBoxContainer.new()
	root_hbox.add_theme_constant_override("separation", 14)
	root_margin.add_child(root_hbox)

	# Портрет — фиксированная ширина, растёт по высоте панели
	_portrait = ColorRect.new()
	_portrait.color = Color(0.3, 0.5, 0.8)
	_portrait.custom_minimum_size = Vector2(110, 0)
	_portrait.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_portrait.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	root_hbox.add_child(_portrait)

	# Правая колонка: имя + текст + кнопка/выборы
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 6)
	root_hbox.add_child(right_vbox)

	# Строка: имя говорящего + кнопка «Продолжить»
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	right_vbox.add_child(top_row)

	_speaker_label = Label.new()
	_speaker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.apply_heading(_speaker_label, 18)
	top_row.add_child(_speaker_label)

	_continue_button = Button.new()
	_continue_button.text = "Продолжить  ▶"
	_continue_button.custom_minimum_size = Vector2(160, 36)
	_continue_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_continue_button.pressed.connect(_on_continue)
	UIStyle.apply_btn(_continue_button, UIStyle.COLOR_HEADING)
	top_row.add_child(_continue_button)

	# Текст реплики — RichTextLabel растёт по доступному пространству
	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_text_label.scroll_active = false
	_text_label.add_theme_font_size_override("normal_font_size", 16)
	right_vbox.add_child(_text_label)

	# Контейнер вариантов выбора
	_choices_container = VBoxContainer.new()
	_choices_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choices_container.add_theme_constant_override("separation", 4)
	right_vbox.add_child(_choices_container)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Запускает диалог.
## [param tree] — Dictionary node_id → Dictionary{ speaker, portrait_color, text, choices[] }
## [param start_node] — с какого узла начинать.
func start(tree: Dictionary, start_node: String = "start") -> void:
	_tree = tree
	show()
	_show_node(start_node)


## Закрывает экран диалога.
func close() -> void:
	hide()
	dialogue_ended.emit()


# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _show_node(node_id: String) -> void:
	_current_node = node_id
	var node: Dictionary = _tree.get(node_id, {})
	if node.is_empty():
		close()
		return

	_speaker_label.text = node.get("speaker", "")
	_text_label.text = node.get("text", "")

	var portrait_color: Color = node.get("portrait_color", Color(0.3, 0.5, 0.8))
	_portrait.color = portrait_color

	# Очищаем варианты
	for child in _choices_container.get_children():
		child.queue_free()

	var choices: Array = node.get("choices", [])
	if choices.is_empty():
		_continue_button.show()
		_choices_container.hide()
	else:
		_continue_button.hide()
		_choices_container.show()
		for choice: Dictionary in choices:
			var btn := Button.new()
			btn.text = choice.get("label", "...")
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size.y = 32
			var next: String = choice.get("next", "")
			btn.pressed.connect(_on_choice.bind(next))
			UIStyle.apply_btn(btn, UIStyle.COLOR_HEADING)
			_choices_container.add_child(btn)


func _on_continue() -> void:
	var node: Dictionary = _tree.get(_current_node, {})
	var next: String = node.get("next", "")
	if next == "":
		close()
	else:
		_show_node(next)


func _on_choice(next: String) -> void:
	if next == "":
		close()
	else:
		_show_node(next)
