class_name MainMenu
extends Node2D

## Главное меню игры. Стартовая сцена.
## Project Settings → Application → Run → Main Scene = res://scenes/main_menu.tscn

func _ready() -> void:
	get_tree().paused = false

	var canvas := CanvasLayer.new()
	add_child(canvas)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)

	# Фон.
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.10)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	# Центральная колонка.
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.set_anchor(SIDE_LEFT,   0.5)
	vbox.set_anchor(SIDE_RIGHT,  0.5)
	vbox.set_anchor(SIDE_TOP,    0.5)
	vbox.set_anchor(SIDE_BOTTOM, 0.5)
	vbox.set_offset(SIDE_LEFT,   -180.0)
	vbox.set_offset(SIDE_RIGHT,   180.0)
	vbox.set_offset(SIDE_TOP,    -140.0)
	vbox.set_offset(SIDE_BOTTOM,  140.0)
	root.add_child(vbox)

	# Название игры.
	var title := Label.new()
	title.text = "ХРОНИКИ\nОДНОГО ГЕРОЯ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var btn_new := Button.new()
	btn_new.text = "Новая игра"
	btn_new.custom_minimum_size = Vector2(360, 48)
	btn_new.pressed.connect(_on_new_game)
	UIStyle.apply_btn(btn_new, UIStyle.COLOR_HEADING)
	vbox.add_child(btn_new)

	var btn_quit := Button.new()
	btn_quit.text = "Выход"
	btn_quit.custom_minimum_size = Vector2(360, 48)
	btn_quit.pressed.connect(_on_quit)
	UIStyle.apply_btn(btn_quit)
	vbox.add_child(btn_quit)

	# Версия.
	var version := Label.new()
	version.text = "v0.6-dev"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.set_offset(SIDE_LEFT, -100.0)
	version.set_offset(SIDE_TOP, -32.0)
	version.add_theme_font_size_override("font_size", 13)
	version.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	root.add_child(version)


func _on_new_game() -> void:
	# Сброс данных на старте новой игры
	PlayerData.gold = 0
	PlayerData.potion_slots = [0, 0, 0, 0]
	PlayerData.quest_stage = 0
	PlayerData.quest_kills = 0
	PlayerData.quest_has_seal = false
	PlayerData.quest_boss_killed = false
	PlayerData.was_resurrected = false
	PlayerData.player_class = PlayerData.CLASS_NONE
	PlayerData.ability_unlocked = [false, false, false]
	PlayerData.saved_level = 1
	PlayerData.saved_xp = 0
	PlayerData.saved_str = 5.0
	PlayerData.saved_dex = 5.0
	PlayerData.saved_end = 5.0
	PlayerData.saved_int = 5.0
	PlayerData.saved_arc = 5.0
	PlayerData.saved_lck = 5.0
	PlayerData.saved_attr_points = 0
	get_tree().change_scene_to_file("res://scenes/town.tscn")


func _on_quit() -> void:
	get_tree().quit()
