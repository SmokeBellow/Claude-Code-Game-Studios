class_name DashAbility
extends AbilityResource

## Рывок: быстрое перемещение в направлении движения (или взгляда).
## Во время рывка игрок неуязвим и не получает урон.
## [br]
## Привяжи к кнопке [code]ability_primary[/code] (Q) через [Player].

# ---------------------------------------------------------------------------
# Tuning knobs
# ---------------------------------------------------------------------------

## Дистанция рывка в пикселях.
@export var dash_distance: float = 150.0
## Длительность рывка в секундах.
@export var dash_duration: float = 0.2

# ---------------------------------------------------------------------------
# Внутреннее состояние
# ---------------------------------------------------------------------------

var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_velocity: Vector2 = Vector2.ZERO
var _owner_ref: CharacterBody2D = null

# ---------------------------------------------------------------------------
# Публичный API
# ---------------------------------------------------------------------------

func activate(owner: Node) -> bool:
	if not is_ready():
		return false
	if _is_dashing:
		return false

	var body := owner as CharacterBody2D
	if body == null:
		return false

	# Направление: вектор движения или facing если стоит.
	var dir := Vector2.ZERO
	dir.x = float(Input.is_action_pressed("move_right")) - float(Input.is_action_pressed("move_left"))
	dir.y = float(Input.is_action_pressed("move_down"))  - float(Input.is_action_pressed("move_up"))

	if dir == Vector2.ZERO:
		# Стоим — рывок в направлении взгляда.
		var player := owner as Player
		if player != null:
			dir = player.facing_direction
		else:
			dir = Vector2.RIGHT

	dir = dir.normalized()
	_dash_velocity = dir * (dash_distance / dash_duration)
	_dash_timer = dash_duration
	_is_dashing = true
	_owner_ref = body

	# Включаем неуязвимость (движение управляется самим Dash, не блокируем).
	var health := owner.get_node_or_null("HealthComponent") as HealthComponent
	if health != null:
		health.set_invincible(true)

	_start_cooldown()
	return true


## Обновляет рывок. Вызывай каждый кадр из Player._physics_process.
func update(delta: float) -> void:
	super.update(delta)

	if not _is_dashing:
		return

	_dash_timer -= delta
	if _dash_timer <= 0.0:
		_end_dash()
		return

	if _owner_ref != null:
		_owner_ref.velocity = _dash_velocity

# ---------------------------------------------------------------------------
# Приватные методы
# ---------------------------------------------------------------------------

func _end_dash() -> void:
	_is_dashing = false
	_dash_timer = 0.0

	if _owner_ref == null:
		return

	_owner_ref.velocity = Vector2.ZERO

	var health := _owner_ref.get_node_or_null("HealthComponent") as HealthComponent
	if health != null:
		health.set_invincible(false)

	_owner_ref = null
