class_name GameCamera
extends Camera2D

## Камера с плавным следованием за целью через lerp.
## [br]
## Присоедини к узлу Camera2D в сцене и заполни поле [member target].
## [br]
## GDD: Sprint 1, S1-04

# ---------------------------------------------------------------------------
# Экспортируемые параметры
# ---------------------------------------------------------------------------

## Узел за которым следит камера (обычно Player).
@export var target: Node2D

## Коэффициент сглаживания (1/с). Выше — резче следование.
@export var follow_speed: float = 5.0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	add_to_group("game_camera")
	position_smoothing_enabled = false

func _physics_process(delta: float) -> void:
	if target == null:
		return
	global_position = global_position.lerp(target.global_position, follow_speed * delta)
