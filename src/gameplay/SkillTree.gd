class_name SkillTree
extends Node

## Система дерева навыков. Управляет покупкой узлов, разблокировкой веток
## и применением пассивных бонусов к StatsComponent.
## [br]
## GDD: [code]design/gdd/skill-tree.md[/code]
##
## Использование:
##   var st := SkillTree.new()
##   player.add_child(st)
##   st.setup(stats, cas, level_xp)

# ---------------------------------------------------------------------------
# Сигналы
# ---------------------------------------------------------------------------

## Испускается при покупке узла. SidePanel слушает для обновления UI.
signal node_purchased(branch_key: String, node_index: int)
## Испускается при изменении доступных очков. SidePanel слушает для счётчика.
signal skill_points_changed(available: int)

# ---------------------------------------------------------------------------
# Константы (tuning knobs из GDD)
# ---------------------------------------------------------------------------

## Очков в общем навыке для разблокировки специализаций.
const GENERAL_GATE: int = 2

## Ветки специализации по классу: class_id → [branch0, branch1, branch2].
## Все три ветки доступны одновременно после выполнения GENERAL_GATE.
const CLASS_BRANCHES: Dictionary = {
	1: ["warrior_berserk", "warrior_tank", "warrior_paladin"],
	2: ["mage_fire", "mage_ice", "mage_lightning"],
	3: ["rogue_glass", "rogue_stealth", "rogue_poison"],
}

## Данные узлов: branch_key → [[type, name, desc, passive_id], ...].
## type: "active" | "passive" | "ultimate"
## passive_id непустой только у пассивных узлов с прямым эффектом на StatsComponent.
const NODES: Dictionary = {
	## Общий навык — шлюз перед специализациями (все классы).
	"general": [
		["passive", "Закалка боем I",  "+5% HP и +5% к урону", "general_0"],
		["passive", "Закалка боем II", "+5% HP и +5% к урону", "general_1"],
	],
	"warrior_berserk": [
		["active",   "Яростный удар",  "Апгрейд атаки: AoE-урон вокруг", ""],
		["passive",  "Жажда крови",    "+15% урона при HP < 50%", "warrior_berserk_1"],
		["active",   "Вихрь",          "Апгрейд: атака по кругу с отбросом", ""],
		["passive",  "Адреналин",      "Убийство: +5% HP", "warrior_berserk_3"],
		["ultimate", "Берсерк",        "8 сек: урон ×3, скорость ×2. КД 45 сек", ""],
	],
	"warrior_tank": [
		["active",   "Щитовой удар",   "Апгрейд: стан 0.5 сек", ""],
		["passive",  "Закалка",        "+20% HP", "warrior_tank_1"],
		["active",   "Провокация",     "Враги атакуют тебя 3 сек", ""],
		["passive",  "Железная кожа",  "-15% получаемого урона", "warrior_tank_3"],
		["ultimate", "Несокрушимость", "5 сек иммунитет к урону. КД 60 сек", ""],
	],
	"warrior_paladin": [
		["active",   "Святой удар",  "Апгрейд: +урон светом, сквозь броню", ""],
		["passive",  "Аура света",   "+10 к урону светом", "warrior_paladin_1"],
		["active",   "Луч света",    "Апгрейд: луч по линии", ""],
		["passive",  "Благодать",    "Убийство светом: +3% HP", "warrior_paladin_3"],
		["ultimate", "Суд",          "Большой AoE свет, оглушение 3 сек. КД 40 сек", ""],
	],
	"mage_fire": [
		["active",   "Огненный шар+",  "Апгрейд: оставляет огненную зону 2 сек", ""],
		["passive",  "Горение",        "+10% урона целям с огнём", ""],
		["active",   "Взрыв",          "Апгрейд: шар взрывается при контакте", ""],
		["passive",  "Испепеление",    "Крит огнём: поджигает на 3 сек", ""],
		["ultimate", "Метеор",         "Через 1.5 сек AoE в точку курсора. КД 50 сек", ""],
	],
	"mage_ice": [
		["active",   "Ледяная стрела+",     "Апгрейд: замедляет на 30% на 2 сек", ""],
		["passive",  "Хрупкость",           "+15% урона замедленным", ""],
		["active",   "Ледяной взрыв",       "Апгрейд: взрыв на осколки", ""],
		["passive",  "Глубокое замораживание", "Замедление +1 сек", ""],
		["ultimate", "Ледяная буря",        "Тики урона вокруг 6 сек. КД 45 сек", ""],
	],
	"mage_lightning": [
		["active",   "Разряд+",        "Апгрейд: бьёт 2 цели", ""],
		["passive",  "Проводимость",   "Каждый 3-й удар молнией — крит", ""],
		["active",   "Шаровая молния", "Апгрейд: медленный шар по пути", ""],
		["passive",  "Перегрузка",     "Крит молнией: оглушение 0.5 сек", ""],
		["ultimate", "Цепной разряд",  "Цепь до 8 врагов, убывающий урон. КД 35 сек", ""],
	],
	"rogue_glass": [
		["active",   "Смертельный бросок+", "Апгрейд: кинжал пробивает насквозь", ""],
		["passive",  "Острое лезвие",       "+20% урона, -10% HP", "rogue_glass_1"],
		["active",   "Веер клинков",        "Апгрейд: 3 кинжала веером", ""],
		["passive",  "Смертоносность",      "+15% крит шанс", "rogue_glass_3"],
		["ultimate", "Смертельный удар",    "Следующая атака ×10 урона. КД 40 сек", ""],
	],
	"rogue_stealth": [
		["active",   "Тихий шаг+",   "Апгрейд: быстрее в стелс, +50% удар из стелса", ""],
		["passive",  "Тень",         "+20% скорость в стелсе", ""],
		["active",   "Удар в спину", "Апгрейд: телепорт за врага + удар", ""],
		["passive",  "Невидимка",    "Выход из стелса без атаки не тратит заряд", ""],
		["ultimate", "Двойник",      "Иллюзия атакует врага 6 сек, игрок невидим. КД 50 сек", ""],
	],
	"rogue_poison": [
		["active",   "Отравленный клинок+", "Апгрейд: каждая атака — стак яда", ""],
		["passive",  "Концентрат",          "+5% урона яда за стак", ""],
		["active",   "Дымовая бомба+",      "Апгрейд: AoE яда + слепота 2 сек", ""],
		["passive",  "Разложение",          "Стаки яда до 8", ""],
		["ultimate", "Заражение",           "1 стак/сек на 8 сек всем вокруг. КД 45 сек", ""],
	],
}

# ---------------------------------------------------------------------------
# Состояние
# ---------------------------------------------------------------------------

var _stats: StatsComponent = null

# ---------------------------------------------------------------------------
# Публичный API
# ---------------------------------------------------------------------------

## Инициализирует систему. Вызывается из Main.gd / Town.gd.
func setup(stats: StatsComponent, level_xp: LevelXPSystem) -> void:
	_stats = stats
	add_to_group("skill_tree")
	if level_xp != null:
		level_xp.level_up.connect(_on_level_up)
	# Стартовое очко для новой игры (1 очко с уровня 1).
	if PlayerData.saved_level == 1 and PlayerData.skill_points == 0 \
			and PlayerData.spent_points.is_empty():
		PlayerData.skill_points = 1
	_restore_passives()


## Тратит одно очко на следующий узел ветки branch_key.
## Возвращает false если очков нет, ветка недоступна или уже заполнена.
func spend_point(branch_key: String) -> bool:
	if PlayerData.skill_points <= 0:
		return false
	if not is_branch_available(branch_key):
		return false
	var points_in: int = int(PlayerData.spent_points.get(branch_key, 0))
	if points_in >= NODES[branch_key].size():
		return false

	PlayerData.skill_points -= 1
	PlayerData.spent_points[branch_key] = points_in + 1
	_apply_node_effect(branch_key, points_in)
	node_purchased.emit(branch_key, points_in)
	skill_points_changed.emit(PlayerData.skill_points)
	return true


## True если ветка доступна для вложения очков.
## Общий навык ("general") — всегда доступен.
## Специализации — доступны когда класс выбран и general >= GENERAL_GATE.
func is_branch_available(branch_key: String) -> bool:
	if branch_key == "general":
		return true
	if PlayerData.player_class == PlayerData.CLASS_NONE:
		return false
	var branches: Array = CLASS_BRANCHES.get(PlayerData.player_class, [])
	if branches.find(branch_key) < 0:
		return false
	return PlayerData.spent_points.get("general", 0) >= GENERAL_GATE


## True если узел node_index в ветке branch_key куплен.
func is_node_unlocked(branch_key: String, node_index: int) -> bool:
	return PlayerData.spent_points.get(branch_key, 0) > node_index


## Количество вложенных очков в ветку.
func get_branch_points(branch_key: String) -> int:
	return int(PlayerData.spent_points.get(branch_key, 0))


## Данные узла: [type, name, desc, passive_id]. Пустой массив если индекс вне диапазона.
func get_node_data(branch_key: String, node_index: int) -> Array:
	var branch: Array = NODES.get(branch_key, [])
	if node_index < 0 or node_index >= branch.size():
		return []
	return branch[node_index]


## Ветки специализации текущего класса (без "general").
func get_class_branches() -> Array:
	return CLASS_BRANCHES.get(PlayerData.player_class, [])

# ---------------------------------------------------------------------------
# Приватные методы
# ---------------------------------------------------------------------------

func _on_level_up(new_level: int, _attr_pts: int) -> void:
	# Уровень 1 — стартовый, очки начисляются со 2-го.
	if new_level > 1:
		PlayerData.skill_points += 1
		skill_points_changed.emit(PlayerData.skill_points)


func _apply_node_effect(branch_key: String, node_index: int) -> void:
	var node_data: Array = get_node_data(branch_key, node_index)
	if node_data.is_empty():
		return
	var passive_id: String = node_data[3]
	if passive_id.is_empty() or _stats == null:
		return  # Активные узлы и ультимейты без прямого стат-эффекта — проверяются через is_node_unlocked()
	_stats.apply_skill_passive(passive_id)


## При загрузке сцены заново применяем все купленные пассивы к StatsComponent.
func _restore_passives() -> void:
	for branch_key: String in PlayerData.spent_points:
		var points: int = PlayerData.spent_points[branch_key]
		for i: int in points:
			_apply_node_effect(branch_key, i)
