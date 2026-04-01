class_name FloorChest
extends Area2D

## Сундук с наградой. Открывается клавишей [E].

## Золото за открытие. Выставляется FloorScene перед add_child.
var gold_reward: int = 60

var _player_nearby: bool = false
var _opened: bool = false
var _prompt: Label
var _lid: Node2D


func _ready() -> void:
	_build_visual()
	_build_area()


func _build_visual() -> void:
	# Корпус сундука
	var body := ColorRect.new()
	body.color = Color(0.50, 0.35, 0.15)
	body.size = Vector2(32, 22)
	body.position = Vector2(-16, -11)
	add_child(body)

	# Крышка (анимируется при открытии)
	_lid = Node2D.new()
	_lid.position = Vector2(-16, -11)
	add_child(_lid)
	var lid_rect := ColorRect.new()
	lid_rect.color = Color(0.60, 0.42, 0.18)
	lid_rect.size = Vector2(32, 8)
	_lid.add_child(lid_rect)

	# Замок
	var lock := ColorRect.new()
	lock.color = Color(0.85, 0.70, 0.25)
	lock.size = Vector2(8, 8)
	lock.position = Vector2(-4, -4)
	add_child(lock)

	# Подсказка
	_prompt = Label.new()
	_prompt.text = "[E] Открыть"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-40, -36)
	_prompt.add_theme_font_size_override("font_size", 12)
	_prompt.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
	_prompt.visible = false
	add_child(_prompt)


func _build_area() -> void:
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 44.0
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and not _opened and event.is_action_pressed("interact"):
		_open()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		_prompt.visible = not _opened


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		_prompt.visible = false


func _open() -> void:
	_opened = true
	_prompt.visible = false
	PlayerData.add_gold(gold_reward)

	# Анимация открытия крышки
	var tween := create_tween()
	tween.tween_property(_lid, "rotation_degrees", -80.0, 0.3)

	# Всплывающий текст с наградой
	var lbl := Label.new()
	lbl.text = "+%d золота" % gold_reward
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	lbl.position = Vector2(-30, -50)
	add_child(lbl)
	var tw2 := create_tween()
	tw2.tween_property(lbl, "position:y", -80.0, 1.2)
	tw2.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2)
	tw2.tween_callback(lbl.queue_free)
