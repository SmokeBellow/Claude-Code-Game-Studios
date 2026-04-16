class_name PuzzleDoor
extends Node2D

## Дверь-преграда для системы головоломки этажа 3.
## Используется как дверь к комнате загадки (открывается после смерти босса)
## и как дверь к комнате сундука (открывается после решения комбинации рычагов).

var gate_width: float = 80.0
var gate_height: float = 60.0

var _body: StaticBody2D
var _visual: ColorRect
var _opened: bool = false

const GATE_COLOR := Color(0.22, 0.20, 0.18)


func _ready() -> void:
	_build()


func _build() -> void:
	_visual = ColorRect.new()
	_visual.color = GATE_COLOR
	_visual.size = Vector2(gate_width, gate_height)
	add_child(_visual)

	# 4 вертикальных полосы
	for i in range(4):
		var bar := ColorRect.new()
		bar.color = Color(0.14, 0.13, 0.11)
		bar.size = Vector2(4.0, gate_height)
		bar.position = Vector2(4.0 + i * (gate_width / 4.0), 0.0)
		_visual.add_child(bar)

	_body = StaticBody2D.new()
	_body.position = Vector2(gate_width * 0.5, gate_height * 0.5)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(gate_width, gate_height)
	cs.shape = shape
	_body.add_child(cs)
	add_child(_body)


## Открывает дверь: убирает коллизию и воспроизводит анимацию сдвига вправо.
func open() -> void:
	if _opened:
		return
	_opened = true
	_body.collision_layer = 0
	_body.collision_mask  = 0
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_visual, "position:x", gate_width, 0.6)
	tween.parallel().tween_property(_visual, "modulate:a", 0.0, 0.5).set_delay(0.15)


## Закрывает дверь: возвращает коллизию и воспроизводит анимацию сдвига обратно.
func close() -> void:
	if not _opened:
		return
	_opened = false
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_visual, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(_visual, "position:x", 0.0, 0.5)
	tween.tween_callback(_restore_collision)


func _restore_collision() -> void:
	_body.collision_layer = 1
	_body.collision_mask  = 1
