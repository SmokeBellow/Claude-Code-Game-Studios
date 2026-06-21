class_name WinScreen
extends CanvasLayer

## Экран победы над боссом. Показывается поверх всех UI (layer 15 > AttributeScreen 10).
## Создаётся программно в Main._ready().

const FLAVOR_TEXTS: Array[String] = [
	"Данж затих. Но опасность никуда не делась...",
	"Его последний вздох растворился в темноте коридоров.",
	"Победа досталась ценой крови. Путь продолжается.",
	"Тьма рассеялась, но другие стражи ещё ждут тебя.",
	"Ни один страж не устоит перед твоим клинком.",
]

var _root: Control
var _title_label: Label
var _flavor_label: Label
var _xp_label: Label
var _did_pause: bool = false

func _ready() -> void:
	add_to_group("win_screen")
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	# Затемнение.
	var bg := ColorRect.new()
	bg.color = UIStyle.COLOR_OVERLAY_MODAL
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	# Центральная панель.
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel_style())
	var pw: float = 380.0
	var ph: float = 280.0
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
	margin.add_theme_constant_override("margin_left",   16)
	margin.add_theme_constant_override("margin_right",  16)
	margin.add_theme_constant_override("margin_top",    12)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_heading(_title_label, 36)
	vbox.add_child(_title_label)

	vbox.add_child(UIStyle.separator())

	_flavor_label = Label.new()
	_flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIStyle.apply_text(_flavor_label, 16)
	vbox.add_child(_flavor_label)

	_xp_label = Label.new()
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_label.add_theme_font_size_override("font_size", 18)
	_xp_label.add_theme_color_override("font_color", UIStyle.COLOR_SUCCESS)
	vbox.add_child(_xp_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var btn := Button.new()
	btn.text = "Продолжить"
	btn.custom_minimum_size = Vector2(200, 40)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_on_continue)
	UIStyle.apply_btn(btn)
	vbox.add_child(btn)


## Показывает экран с данными поверженного босса.
func show_win(enemy_data: EnemyData) -> void:
	_title_label.text = "%s\nПОВЕРЖЕН" % enemy_data.display_name.to_upper()
	_flavor_label.text = FLAVOR_TEXTS[randi() % FLAVOR_TEXTS.size()]
	_xp_label.text = "+ %d XP" % enemy_data.xp_reward
	_root.visible = true
	if not get_tree().paused:
		get_tree().paused = true
		_did_pause = true


func _on_continue() -> void:
	_root.visible = false
	# Снимаем паузу только если AttributeScreen не держит её.
	var attr := get_tree().get_first_node_in_group("attribute_screen")
	var attr_open: bool = attr != null and attr.has_method("is_open") and attr.is_open()
	if _did_pause and not attr_open:
		get_tree().paused = false
	_did_pause = false
