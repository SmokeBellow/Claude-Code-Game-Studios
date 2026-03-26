class_name Player
extends CharacterBody2D

## Контроллер движения игрока.
## Отвечает за 8-направленное перемещение, sprint, ориентацию к курсору и блокировку движения.
## [br]
## [b]Интеграция:[/b]
## - [StatsComponent] предоставляет [code]move_speed[/code] через DEX.
## - [HealthComponent] испускает [signal HealthComponent.died] → [method on_died].
## - Боевая система (#9) вызывает [method set_movement_locked] во время атаки.

# ---------------------------------------------------------------------------
# Ссылки на компоненты (заполнить в инспекторе)
# ---------------------------------------------------------------------------

## StatsComponent игрока. Если не заполнен — используется move_speed_fallback.
@export var stats: StatsComponent
## HealthComponent игрока. Подключить died → on_died() в редакторе или в _ready().
@export var health: HealthComponent

# ---------------------------------------------------------------------------
# Tuning knobs (используются только если stats == null)
# ---------------------------------------------------------------------------

## Резервная скорость для тестирования без StatsComponent.
@export var move_speed_fallback: float = 180.0
## Коэффициент сглаживания инерции (1/с).
@export var acceleration: float = 15.0
## Множитель скорости при sprint (Shift).
@export var sprint_multiplier: float = 1.5

# ---------------------------------------------------------------------------
# Константы
# ---------------------------------------------------------------------------

const MAX_DELTA: float = 0.1
const MIN_FACING_DISTANCE_SQ: float = 1.0

# ---------------------------------------------------------------------------
# Публичное состояние
# ---------------------------------------------------------------------------

## Нормализованное направление к курсору. Читается Боевой системой (#9).
var facing_direction: Vector2 = Vector2.RIGHT

## Флаг блокировки движения. Устанавливается Боевой системой (#9).
var is_movement_locked: bool = false

# ---------------------------------------------------------------------------
# Внутреннее состояние
# ---------------------------------------------------------------------------

var _target_velocity: Vector2 = Vector2.ZERO

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	if health != null:
		health.died.connect(on_died)

func _physics_process(delta: float) -> void:
	var safe_delta: float = minf(delta, MAX_DELTA)
	_update_facing()

	if is_movement_locked:
		velocity = Vector2.ZERO
	else:
		_update_movement(safe_delta)

	move_and_slide()

# ---------------------------------------------------------------------------
# Публичный API
# ---------------------------------------------------------------------------

## Блокирует или разблокирует движение. Вызывается Боевой системой (#9).
func set_movement_locked(value: bool) -> void:
	is_movement_locked = value
	if value:
		velocity = Vector2.ZERO

## Вызывается при смерти (подключить к HealthComponent.died).
func on_died() -> void:
	is_movement_locked = true
	velocity = Vector2.ZERO

# ---------------------------------------------------------------------------
# Приватные методы
# ---------------------------------------------------------------------------

func _update_movement(delta: float) -> void:
	var input_dir := Vector2(
		float(Input.is_action_pressed("move_right")) - float(Input.is_action_pressed("move_left")),
		float(Input.is_action_pressed("move_down"))  - float(Input.is_action_pressed("move_up"))
	)

	var speed: float = stats.move_speed() if stats != null else move_speed_fallback
	if Input.is_action_pressed("sprint") and input_dir != Vector2.ZERO:
		speed *= sprint_multiplier

	_target_velocity = input_dir.normalized() * speed
	velocity = velocity.lerp(_target_velocity, acceleration * delta)

func _update_facing() -> void:
	var mouse_offset: Vector2 = get_global_mouse_position() - global_position
	if mouse_offset.length_squared() > MIN_FACING_DISTANCE_SQ:
		facing_direction = mouse_offset.normalized()
