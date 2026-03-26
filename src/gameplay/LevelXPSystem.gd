class_name LevelXPSystem
extends Node

## Система уровней и XP. Отслеживает опыт героя и управляет повышением уровня.
## [br]
## Подключи к сигналу [signal BaseEnemy.enemy_died] каждого врага через код или редактор.
## Подключи к сигналу [signal HealthComponent.died] игрока для штрафа смерти.
## [br]
## GDD: [code]design/gdd/level-xp-system.md[/code]

# ---------------------------------------------------------------------------
# Сигналы
# ---------------------------------------------------------------------------

## Испускается при повышении уровня. Health & Stats слушает для начисления очков.
signal level_up(current_level: int, attribute_points: int)

## Испускается при каждом получении XP. HUD показывает флоатинг-текст.
signal xp_gained(amount: int, source: String)

## Испускается после любого изменения XP. HUD обновляет XP-бар.
signal xp_updated(current_xp: int, xp_to_next: int)

# ---------------------------------------------------------------------------
# Константы (tuning knobs из GDD)
# ---------------------------------------------------------------------------

const XP_BASE: int = 50        ## Базовое требование XP на уровне 1.
const XP_INCREMENT: int = 10   ## Прирост требования за каждый уровень.
const MAX_LEVEL: int = 30      ## Хард кап уровня.
const ATTRIBUTE_POINTS_PER_LEVEL: int = 5

# ---------------------------------------------------------------------------
# Состояние
# ---------------------------------------------------------------------------

## Текущий уровень героя. Начинается с 1.
var current_level: int = 1

## Текущий накопленный XP.
var current_xp: int = 0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Подписываемся на enemy_died всех врагов в сцене через группу.
	# Новые враги подключаются при спавне через connect_enemy().
	pass

# ---------------------------------------------------------------------------
# Публичный API
# ---------------------------------------------------------------------------

## Добавляет XP. Вызывается автоматически через connect_enemy() или напрямую (квесты).
func add_xp(amount: int, source: String = "enemy") -> void:
	if current_level >= MAX_LEVEL:
		return
	if amount <= 0:
		return

	current_xp += amount
	xp_gained.emit(amount, source)
	_check_level_up()
	xp_updated.emit(current_xp, xp_to_next_level(current_level))


## Подключает сигнал enemy_died врага к этой системе.
## Вызывай при спавне каждого врага.
func connect_enemy(enemy: BaseEnemy) -> void:
	if not enemy.enemy_died.is_connected(_on_enemy_died):
		enemy.enemy_died.connect(_on_enemy_died)


## Подключает сигнал died игрока для штрафа смерти.
func connect_player_health(health: HealthComponent) -> void:
	if not health.died.is_connected(_on_player_died):
		health.died.connect(_on_player_died)


## XP, необходимый для перехода с уровня [param n] на n+1.
## Формула: [code]50 + 10 * n[/code]
func xp_to_next_level(n: int) -> int:
	return XP_BASE + XP_INCREMENT * n


## Накопленный XP для достижения уровня [param level] от старта.
## Формула: [code](L-1) * (50 + 5*L)[/code]
func cumulative_xp(level: int) -> int:
	return (level - 1) * (XP_BASE + 5 * level)


## Нижняя граница XP для текущего уровня (используется при штрафе смерти).
func xp_floor(level: int) -> int:
	return cumulative_xp(level)

# ---------------------------------------------------------------------------
# Приватные методы
# ---------------------------------------------------------------------------

func _check_level_up() -> void:
	# Обрабатываем несколько level_up подряд (переполнение XP).
	while current_level < MAX_LEVEL and current_xp >= xp_to_next_level(current_level):
		current_level += 1
		level_up.emit(current_level, ATTRIBUTE_POINTS_PER_LEVEL)

	# Зажимаем XP на уровне MAX_LEVEL.
	if current_level >= MAX_LEVEL:
		current_xp = xp_floor(MAX_LEVEL)

# ---------------------------------------------------------------------------
# Обработчики сигналов
# ---------------------------------------------------------------------------

func _on_enemy_died(xp_reward: int, _enemy_data: EnemyData) -> void:
	add_xp(xp_reward, "enemy")


func _on_player_died() -> void:
	# Штраф смерти: сбросить XP до нижней границы текущего уровня.
	current_xp = xp_floor(current_level)
	xp_updated.emit(current_xp, xp_to_next_level(current_level))
	print("Death penalty: XP сброшен до ", current_xp, " (floor уровня ", current_level, ")")
