class_name DungeonGate
extends Node2D

## Ворота данжа в городе. Игрок подходит и нажимает E, чтобы войти.

var _player_nearby: bool = false
var _prompt_label: Label

func _ready() -> void:
	_build_visual()
	_build_area()


func _build_visual() -> void:
	# Ворота — тёмно-серый прямоугольник
	var gate := ColorRect.new()
	gate.color = Color(0.2, 0.15, 0.1)
	gate.size = Vector2(60, 80)
	gate.position = Vector2(-30, -80)
	add_child(gate)

	# Арка (декоративная)
	var arch := ColorRect.new()
	arch.color = Color(0.35, 0.25, 0.15)
	arch.size = Vector2(80, 20)
	arch.position = Vector2(-40, -90)
	add_child(arch)

	var lbl := Label.new()
	lbl.text = "Данж"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	lbl.position = Vector2(-20, -108)
	lbl.size = Vector2(60, 20)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)

	_prompt_label = Label.new()
	_prompt_label.text = "[E] Войти в данж"
	_prompt_label.add_theme_font_size_override("font_size", 11)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
	_prompt_label.position = Vector2(-50, -124)
	_prompt_label.size = Vector2(120, 20)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.hide()
	add_child(_prompt_label)


func _build_area() -> void:
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(100, 100)
	shape.shape = rect
	area.add_child(shape)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)


func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and event.is_action_pressed("interact"):
		get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		_prompt_label.show()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		_prompt_label.hide()
