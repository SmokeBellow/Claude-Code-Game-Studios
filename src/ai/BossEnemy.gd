class_name BossEnemy
extends BaseEnemy

## Босс данжа. Расширяет BaseEnemy зарядной атакой и фазой ярости.
## [br]
## Фаза 1: стандартный бой + рывок каждые 6с (телеграф 0.8с → рывок 0.4с).
## Фаза 2 (ярость, ≤50% HP): скорость ×1.5, урон ×1.5, рывок чаще.
## [br]
## GDD: [code]design/gdd/boss-enemy.md[/code]

# ---------------------------------------------------------------------------
# Фазы зарядной атаки (отдельно от родительского State)
# ---------------------------------------------------------------------------

enum BossPhase { CHARGE_WINDUP, CHARGE_RUSH }

# ---------------------------------------------------------------------------
# Настройка зарядной атаки
# ---------------------------------------------------------------------------

## Задержка между рывками (с), фаза 1.
@export var charge_cooldown: float = 6.0
## Задержка между рывками в ярости (с), фаза 2.
@export var charge_cooldown_enraged: float = 3.5
## Длительность телеграфа рывка (с).
@export var charge_windup_time: float = 0.8
## Длительность самого рывка (с).
@export var charge_rush_time: float = 0.4
## Скорость рывка (px/s).
@export var charge_speed: float = 380.0
## Урон рывком при контакте с игроком.
@export var charge_damage: float = 30.0
## Дистанция контакта рывка (px).
@export var charge_hit_range: float = 55.0
## Порог HP для ярости (доля 0..1).
@export var enrage_threshold: float = 0.5

# ---------------------------------------------------------------------------
# Внутреннее состояние босса
# ---------------------------------------------------------------------------

var _in_charge: bool = false
var _charge_phase: BossPhase = BossPhase.CHARGE_WINDUP
var _charge_timer: float = 0.0
var _charge_cd: float = 3.0          # первый рывок через 3с
var _charge_dir: Vector2 = Vector2.RIGHT
var _is_enraged: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Дублируем ресурс данных — иначе изменения при ярости затронут всех врагов.
	if data != null:
		data = data.duplicate()
	super._ready()
	scale = Vector2(1.3, 1.3)
	modulate = Color(1.0, 0.55, 0.55)   # Красноватый оттенок


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return

	# Проверяем переход в ярость.
	if not _is_enraged:
		var hp_frac: float = health.current_hp / health._get_max_hp()
		if hp_frac <= enrage_threshold:
			_enrage()

	# --- Зарядная атака ---
	if _in_charge:
		# Продолжаем тикать родительские таймеры, чтобы не ломать cooldown атак.
		_state_timer -= delta
		_nav_timer -= delta
		_charge_timer -= delta
		match _charge_phase:
			BossPhase.CHARGE_WINDUP: _tick_charge_windup()
			BossPhase.CHARGE_RUSH:   _tick_charge_rush(delta)
		return

	# Обновляем cooldown рывка только во время преследования.
	if _state == State.CHASE:
		_charge_cd -= delta
		if _charge_cd <= 0.0:
			_begin_charge_windup()
			return

	# Обычное поведение родителя.
	super._physics_process(delta)


# ---------------------------------------------------------------------------
# Тики зарядной атаки
# ---------------------------------------------------------------------------

func _tick_charge_windup() -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	if _charge_timer <= 0.0:
		_begin_charge_rush()


func _tick_charge_rush(delta: float) -> void:
	velocity = _charge_dir * charge_speed * (1.3 if _is_enraged else 1.0)
	move_and_slide()

	# Попадание по игроку во время рывка.
	if _target != null:
		var dist: float = global_position.distance_to(_target.global_position)
		if dist <= charge_hit_range:
			_apply_charge_hit()
			_end_charge()
			return

	if _charge_timer <= 0.0:
		_end_charge()


# ---------------------------------------------------------------------------
# Переходы зарядной атаки
# ---------------------------------------------------------------------------

func _begin_charge_windup() -> void:
	_in_charge = true
	_charge_phase = BossPhase.CHARGE_WINDUP
	_charge_timer = charge_windup_time
	# Запоминаем направление к игроку в момент начала.
	if _target != null:
		_charge_dir = (_target.global_position - global_position).normalized()
	modulate = Color(1.0, 0.0, 0.0)    # Красный — телеграф рывка


func _begin_charge_rush() -> void:
	_charge_phase = BossPhase.CHARGE_RUSH
	_charge_timer = charge_rush_time
	modulate = Color(1.8, 0.15, 0.15)  # Ярко-красный во время рывка


func _end_charge() -> void:
	_in_charge = false
	_charge_cd = charge_cooldown_enraged if _is_enraged else charge_cooldown
	modulate = Color(1.8, 0.1, 0.1) if _is_enraged else Color(1.0, 0.55, 0.55)
	_change_state(State.CHASE)


func _apply_charge_hit() -> void:
	if _target == null:
		return
	var combat: CombatComponent = _target.get_node_or_null("CombatComponent") as CombatComponent
	if combat != null and combat.notify_parry_hit():
		return  # парировано
	var target_hp: HealthComponent = _target.get_node_or_null("HealthComponent") as HealthComponent
	if target_hp != null and not target_hp.is_dead:
		target_hp.take_damage(charge_damage * (1.5 if _is_enraged else 1.0))


# ---------------------------------------------------------------------------
# Ярость (фаза 2)
# ---------------------------------------------------------------------------

func _enrage() -> void:
	_is_enraged = true
	data.move_speed *= 1.5
	data.attack_damage *= 1.5
	charge_speed *= 1.3
	modulate = Color(1.8, 0.1, 0.1)

	# Визуальный рывок масштаба.
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.15)
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.15)
