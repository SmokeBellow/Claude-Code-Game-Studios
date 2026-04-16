class_name PuzzleTrigger
extends Area2D

## Интерактивный рычаг для головоломки этажа 3.
## Игрок подходит и нажимает "interact", чтобы переключить состояние (UP/DOWN).
## Правильная комбинация: left=DOWN, center=UP, right=DOWN.

@export var lever_name: String = "left"
@export var initial_state: bool = true   ## true = UP, false = DOWN

signal state_changed(lever_name: String, new_state: bool)

var state: bool = true
var _player_nearby: bool = false

var _handle: ColorRect
var _arrow: Label
var _prompt: Label


func _ready() -> void:
	state = initial_state
	_build_visual()
	_build_area()


func _build_visual() -> void:
	# Основание рычага
	var base := ColorRect.new()
	base.color = Color(0.25, 0.22, 0.18)
	base.size = Vector2(20.0, 8.0)
	base.position = Vector2(-10.0, 6.0)
	add_child(base)

	# Рукоятка — положение и цвет зависят от state
	_handle = ColorRect.new()
	_handle.size = Vector2(6.0, 20.0)
	add_child(_handle)

	# Стрелка-индикатор
	_arrow = Label.new()
	_arrow.add_theme_font_size_override("font_size", 14)
	_arrow.size = Vector2(20.0, 16.0)
	_arrow.position = Vector2(-10.0, -40.0)
	_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_arrow)

	# Подсказка взаимодействия
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 12)
	_prompt.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
	_prompt.text = "[F] Потянуть"
	_prompt.position = Vector2(-40.0, -58.0)
	_prompt.visible = false
	add_child(_prompt)

	_refresh_visuals()


func _build_area() -> void:
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 36.0
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and event.is_action_pressed("interact"):
		state = not state
		_refresh_visuals()
		state_changed.emit(lever_name, state)


func _refresh_visuals() -> void:
	if state:
		# UP
		_handle.color = Color(0.70, 0.55, 0.20)
		_handle.position = Vector2(-3.0, -20.0)
		_arrow.text = "↑"
	else:
		# DOWN
		_handle.color = Color(0.35, 0.27, 0.10)
		_handle.position = Vector2(0.0, -10.0)
		_arrow.text = "↓"


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		_prompt.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		_prompt.visible = false
