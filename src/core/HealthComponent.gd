class_name HealthComponent
extends Node

## Управляет текущим HP и маной сущности: получение урона, лечение, реген, смерть.
## [br]
## Требует наличия [StatsComponent] в поле [member stats] для чтения максимальных значений.
## [br]
## [b]Реген HP:[/b] приостанавливается на 3с после получения урона.
## [b]Реген маны:[/b] работает всегда (кроме состояния «Мёртв»).
## [br]
## GDD: [code]design/gdd/health-stats.md[/code]

# ---------------------------------------------------------------------------
# Сигналы
# ---------------------------------------------------------------------------

## Испускается при изменении HP.
signal health_changed(current_hp: float, max_hp: float)
## Испускается при изменении маны.
signal mana_changed(current_mana: float, max_mana: float)
## Испускается при HP = 0. Подключи к [method Player.on_died].
signal died
## Испускается при каждом получении урона.
signal damaged(amount: float)
## Испускается при каждом лечении.
signal healed(amount: float)

# ---------------------------------------------------------------------------
# Экспортируемые параметры
# ---------------------------------------------------------------------------

## StatsComponent этой сущности. Обязательно заполнить в инспекторе.
@export var stats: StatsComponent

## Задержка регена HP после получения урона (секунд).
@export var regen_cooldown_duration: float = 3.0

## Множитель регена HP между комнатами (tuning knob).
@export var between_rooms_regen_mult: float = 5.0

# ---------------------------------------------------------------------------
# Состояние
# ---------------------------------------------------------------------------

## Текущий HP. Читается HUD и Боевой системой.
var current_hp: float = 0.0

## Текущая мана. Читается Системой способностей и HUD.
var current_mana: float = 0.0

## Истина если сущность мертва. После смерти все операции с HP игнорируются.
var is_dead: bool = false
var is_invincible: bool = false

var _regen_cooldown: float = 0.0
var _between_rooms_mode: bool = false

## Активные временные HP: массив [amount, timer].
var _temp_hp_entries: Array = []

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

## Максимальный HP для сущностей без StatsComponent (враги, объекты).
## Игнорируется если [member stats] заполнен.
@export var max_hp_override: float = 0.0

func _ready() -> void:
	if stats != null:
		current_hp = stats.max_hp()
		current_mana = stats.max_mana()
		stats.stats_changed.connect(_on_stats_changed)
	elif max_hp_override > 0.0:
		current_hp = max_hp_override
	else:
		push_warning("HealthComponent на '%s': ни stats, ни max_hp_override не заполнены." % get_parent().name)

func _process(delta: float) -> void:
	if is_dead:
		return
	_tick_temp_hp(delta)
	if _regen_cooldown > 0.0:
		_regen_cooldown -= delta
		return
	_apply_regen(delta)

# ---------------------------------------------------------------------------
# Публичный API: боевые операции
# ---------------------------------------------------------------------------

## Наносит урон. HP не уходит в минус. Испускает [signal died] при HP=0.
## [br]Вызывается Боевой системой (#9).
## Включает или выключает неуязвимость (используется Dash и парированием).
func set_invincible(value: bool) -> void:
	is_invincible = value

func take_damage(amount: float) -> void:
	if is_dead or is_invincible:
		return
	_regen_cooldown = regen_cooldown_duration
	current_hp = maxf(0.0, current_hp - amount)
	health_changed.emit(current_hp, _get_max_hp())
	damaged.emit(amount)
	if current_hp <= 0.0:
		_die()

## Лечит сущность. HP не превышает максимум.
## [br]Вызывается Боевой системой (#9) и системой предметов.
func heal(amount: float) -> void:
	if is_dead:
		return
	current_hp = minf(_get_max_hp(), current_hp + amount)
	health_changed.emit(current_hp, _get_max_hp())
	healed.emit(amount)

## Добавляет временные HP на [param duration] секунд.
## По истечении бонус снимается (HP зажимается до актуального максимума).
func add_temp_hp(amount: float, duration: float) -> void:
	if is_dead:
		return
	_temp_hp_entries.append([amount, duration])
	current_hp = minf(current_hp + amount, _get_max_hp() + amount)
	health_changed.emit(current_hp, _get_max_hp())


## Тратит ману. Возвращает [code]false[/code] и не тратит ману если её не хватает.
## [br]Вызывается Системой способностей (#10).
func spend_mana(amount: float) -> bool:
	if current_mana < amount:
		return false
	current_mana -= amount
	mana_changed.emit(current_mana, stats.max_mana() if stats != null else 0.0)
	return true

# ---------------------------------------------------------------------------
# Публичный API: режим регена между комнатами
# ---------------------------------------------------------------------------

## Включает ускоренный реген HP между комнатами (×[member between_rooms_regen_mult]).
func set_between_rooms_mode(active: bool) -> void:
	_between_rooms_mode = active
	_regen_cooldown = 0.0  # сбросить задержку при входе в комнату

# ---------------------------------------------------------------------------
# Приватные методы
# ---------------------------------------------------------------------------

func _tick_temp_hp(delta: float) -> void:
	if _temp_hp_entries.is_empty():
		return
	var expired: Array = []
	for entry in _temp_hp_entries:
		entry[1] -= delta
		if entry[1] <= 0.0:
			expired.append(entry)
	for entry in expired:
		_temp_hp_entries.erase(entry)
		# Снимаем бонусные HP, но не убиваем игрока (минимум 1).
		current_hp = maxf(1.0, current_hp - entry[0])
		health_changed.emit(current_hp, _get_max_hp())


func _apply_regen(delta: float) -> void:
	if stats == null:
		return  # враги без StatsComponent не регенерируют

	var regen_mult: float = between_rooms_regen_mult if _between_rooms_mode else 1.0
	var max_hp: float = _get_max_hp()

	var hp_changed: bool = false
	var mp_changed: bool = false

	if current_hp < max_hp:
		current_hp = minf(max_hp, current_hp + stats.hp_regen_per_sec() * regen_mult * delta)
		hp_changed = true

	if current_mana < stats.max_mana():
		current_mana = minf(stats.max_mana(), current_mana + stats.mana_regen_per_sec() * delta)
		mp_changed = true

	if hp_changed:
		health_changed.emit(current_hp, max_hp)
	if mp_changed:
		mana_changed.emit(current_mana, stats.max_mana())

func _get_max_hp() -> float:
	if stats != null:
		return stats.max_hp()
	return max_hp_override if max_hp_override > 0.0 else current_hp


## Возрождает сущность с полным HP. Вызывается Player.on_died() после задержки.
func respawn() -> void:
	is_dead = false
	_regen_cooldown = 0.0
	current_hp = _get_max_hp()
	health_changed.emit(current_hp, _get_max_hp())


func _die() -> void:
	is_dead = true
	died.emit()

func _on_stats_changed() -> void:
	# При изменении статов зажимаем HP/ману до новых максимумов (напр. снятие экипировки).
	var new_max_hp: float = stats.max_hp()
	var new_max_mana: float = stats.max_mana()

	if current_hp > new_max_hp:
		current_hp = new_max_hp
		health_changed.emit(current_hp, new_max_hp)

	if current_mana > new_max_mana:
		current_mana = new_max_mana
		mana_changed.emit(current_mana, new_max_mana)
