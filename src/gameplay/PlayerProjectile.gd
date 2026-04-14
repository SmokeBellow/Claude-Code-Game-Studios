class_name PlayerProjectile
extends Area2D

## Снаряд, выпущенный игроком (маг / Веер клинков плута).
## При столкновении с врагом наносит урон и опционально применяет статус-эффект.

enum Effect { NONE, SLOW, STUN, AOE }

# ---------------------------------------------------------------------------
# Параметры (задаются через init() после instantiate)
# ---------------------------------------------------------------------------

var damage: float      = 20.0
var speed: float       = 450.0
var range_left: float  = 500.0   # Максимальное расстояние пролёта
var direction: Vector2 = Vector2.RIGHT

var effect: Effect     = Effect.NONE
var effect_duration: float = 2.0
var effect_value: float    = 0.4  # mult для SLOW, радиус для AOE

# ---------------------------------------------------------------------------
# Внутреннее состояние
# ---------------------------------------------------------------------------

var _color: Color = Color(0.4, 0.6, 1.0)   # синий по умолчанию (маг)
var _hit: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	connect("body_entered", _on_body_entered)
	connect("area_entered",  _on_area_entered)

	# Рисуем простой кружок (placeholder до появления спрайтов)
	var vis := VisibleOnScreenNotifier2D.new()
	add_child(vis)

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	col.shape = shape
	add_child(col)


func _process(delta: float) -> void:
	if _hit:
		return
	var move: float = speed * delta
	range_left -= move
	position += direction * move
	if range_left <= 0.0:
		queue_free()


# ---------------------------------------------------------------------------
# Инициализация
# ---------------------------------------------------------------------------

## Настроить снаряд после спавна.
func init(dir: Vector2, dmg: float, spd: float, rng: float,
		  eff: Effect = Effect.NONE, eff_dur: float = 2.0,
		  eff_val: float = 0.4, col: Color = Color(0.4, 0.6, 1.0)) -> void:
	direction       = dir.normalized()
	damage          = dmg
	speed           = spd
	range_left      = rng
	effect          = eff
	effect_duration = eff_dur
	effect_value    = eff_val
	_color          = col
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color(_color.r, _color.g, _color.b, 0.25))
	draw_circle(Vector2.ZERO, 8.0, _color)


# ---------------------------------------------------------------------------
# Коллизии
# ---------------------------------------------------------------------------

func _on_body_entered(body: Node) -> void:
	if body is StaticBody2D:
		queue_free()
		return
	_try_hit(body)


func _on_area_entered(area: Node) -> void:
	_try_hit(area)


func _try_hit(node: Node) -> void:
	if _hit:
		return
	# Попадаем только во врагов
	if not node.is_in_group("enemies"):
		return
	_hit = true

	_apply_damage(node)

	if effect == Effect.AOE:
		_apply_aoe()

	# VFX при попадании
	match effect:
		Effect.SLOW:
			AbilityVFX.spawn_mage_ice_hit(get_tree(), global_position)
		Effect.AOE:
			AbilityVFX.spawn_mage_fireball_explosion(get_tree(), global_position, effect_value)

	queue_free()


func _apply_damage(enemy: Node) -> void:
	var hp: HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent
	if hp != null and not hp.is_dead:
		hp.take_damage(damage)
	_apply_effect(enemy)


func _apply_effect(enemy: Node) -> void:
	if not enemy is BaseEnemy:
		return
	var e: BaseEnemy = enemy as BaseEnemy
	match effect:
		Effect.SLOW:
			e.apply_slow(effect_duration, effect_value)
		Effect.STUN:
			e.apply_stun(effect_duration)
		_:
			pass  # NONE и AOE-урон обрабатывается отдельно


func _apply_aoe() -> void:
	# AOE: ищем всех врагов в радиусе effect_value
	var bodies := get_tree().get_nodes_in_group("enemies")
	for body in bodies:
		if body is BaseEnemy and is_instance_valid(body):
			var dist: float = (body as Node2D).global_position.distance_to(global_position)
			if dist <= effect_value:
				_apply_damage(body)
