class_name NameInputScreen
extends CanvasLayer

## Экран ввода имени героя. Показывается один раз при новой игре.
## Испускает name_confirmed когда игрок ввёл непустое имя.

signal name_confirmed(hero_name: String)

var _line_edit: LineEdit
var _error_label: Label


func _ready() -> void:
	layer = 10
	_build()
	_line_edit.grab_focus.call_deferred()


func _build() -> void:
	# Затемнение фона
	var bg := ColorRect.new()
	bg.color = UIStyle.COLOR_OVERLAY_MODAL
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Центральная панель — пергамент
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(400, 0)
	panel.add_theme_stylebox_override("panel", UIStyle.panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   28)
	margin.add_theme_constant_override("margin_right",  28)
	margin.add_theme_constant_override("margin_top",    24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# Заголовок
	var title := Label.new()
	title.text = "Как зовут героя?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_heading(title, 24)
	vbox.add_child(title)

	vbox.add_child(UIStyle.separator())

	# Поле ввода
	_line_edit = LineEdit.new()
	_line_edit.placeholder_text = "Введите имя..."
	_line_edit.max_length = 20
	_line_edit.custom_minimum_size = Vector2(0, 42)
	_line_edit.text_submitted.connect(_on_confirm)
	UIStyle.apply_line_edit(_line_edit)
	vbox.add_child(_line_edit)

	# Метка ошибки (скрыта по умолчанию)
	_error_label = Label.new()
	_error_label.add_theme_color_override("font_color", Color(1.0, 0.40, 0.30))
	_error_label.add_theme_font_size_override("font_size", 12)
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.visible = false
	vbox.add_child(_error_label)

	# Кнопка подтверждения
	var btn := Button.new()
	btn.text = "Начать приключение"
	btn.custom_minimum_size = Vector2(0, 42)
	btn.pressed.connect(func() -> void: _on_confirm(_line_edit.text))
	UIStyle.apply_btn(btn)
	vbox.add_child(btn)


func _on_confirm(text: String) -> void:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		_error_label.text = "Имя не может быть пустым"
		_error_label.visible = true
		_line_edit.grab_focus()
		return
	name_confirmed.emit(trimmed)
