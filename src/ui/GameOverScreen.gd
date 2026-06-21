class_name GameOverScreen
extends CanvasLayer

## Экран поражения. Показывается после смерти игрока вместо автовозрождения.
## Создаётся программно в Main._ready().

var _root: Control

func _ready() -> void:
	add_to_group("game_over_screen")
	layer = 20
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
	panel.add_theme_stylebox_override("panel", UIStyle.panel_style())
	var pw: float = 360.0
	var ph: float = 240.0
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
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "ИГРА ОКОНЧЕНА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", UIStyle.COLOR_DANGER)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Герой пал в бою"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", UIStyle.COLOR_TEXT_DIM)
	vbox.add_child(subtitle)

	vbox.add_child(UIStyle.separator())

	var btn_restart := Button.new()
	btn_restart.text = "Играть снова"
	btn_restart.custom_minimum_size = Vector2(320, 44)
	btn_restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_restart.pressed.connect(_on_restart)
	UIStyle.apply_btn(btn_restart)
	vbox.add_child(btn_restart)

	var btn_menu := Button.new()
	btn_menu.text = "В главное меню"
	btn_menu.custom_minimum_size = Vector2(320, 44)
	btn_menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_menu.pressed.connect(_on_menu)
	UIStyle.apply_btn(btn_menu)
	vbox.add_child(btn_menu)


## Показывает экран поражения.
func show_game_over() -> void:
	_root.visible = true
	get_tree().paused = true


func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
