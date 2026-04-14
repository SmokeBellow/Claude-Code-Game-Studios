class_name Projectile
extends Area2D

## Снаряд дальнего врага. Летит по прямой, наносит урон при касании с игроком.
## Создаётся RangedEnemy и добавляется в Main.

var _velocity: Vector2 = Vector2.ZERO
var _damage: float = 0.0
var _dist_left: float = 400.0

func _ready() -> void:
	# Визуал — маленький оранжевый октагон.
	var poly := Polygon2D.new()
	var pts: PackedVector2Array = []
	for i in range(8):
		var a: float = i * TAU / 8.0
		pts.append(Vector2(cos(a), sin(a)) * 6.0)
	poly.polygon = pts
	poly.color = Color(1.0, 0.65, 0.1)
	add_child(poly)

	body_entered.connect(_on_body_entered)

	# Самоуничтожение по таймеру на случай промаха.
	get_tree().create_timer(3.0).timeout.connect(func(): if is_instance_valid(self): queue_free())


## Инициализирует снаряд после add_child.
func init(direction: Vector2, speed: float, damage: float) -> void:
	_velocity = direction * speed
	_damage = damage


func _physics_process(delta: float) -> void:
	var move: Vector2 = _velocity * delta
	global_position += move
	_dist_left -= move.length()
	if _dist_left <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body is StaticBody2D:
		queue_free()
		return
	if not body.is_in_group("player"):
		return
	var combat: CombatComponent = body.get_node_or_null("CombatComponent") as CombatComponent
	if combat != null and combat.notify_parry_hit():
		queue_free()
		return
	var hp: HealthComponent = body.get_node_or_null("HealthComponent") as HealthComponent
	if hp != null and not hp.is_dead:
		hp.take_damage(_damage)
	queue_free()
