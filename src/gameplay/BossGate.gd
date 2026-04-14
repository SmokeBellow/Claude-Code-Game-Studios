class_name BossGate
extends Node2D

## Ворота перед боссом на 3-м этаже.
## Изначально заблокированы физически. Открываются анимацией сдвига вправо
## после гибели всех стражей.

## Размер ворот в пикселях (выставляется FloorScene до add_child)
var gate_width: float = 80.0
var gate_height: float = 60.0

var _body: StaticBody2D
var _visual: ColorRect
var _opened: bool = false

const GATE_COLOR := Color(0.45, 0.35, 0.20)
const OPEN_COLOR := Color(0.45, 0.35, 0.20, 0.0)


func _ready() -> void:
	_build()


func _build() -> void:
	# Визуал
	_visual = ColorRect.new()
	_visual.color = GATE_COLOR
	_visual.size = Vector2(gate_width, gate_height)
	add_child(_visual)

	# Декоративные полосы
	for i in range(3):
		var bar := ColorRect.new()
		bar.color = Color(0.3, 0.22, 0.12)
		bar.size = Vector2(gate_width, 4)
		bar.position = Vector2(0, 6 + i * (gate_height / 3))
		_visual.add_child(bar)

	# Коллизия
	_body = StaticBody2D.new()
	_body.position = Vector2(gate_width * 0.5, gate_height * 0.5)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(gate_width, gate_height)
	cs.shape = shape
	_body.add_child(cs)
	add_child(_body)


## Открывает ворота: анимация сдвига вправо + удаление коллизии.
func open() -> void:
	if _opened:
		return
	_opened = true

	# Отключаем коллизию сразу
	_body.collision_layer = 0
	_body.collision_mask  = 0

	# Анимация: ворота сдвигаются вправо на свою ширину
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_visual, "position:x", gate_width, 0.6)
	tween.parallel().tween_property(_visual, "modulate:a", 0.0, 0.5).set_delay(0.15)
	tween.tween_callback(queue_free)
