class_name BaseEnemy
extends CharacterBody2D

## Базовый класс врага. Конечный автомат: PATROL → CHASE → ATTACK_WINDUP → ATTACK → ATTACK_COOLDOWN → DEAD.
## [br]
## Настраивается через [EnemyData] ресурс. Добавь в группу [code]"enemies"[/code].
## [br]
## [b]Требует в сцене:[/b] NavigationAgent2D, HealthComponent, Area2D (DetectionArea).
## [br]
## GDD: [code]design/gdd/enemy-ai.md[/code]

# ---------------------------------------------------------------------------
# Сигналы
# ---------------------------------------------------------------------------

## Испускается при смерти. LevelXPSystem и LootSystem слушают.
signal enemy_died(xp_reward: int, enemy_data: EnemyData)

# ---------------------------------------------------------------------------
# Состояния
# ---------------------------------------------------------------------------

enum State { PATROL, CHASE, ATTACK_WINDUP, ATTACK, ATTACK_COOLDOWN, DEAD }

# ---------------------------------------------------------------------------
# Экспорт
# ---------------------------------------------------------------------------

## Конфигурационный ресурс. Создай .tres в assets/data/enemies/ и подключи сюда.
@export var data: EnemyData

## HealthComponent врага.
@export var health: HealthComponent

# ---------------------------------------------------------------------------
# Внутреннее состояние
# ---------------------------------------------------------------------------

var _state: State = State.PATROL
var _target: Node2D = null          # ссылка на Player
var _state_timer: float = 0.0       # таймер текущего состояния
var _nav_timer: float = 0.0         # throttle NavigationAgent2D (0.1с)
var _patrol_wait: float = 0.0       # ожидание в патруле
var _patrol_target: Vector2         # текущая патрульная точка
var _start_position: Vector2        # стартовая позиция для патруля
var _facing: Vector2 = Vector2.RIGHT

# Статус-эффекты
var _stun_timer: float    = 0.0   # Оглушение: нет движения и атак
var _slow_timer: float    = 0.0   # Замедление
var _slow_mult: float     = 1.0   # Множитель скорости при замедлении
var _miss_timer: float    = 0.0   # Туман: шанс промахнуться атакой
var _miss_chance: float   = 0.0   # 0.0–1.0

@onready var _nav: NavigationAgent2D = $NavigationAgent2D

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	assert(data != null, "BaseEnemy: поле 'data' (EnemyData) не заполнено на %s" % name)
	assert(health != null, "BaseEnemy: поле 'health' (HealthComponent) не заполнено на %s" % name)

	add_to_group("enemies")
	_start_position = global_position
	_patrol_target = global_position

	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)

	# Настройка NavigationAgent2D.
	_nav.path_desired_distance = 4.0
	_nav.target_desired_distance = 4.0

	_find_player()
	_enter_patrol()


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return

	_state_timer -= delta
	_nav_timer -= delta

	# Тики статус-эффектов
	if _stun_timer > 0.0:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			_refresh_status_modulate()
		velocity = Vector2.ZERO
		move_and_slide()
		return  # Оглушён — пропускаем всю логику
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_mult = 1.0
			_refresh_status_modulate()
	if _miss_timer > 0.0:
		_miss_timer -= delta
		if _miss_timer <= 0.0:
			_miss_chance = 0.0
			_refresh_status_modulate()

	match _state:
		State.PATROL:        _tick_patrol(delta)
		State.CHASE:         _tick_chase(delta)
		State.ATTACK_WINDUP: _tick_windup(delta)
		State.ATTACK:        _tick_attack()
		State.ATTACK_COOLDOWN: _tick_cooldown()

# ---------------------------------------------------------------------------
# Тики состояний
# ---------------------------------------------------------------------------

func _tick_patrol(delta: float) -> void:
	_check_aggro()

	if _patrol_wait > 0.0:
		_patrol_wait -= delta
		return

	# Движение к патрульной точке.
	if _nav_timer <= 0.0:
		_nav.set_target_position(_patrol_target)
		_nav_timer = 0.1

	if _nav.is_navigation_finished():
		_patrol_wait = randf_range(0.3, 1.2)
		_pick_patrol_point()
		return

	_move_toward_nav(delta, data.move_speed * 0.7 * _slow_mult)


func _tick_chase(delta: float) -> void:
	if _target == null:
		_enter_patrol()
		return

	var dist: float = global_position.distance_to(_target.global_position)

	# Де-агро: игрок ушёл слишком далеко — возвращаемся на патруль.
	if dist > data.aggro_range * 2.0:
		_enter_patrol()
		return

	# В зоне атаки и cooldown истёк — начинаем windup.
	if dist <= data.attack_range and _state_timer <= 0.0:
		_enter_windup()
		return

	# Обновляем путь через NavigationAgent2D каждые 0.1с.
	if _nav_timer <= 0.0:
		_nav.set_target_position(_target.global_position)
		_nav_timer = 0.1

	_move_toward_nav(delta, data.move_speed * _slow_mult)
	if _target != null:
		_facing = (_target.global_position - global_position).normalized()


func _tick_windup(_delta: float) -> void:
	# Стоим на месте, ждём завершения телеграфа.
	velocity = Vector2.ZERO
	move_and_slide()

	if _state_timer <= 0.0:
		_enter_attack()


func _tick_attack() -> void:
	# Наносим урон — применяется мгновенно (1 кадр).
	if _target != null:
		# Проверяем шанс промаха (статус-эффект тумана).
		if _miss_chance > 0.0 and randf() < _miss_chance:
			_enter_cooldown()
			return
		# Проверяем парирование: если сработало — урон не проходит.
		var combat: CombatComponent = _target.get_node_or_null("CombatComponent") as CombatComponent
		if combat != null and combat.notify_parry_hit():
			_enter_cooldown()
			return
		if _target.has_node("HealthComponent"):
			var target_hp: HealthComponent = _target.get_node("HealthComponent") as HealthComponent
			if target_hp != null and not target_hp.is_dead:
				target_hp.take_damage(data.attack_damage)
	_enter_cooldown()


func _tick_cooldown() -> void:
	# Ждём окончания cooldown, потом возвращаемся в CHASE.
	if _state_timer <= 0.0:
		if _target != null:
			_change_state(State.CHASE)
		else:
			_enter_patrol()

# ---------------------------------------------------------------------------
# Публичный API статус-эффектов
# ---------------------------------------------------------------------------

## Оглушить врага на [param duration] секунд (не суммируется, берём максимум).
func apply_stun(duration: float) -> void:
	_stun_timer = maxf(_stun_timer, duration)
	modulate = Color(1.0, 0.9, 0.3)   # Жёлтый — оглушение


## Замедлить врага на [param duration] секунд. [param mult] — множитель скорости (0.0–1.0).
func apply_slow(duration: float, mult: float = 0.4) -> void:
	_slow_timer = maxf(_slow_timer, duration)
	_slow_mult  = minf(_slow_mult,  mult)
	if _stun_timer <= 0.0:
		modulate = Color(0.5, 0.75, 1.0)  # Голубой — замедление


## Наложить «туман» — шанс промахнуться атакой. [param chance] — 0.0–1.0.
func apply_miss_chance(duration: float, chance: float = 0.5) -> void:
	_miss_timer  = maxf(_miss_timer,  duration)
	_miss_chance = maxf(_miss_chance, chance)
	if _stun_timer <= 0.0 and _slow_timer <= 0.0:
		modulate = Color(0.6, 0.8, 0.6)   # Зелёный — туман / снижение точности

# ---------------------------------------------------------------------------
# Переходы состояний
# ---------------------------------------------------------------------------

func _enter_patrol() -> void:
	_change_state(State.PATROL)
	_patrol_wait = 0.0
	_pick_patrol_point()


func _enter_windup() -> void:
	_change_state(State.ATTACK_WINDUP)
	_state_timer = data.attack_windup
	modulate = Color(1.0, 0.4, 0.0)  # Оранжевый — телеграф атаки


func _enter_attack() -> void:
	_change_state(State.ATTACK)


func _enter_cooldown() -> void:
	_change_state(State.ATTACK_COOLDOWN)
	_state_timer = data.attack_cooldown
	_refresh_status_modulate()  # Сброс цвета телеграфа, восстанавливаем цвет статуса


func _change_state(new_state: State) -> void:
	_state = new_state

# ---------------------------------------------------------------------------
# Aggro
# ---------------------------------------------------------------------------

func _check_aggro() -> void:
	if _target == null:
		return

	var to_player: Vector2 = _target.global_position - global_position
	var dist: float = to_player.length()

	if dist > data.aggro_range:
		return

	# Проверка конуса зрения.
	var angle: float = absf(_facing.angle_to(to_player.normalized()))
	var half_arc: float = deg_to_rad(data.aggro_angle * 0.5)
	if angle <= half_arc:
		_aggro()


func _aggro() -> void:
	if _state == State.PATROL:
		_change_state(State.CHASE)

# ---------------------------------------------------------------------------
# Вспомогательные
# ---------------------------------------------------------------------------

## Обновляет цвет спрайта в соответствии с активными статус-эффектами.
## Вызывается при истечении любого из таймеров.
func _refresh_status_modulate() -> void:
	if _stun_timer > 0.0:
		modulate = Color(1.0, 0.9, 0.3)
	elif _slow_timer > 0.0:
		modulate = Color(0.5, 0.75, 1.0)
	elif _miss_timer > 0.0:
		modulate = Color(0.6, 0.8, 0.6)
	else:
		modulate = Color.WHITE


func _move_toward_nav(delta: float, speed: float) -> void:
	if _nav.is_navigation_finished():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var next_pos: Vector2 = _nav.get_next_path_position()
	var dir: Vector2 = (next_pos - global_position).normalized()
	velocity = velocity.lerp(dir * speed, 10.0 * delta)
	move_and_slide()


func _pick_patrol_point() -> void:
	var angle: float = randf() * TAU
	var radius: float = randf() * data.patrol_radius
	_patrol_target = _start_position + Vector2(cos(angle), sin(angle)) * radius


func _find_player() -> void:
	# Ищем игрока по группе.
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_target = players[0] as Node2D

# ---------------------------------------------------------------------------
# Обработчики сигналов
# ---------------------------------------------------------------------------

func _on_damaged(_amount: float) -> void:
	# On-hit aggro: враг реагирует на удар независимо от направления взгляда.
	if _state == State.PATROL:
		_aggro()


func _on_died() -> void:
	_change_state(State.DEAD)
	velocity = Vector2.ZERO

	# Отключаем коллизии.
	set_physics_process(false)
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", true)

	enemy_died.emit(data.xp_reward, data)

	# Удаляем из дерева через 0.5с (время fade-out анимации).
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(self):
		queue_free()
