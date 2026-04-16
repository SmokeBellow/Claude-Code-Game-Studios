extends Node

## Глобальный синглтон для данных игрока, сохраняемых между сценами.
## Добавь как Autoload в project.godot с именем "PlayerData".

# ---------------------------------------------------------------------------
# Система классов
# ---------------------------------------------------------------------------

const CLASS_NONE: int    = 0
const CLASS_WARRIOR: int = 1
const CLASS_MAGE: int    = 2
const CLASS_ROGUE: int   = 3

## Выбранный класс. Устанавливается на 3-м уровне.
var player_class: int = CLASS_NONE

## Разблокированные классовые умения (слоты 0–2, открываются на ур. 3/6/9).
var ability_unlocked: Array[bool] = [false, false, false]


## Применяет базовые бонусы класса к StatsComponent.
func apply_class_stats(stats: StatsComponent) -> void:
	match player_class:
		CLASS_WARRIOR:
			stats.apply_equipment_bonus(5.0, -2.0, 4.0, 0.0, 0.0, 0.0)
		CLASS_MAGE:
			stats.apply_equipment_bonus(-2.0, 0.0, -3.0, 5.0, 5.0, 0.0)
		CLASS_ROGUE:
			stats.apply_equipment_bonus(0.0, 5.0, -2.0, 0.0, 0.0, 3.0)


## Разблокирует умения согласно уровню.
func unlock_abilities_for_level(level: int) -> void:
	if level >= 3: ability_unlocked[0] = true
	if level >= 6: ability_unlocked[1] = true
	if level >= 9: ability_unlocked[2] = true

# ---------------------------------------------------------------------------
# Валюта
# ---------------------------------------------------------------------------

## Золото игрока.
var gold: int = 0

# ---------------------------------------------------------------------------
# Расходники (4 слота, клавиши 1–4)
# ---------------------------------------------------------------------------

## Зелья здоровья по слотам (индексы 0–3 → клавиши 1–4).
var potion_slots: Array[int] = [0, 0, 0, 0]

## Суммарное количество зелий (для совместимости с ShopScreen).
var potions: int:
	get: return potion_slots[0] + potion_slots[1] + potion_slots[2] + potion_slots[3]

# ---------------------------------------------------------------------------
# Квест от старосты
# ---------------------------------------------------------------------------

## Текущая стадия цепочки квестов.
## 0=не начат 1=убей 5 врагов 2=принеси печать элиты 3=убей босса 4=завершён
## Логика квестов — в QuestSystem (Autoload). Только данные хранятся здесь.
var quest_stage: int = 0

## Убийства в рамках стадии 1.
var quest_kills: int = 0
## Печать Стражника подобрана (стадия 2).
var quest_has_seal: bool = false
## Босс убит (стадия 3).
var quest_boss_killed: bool = false

# ---------------------------------------------------------------------------
# Флаг воскрешения
# ---------------------------------------------------------------------------

## True если игрок погиб в данже и был воскрешён в городе.
var was_resurrected: bool = false
## True если игрок вернулся через портал — спавним у ворот данжа.
var returned_from_dungeon: bool = false

# ---------------------------------------------------------------------------
# Сохранение прогрессии (выживает при reload сцены и смерти)
# ---------------------------------------------------------------------------

## Сохранённый уровень. Сбрасывается только при новой игре.
var saved_level: int = 1
var saved_xp: int = 0
## Базовые атрибуты (без классового бонуса и экипировки).
var saved_str: float = 5.0
var saved_dex: float = 5.0
var saved_end: float = 5.0
var saved_int: float = 5.0
var saved_arc: float = 5.0
var saved_lck: float = 5.0
var saved_attr_points: int = 0

# ---------------------------------------------------------------------------
# Жизненный цикл
# ---------------------------------------------------------------------------

func _ready() -> void:
	add_to_group("player_data")


# ---------------------------------------------------------------------------
# API
# ---------------------------------------------------------------------------

## Добавить золото.
func add_gold(amount: int) -> void:
	gold = max(0, gold + amount)


## Потратить золото. Возвращает false если не хватает.
func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	return true


## Добавить зелья — кладёт в первый незаполненный слот (до 5 штук в слоте).
func add_potions(count: int) -> void:
	var remaining: int = count
	for i in range(4):
		if remaining <= 0:
			break
		var space: int = 5 - potion_slots[i]
		var add: int = mini(space, remaining)
		potion_slots[i] += add
		remaining -= add


## Использовать зелье из слота [param slot] (0–3). Возвращает false если слот пуст.
func use_potion(slot: int = 0) -> bool:
	if slot < 0 or slot >= 4:
		return false
	if potion_slots[slot] <= 0:
		return false
	potion_slots[slot] -= 1
	return true


# Квестовые методы перенесены в QuestSystem (Autoload — src/core/QuestSystem.gd).
# Используй QuestSystem.notify_enemy_killed(), QuestSystem.complete_stage() и т.д.
