class_name HitboxFlash
extends Node2D

## Временная визуализация зоны удара — красный сектор на 0.15 сек.
## Placeholder: будет заменён анимацией удара.
## Вызывай: HitboxFlash.spawn(get_tree(), origin, facing, radius, half_arc_deg)

const DURATION:  float = 0.15
const SEGMENTS:  int   = 10
const FILL_COLOR: Color = Color(1.0, 0.15, 0.15, 0.45)

var _radius:       float = 80.0
var _half_arc:     float = 0.96   # радианы
var _facing_angle: float = 0.0
var _elapsed:      float = 0.0


static func spawn(tree: SceneTree, origin: Vector2, facing: Vector2,
		radius: float, half_arc_deg: float) -> void:
	var fx := HitboxFlash.new()
	fx.global_position = origin
	fx._radius         = radius
	fx._half_arc       = deg_to_rad(half_arc_deg)
	fx._facing_angle   = facing.angle()
	fx.z_index         = 10
	tree.root.add_child(fx)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION:
		queue_free()
		return
	modulate.a = 1.0 - (_elapsed / DURATION)
	queue_redraw()


func _draw() -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	for i: int in range(SEGMENTS + 1):
		var t: float    = float(i) / float(SEGMENTS)
		var angle: float = _facing_angle - _half_arc + t * _half_arc * 2.0
		pts.append(Vector2(cos(angle), sin(angle)) * _radius)
	draw_polygon(pts, PackedColorArray([FILL_COLOR]))
