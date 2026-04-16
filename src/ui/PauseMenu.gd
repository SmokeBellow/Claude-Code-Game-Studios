class_name PauseMenu
extends CanvasLayer

## Меню паузы (Escape). Работает в городе и в данже.
## Кнопки: Продолжить / Сохранить / Выход в меню / Выход из игры.
## Сохранение доступно в любой момент — находит Inventory через группу.

const SAVE_FEEDBACK_SEC: float = 2.0

var _root: Control
var _save_feedback: Label
var _save_timer: float = 0.0


func _ready() -> void:
	add_to_group("pause_menu")
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


# ---------------------------------------------------------------------------
# Публичный API
# ---------------------------------------------------------------------------

## Открыть меню паузы.
func open() -> void:
	_root.visible = true
	if not get_tree().paused:
		get_tree().paused = true


## Закрыть меню паузы.
func close() -> void:
	_root.visible = false
	get_tree().paused = false
	_save_feedback.visible = false
	_save_timer = 0.0


# ---------------------------------------------------------------------------
# Ввод
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _root.visible:
		close()
	else:
		open()


func _process(delta: float) -> void:
	if _save_timer > 0.0:
		_save_timer -= delta
		if _save_timer <= 0.0:
			_save_feedback.visible = false


# ---------------------------------------------------------------------------
# Обработчики кнопок
# ---------------------------------------------------------------------------

func _on_save() -> void:
	var inv := get_tree().get_first_node_in_group("inventory") as Inventory
	SaveSystem.save(inv)
	_save_feedback.visible = true
	_save_timer = SAVE_FEEDBACK_SEC


func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_quit() -> void:
	get_tree().quit()


# ---------------------------------------------------------------------------
# Построение UI
# ---------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	# Затемнённый оверлей.
	var bg := ColorRect.new()
	bg.color = UIStyle.COLOR_OVERLAY_MODAL
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	# Центральная панель.
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel_style())
	const PW: float = 340.0
	const PH: float = 320.0
	panel.set_anchor(SIDE_LEFT,   0.5)
	panel.set_anchor(SIDE_RIGHT,  0.5)
	panel.set_anchor(SIDE_TOP,    0.5)
	panel.set_anchor(SIDE_BOTTOM, 0.5)
	panel.set_offset(SIDE_LEFT,   -PW / 2.0)
	panel.set_offset(SIDE_RIGHT,   PW / 2.0)
	panel.set_offset(SIDE_TOP,    -PH / 2.0)
	panel.set_offset(SIDE_BOTTOM,  PH / 2.0)
	_root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.set_anchor(SIDE_LEFT,   0.0)
	vbox.set_anchor(SIDE_RIGHT,  1.0)
	vbox.set_anchor(SIDE_TOP,    0.0)
	vbox.set_anchor(SIDE_BOTTOM, 1.0)
	vbox.set_offset(SIDE_LEFT,    24.0)
	vbox.set_offset(SIDE_RIGHT,  -24.0)
	vbox.set_offset(SIDE_TOP,     24.0)
	vbox.set_offset(SIDE_BOTTOM, -24.0)
	panel.add_child(vbox)

	# Заголовок.
	var title := Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UIStyle.COLOR_HEADING)
	vbox.add_child(title)

	vbox.add_child(UIStyle.separator())

	var spacer_top := Control.new()
	spacer_top.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer_top)

	# Продолжить.
	var btn_resume := Button.new()
	btn_resume.text = "Продолжить"
	btn_resume.custom_minimum_size = Vector2(0, 44)
	btn_resume.pressed.connect(close)
	UIStyle.apply_btn(btn_resume)
	vbox.add_child(btn_resume)

	# Сохранить.
	var btn_save := Button.new()
	btn_save.text = "Сохранить"
	btn_save.custom_minimum_size = Vector2(0, 44)
	btn_save.pressed.connect(_on_save)
	UIStyle.apply_btn(btn_save)
	vbox.add_child(btn_save)

	# Обратная связь «Сохранено ✓».
	_save_feedback = Label.new()
	_save_feedback.text = "Сохранено ✓"
	_save_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_feedback.add_theme_font_size_override("font_size", 14)
	_save_feedback.add_theme_color_override("font_color", UIStyle.COLOR_SUCCESS)
	_save_feedback.visible = false
	vbox.add_child(_save_feedback)

	vbox.add_child(UIStyle.separator())

	# Выход в главное меню.
	var btn_menu := Button.new()
	btn_menu.text = "Выход в главное меню"
	btn_menu.custom_minimum_size = Vector2(0, 44)
	btn_menu.pressed.connect(_on_main_menu)
	UIStyle.apply_btn(btn_menu)
	vbox.add_child(btn_menu)

	# Выход из игры.
	var btn_quit := Button.new()
	btn_quit.text = "Выход из игры"
	btn_quit.custom_minimum_size = Vector2(0, 44)
	btn_quit.pressed.connect(_on_quit)
	UIStyle.apply_btn(btn_quit)
	vbox.add_child(btn_quit)
