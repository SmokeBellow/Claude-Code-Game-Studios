class_name CombatComponent
extends Node

## Боевой компонент игрока: атака ЛКМ, парирование ПКМ, расчёт урона.
## [br]
## [b]Парирование:[/b] ПКМ открывает окно 0.35с. Если враг атаковал в окне →
## контрудар (следующая LMB в 0.5с наносит ×2). Иначе → уязвимость 0.4с.
## [br]
## GDD: [code]design/gdd/combat-system.md[/code]

# ---------------------------------------------------------------------------
# Сигналы
# ---------------------------------------------------------------------------

signal attack_hit(target: Node, damage: float, is_crit: bool)
signal attack_started
signal attack_finished
signal parry_success   ## Парирование сработало — враг попал в окно.
signal parry_failed    ## Парирование не сработало — входим в уязвимость.
signal counter_hit     ## Контрудар нанесён.

# ---------------------------------------------------------------------------
# Экспорт
# ---------------------------------------------------------------------------

@export var player: CharacterBody2D
@export var stats: StatsComponent
@export var health: HealthComponent

# ---------------------------------------------------------------------------
# Tuning knobs
# ---------------------------------------------------------------------------

@export var weapon_base: float = 25.0
@export var attack_cooldown_base: float = 0.4
@export var attack_duration: float = 0.4
@export var hitbox_radius: float = 80.0
@export var hitbox_half_arc_deg: float = 55.0

## Длительность окна парирования (с). Должна быть больше attack_windup врага (0.4с).
@export var parry_window: float = 0.6
## Длительность уязвимости при промахе парирования (с).
@export var vulnerable_duration: float = 0.4
## Cooldown парирования (с).
@export var parry_cooldown_base: float = 1.5
## Окно контрудара после успешного парирования (с).
@export var counter_window: float = 0.5
## Множитель урона контрудара.
@export var counter_multiplier: float = 2.0

# ---------------------------------------------------------------------------
# Состояние
# ---------------------------------------------------------------------------

var _attack_cooldown: float = 0.0
var _attack_timer: float = 0.0
var _is_attacking: bool = false

var _is_parrying: bool = false
var _parry_timer: float = 0.0
var _parry_cooldown: float = 0.0

var _is_vulnerable: bool = false
var _vulnerable_timer: float = 0.0

var _counter_ready: bool = false
var _counter_timer: float = 0.0

# ---------------------------------------------------------------------------
# Публичный доступ (читается BaseEnemy для проверки блока урона)
# ---------------------------------------------------------------------------

## True если игрок сейчас в окне парирования. BaseEnemy проверяет перед нанесением урона.
var is_parrying: bool:
	get: return _is_parrying

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	pass  # Подключение к врагам больше не нужно — BaseEnemy вызывает notify_parry_hit напрямую.

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		if _counter_ready:
			_do_counter_attack()
		else:
			try_attack()
	if event.is_action_pressed("parry"):
		try_parry()

func _process(delta: float) -> void:
	# Атака.
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta
	if _is_attacking:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_end_attack()

	# Парирование.
	if _parry_cooldown > 0.0:
		_parry_cooldown -= delta
	if _is_parrying:
		_parry_timer -= delta
		if _parry_timer <= 0.0:
			_end_parry_miss()

	# Уязвимость.
	if _is_vulnerable:
		_vulnerable_timer -= delta
		if _vulnerable_timer <= 0.0:
			_end_vulnerable()

	# Окно контрудара.
	if _counter_ready:
		_counter_timer -= delta
		if _counter_timer <= 0.0:
			_counter_ready = false
			_set_modulate(Color.WHITE)

# ---------------------------------------------------------------------------
# Публичный API
# ---------------------------------------------------------------------------

func try_attack() -> void:
	if _is_attacking or _attack_cooldown > 0.0:
		return
	if _is_parrying or _is_vulnerable:
		return
	_start_attack()

func try_parry() -> void:
	if _is_parrying or _parry_cooldown > 0.0:
		return
	if _is_attacking or _is_vulnerable:
		return
	_start_parry()

func is_attacking() -> bool:
	return _is_attacking

## Оставлен для совместимости. Подключение к сигналу больше не требуется.
func connect_enemy(_enemy: BaseEnemy) -> void:
	pass

# ---------------------------------------------------------------------------
# Атака
# ---------------------------------------------------------------------------

func _start_attack() -> void:
	_is_attacking = true
	var atk_spd: float = stats.attack_speed() if stats != null else 1.0
	_attack_cooldown = attack_cooldown_base / atk_spd
	_attack_timer = attack_duration
	if player != null:
		player.set_movement_locked(true)
	attack_started.emit()
	_apply_hitbox(false)

func _do_counter_attack() -> void:
	if _is_attacking or _attack_cooldown > 0.0:
		return
	_counter_ready = false
	_counter_timer = 0.0
	_is_attacking = true
	var atk_spd: float = stats.attack_speed() if stats != null else 1.0
	_attack_cooldown = attack_cooldown_base / atk_spd
	_attack_timer = attack_duration
	if player != null:
		player.set_movement_locked(true)
	attack_started.emit()
	_apply_hitbox(true)  # is_counter = true → ×2 урон

func _apply_hitbox(is_counter: bool) -> void:
	if player == null:
		return
	var facing: Vector2 = player.facing_direction
	var origin: Vector2 = player.global_position
	var half_arc: float = deg_to_rad(hitbox_half_arc_deg)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D:
			continue
		var to_enemy: Vector2 = enemy.global_position - origin
		if to_enemy.length() > hitbox_radius:
			continue
		var angle: float = facing.angle_to(to_enemy.normalized())
		if absf(angle) > half_arc:
			continue
		_deal_damage_to(enemy, is_counter)

func _deal_damage_to(target: Node, is_counter: bool) -> void:
	var target_health: HealthComponent = _find_health_component(target)
	if target_health == null or target_health.is_dead:
		return

	var target_stats: StatsComponent = _find_stats_component(target)
	if target_stats != null:
		if randf() < target_stats.dodge_chance() / 100.0:
			return

	var phys_bonus: float = stats.phys_damage_bonus() if stats != null else 0.0
	var base_damage: float = weapon_base + phys_bonus

	var is_crit: bool = false
	if stats != null:
		if randf() < stats.crit_chance() / 100.0:
			is_crit = true
			base_damage *= stats.crit_multiplier()

	if is_counter:
		base_damage *= counter_multiplier
		counter_hit.emit()

	target_health.take_damage(base_damage)
	attack_hit.emit(target, base_damage, is_crit)

func _end_attack() -> void:
	_is_attacking = false
	if player != null:
		player.set_movement_locked(false)
	attack_finished.emit()

# ---------------------------------------------------------------------------
# Парирование
# ---------------------------------------------------------------------------

func _start_parry() -> void:
	_is_parrying = true
	_parry_timer = parry_window
	print("PARRY START: window=", parry_window)
	_parry_cooldown = parry_cooldown_base
	if player != null:
		player.set_movement_locked(true)
	_set_modulate(Color(0.4, 0.6, 1.0))  # Синий — окно парирования

func _end_parry_miss() -> void:
	# Никто не атаковал в окне — уязвимость.
	print("PARRY MISS called! _parry_timer=", _parry_timer, " _is_parrying=", _is_parrying)
	_is_parrying = false
	if player != null:
		player.set_movement_locked(false)
	_set_modulate(Color.WHITE)
	parry_failed.emit()
	_start_vulnerable()

func _start_vulnerable() -> void:
	_is_vulnerable = true
	_vulnerable_timer = vulnerable_duration
	_set_modulate(Color(1.0, 0.3, 0.3))  # Красный — уязвимость

func _end_vulnerable() -> void:
	_is_vulnerable = false
	_set_modulate(Color.WHITE)

# ---------------------------------------------------------------------------
# Публичный вызов от врага при нанесении удара
# ---------------------------------------------------------------------------

## Вызывается BaseEnemy в момент удара. Возвращает true если парирование сработало.
func notify_parry_hit() -> bool:
	if not _is_parrying:
		return false
	# Успешное парирование!
	_is_parrying = false
	_parry_timer = 0.0
	if player != null:
		player.set_movement_locked(false)
	_set_modulate(Color(1.0, 0.85, 0.0))  # Золотой — контрудар готов
	parry_success.emit()
	_counter_ready = true
	_counter_timer = counter_window
	return true

# ---------------------------------------------------------------------------
# Вспомогательные
# ---------------------------------------------------------------------------

func _subscribe_to_enemies() -> void:
	pass  # Не используется.

func _set_modulate(color: Color) -> void:
	if player != null:
		player.modulate = color

func _find_health_component(node: Node) -> HealthComponent:
	for child in node.get_children():
		if child is HealthComponent:
			return child
	return null

func _find_stats_component(node: Node) -> StatsComponent:
	for child in node.get_children():
		if child is StatsComponent:
			return child
	return null
