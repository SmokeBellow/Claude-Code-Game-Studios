class_name RangedEnemy
extends BaseEnemy

## Дальний враг. Стреляет снарядами с дистанции, отступает если игрок подходит вплотную.
## [br]
## Дистанция атаки задаётся через [EnemyData.attack_range] (рекомендуется 180–220px).
## При расстоянии меньше [member retreat_range] — отходит назад.

const _ProjScene = preload("res://scenes/projectile.tscn")

## Дистанция (px) ниже которой враг начинает отступать.
@export var retreat_range: float = 90.0
## Скорость снаряда (px/с).
@export var projectile_speed: float = 230.0

# ---------------------------------------------------------------------------
# Переопределение: преследование с отступлением
# ---------------------------------------------------------------------------

func _tick_chase(delta: float) -> void:
	if _target == null:
		_enter_patrol()
		return

	var dist: float = global_position.distance_to(_target.global_position)

	if dist > data.aggro_range * 2.0:
		_enter_patrol()
		return

	# Атака если дистанция подходящая и cooldown истёк.
	if dist <= data.attack_range and _state_timer <= 0.0:
		_enter_windup()
		return

	# Отступаем если игрок слишком близко.
	if dist < retreat_range:
		var away: Vector2 = (global_position - _target.global_position).normalized()
		velocity = velocity.lerp(away * data.move_speed, 10.0 * delta)
		move_and_slide()
		_facing = -away
		return

	# Сближаемся если слишком далеко.
	if _nav_timer <= 0.0:
		_nav.set_target_position(_target.global_position)
		_nav_timer = 0.1
	_move_toward_nav(delta, data.move_speed)
	if _target != null:
		_facing = (_target.global_position - global_position).normalized()


# ---------------------------------------------------------------------------
# Переопределение: атака снарядом вместо ближнего удара
# ---------------------------------------------------------------------------

func _tick_attack() -> void:
	if _target != null:
		_fire_projectile()
	_enter_cooldown()


func _fire_projectile() -> void:
	var proj: Node = _ProjScene.instantiate()
	# Добавляем в Main чтобы снаряд пережил смену комнаты.
	var main := get_tree().get_first_node_in_group("main")
	if main != null:
		main.add_child(proj)
	else:
		get_tree().root.add_child(proj)
	proj.global_position = global_position
	var dir: Vector2 = (_target.global_position - global_position).normalized()
	proj.init(dir, projectile_speed, data.attack_damage)
