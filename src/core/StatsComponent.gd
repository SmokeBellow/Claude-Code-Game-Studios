class_name StatsComponent
extends Node

## Управляет первичными атрибутами и производными статами героя (или врага).
## [br]
## Является единственным источником истины о характеристиках сущности.
## Другие системы читают производные через методы этого компонента.
## [br]
## [b]Архитектура:[/b] пассивная система — хранит данные, не обращается к другим системам.
## [br]
## GDD: [code]design/gdd/health-stats.md[/code]

# ---------------------------------------------------------------------------
# Сигналы
# ---------------------------------------------------------------------------

## Испускается при любом изменении атрибутов или экипировки.
signal stats_changed

# ---------------------------------------------------------------------------
# Первичные атрибуты (начальное значение: 5 на уровне 1)
# ---------------------------------------------------------------------------

@export_group("Primary Attributes")
## Сила — физический урон.
@export var strength: float = 5.0
## Ловкость — скорость движения, атаки, шанс уклонения.
@export var dexterity: float = 5.0
## Выносливость — макс HP, реген HP, сопротивление эффектам.
@export var endurance: float = 5.0
## Интеллект — макс мана, реген маны.
@export var intelligence: float = 5.0
## Аркана — сила способностей.
@export var arcana: float = 5.0
## Удача — шанс крита, множитель крит-урона.
@export var luck: float = 5.0

# ---------------------------------------------------------------------------
# Нераспределённые очки атрибутов
# ---------------------------------------------------------------------------

## Накопленные нераспределённые очки. Начисляются через [method add_attribute_points].
var attribute_points: int = 0

func _ready() -> void:
	# Восстанавливаем атрибуты из PlayerData при повторном запуске сцены.
	if PlayerData.saved_level > 1 or PlayerData.saved_str > 5.0:
		strength     = PlayerData.saved_str
		dexterity    = PlayerData.saved_dex
		endurance    = PlayerData.saved_end
		intelligence = PlayerData.saved_int
		arcana       = PlayerData.saved_arc
		luck         = PlayerData.saved_lck
		attribute_points = PlayerData.saved_attr_points
		if PlayerData.player_class != PlayerData.CLASS_NONE:
			PlayerData.apply_class_stats(self)
		stats_changed.emit()

# ---------------------------------------------------------------------------
# Бонусы от экипировки (устанавливаются системой инвентаря)
# ---------------------------------------------------------------------------

var _equip_str: float = 0.0
var _equip_dex: float = 0.0
var _equip_end: float = 0.0
var _equip_int: float = 0.0
var _equip_arc: float = 0.0
var _equip_lck: float = 0.0

# ---------------------------------------------------------------------------
# Константы капов (Elden Ring-стиль)
# ---------------------------------------------------------------------------

const SOFT_CAP_1: float = 30.0  ## 100% возврат ниже этого порога
const SOFT_CAP_2: float = 55.0  ## 60% возврат от SC1 до SC2
const HARD_CAP: float = 70.0    ## 30% возврат от SC2 до HC; выше — невозможно

# ---------------------------------------------------------------------------
# Публичный API: атрибуты с кепом
# ---------------------------------------------------------------------------

## Возвращает итоговое значение атрибута (базовый + экипировка), зажатое на HARD_CAP.
func total_str() -> float: return minf(strength + _equip_str, HARD_CAP)
## Возвращает итоговое значение DEX.
func total_dex() -> float: return minf(dexterity + _equip_dex, HARD_CAP)
## Возвращает итоговое значение END.
func total_end() -> float: return minf(endurance + _equip_end, HARD_CAP)
## Возвращает итоговое значение INT.
func total_int() -> float: return minf(intelligence + _equip_int, HARD_CAP)
## Возвращает итоговое значение ARC.
func total_arc() -> float: return minf(arcana + _equip_arc, HARD_CAP)
## Возвращает итоговое значение LCK.
func total_lck() -> float: return minf(luck + _equip_lck, HARD_CAP)

# ---------------------------------------------------------------------------
# Публичный API: функция капов
# ---------------------------------------------------------------------------

## Применяет трёхзонный кап к сырому значению атрибута.
## [br]Зоны: [5–30] 100% | [30–55] 60% | [55–70] 30% | 70+ невозможно.
func effective(raw: float) -> float:
	var a: float = minf(raw, HARD_CAP)
	if a <= SOFT_CAP_1:
		return a
	elif a <= SOFT_CAP_2:
		return SOFT_CAP_1 + (a - SOFT_CAP_1) * 0.6
	else:
		return 45.0 + (a - SOFT_CAP_2) * 0.3

# ---------------------------------------------------------------------------
# Публичный API: производные статы
# ---------------------------------------------------------------------------

## Макс HP. Формула: [code](60 + 8 * E(END)) * (1 + skill_hp_pct)[/code]. При уровне 1: 100.
func max_hp() -> float:
	return (60.0 + 8.0 * effective(total_end())) * (1.0 + _skill_hp_pct)

## Реген HP в секунду. Формула: [code]0.2 * E(END)[/code].
func hp_regen_per_sec() -> float:
	return 0.2 * effective(total_end())

## Сопротивление эффектам %. Формула: [code]min(75, 1.5 * E(END))[/code].
func effect_resistance() -> float:
	return minf(75.0, 1.5 * effective(total_end()))

## Скорость движения px/s. Формула: [code]clamp(165 + 3*E(DEX), 150, 280)[/code]. При уровне 1: 180.
func move_speed() -> float:
	return clampf(165.0 + 3.0 * effective(total_dex()), 150.0, 280.0)

## Скорость атаки (множитель). Формула: [code]min(2.0, 0.9 + 0.02*E(DEX))[/code].
func attack_speed() -> float:
	return minf(2.0, 0.9 + 0.02 * effective(total_dex()))

## Шанс уклонения %. Формула: [code]min(40, E(DEX))[/code].
func dodge_chance() -> float:
	return minf(40.0, effective(total_dex()))

## Плоский бонус к физ. урону. Формула: [code]E(STR) * (1 + skill_dmg_pct)[/code].
func phys_damage_bonus() -> float:
	return effective(total_str()) * (1.0 + _skill_dmg_pct)

## Макс мана. Формула: [code]30 + 4*E(INT)[/code]. При уровне 1: 50.
func max_mana() -> float:
	return 30.0 + 4.0 * effective(total_int())

## Реген маны в секунду. Формула: [code]0.1 * E(INT)[/code].
func mana_regen_per_sec() -> float:
	return 0.1 * effective(total_int())

## Сила способностей (множитель). Формула: [code]0.83 + 0.034*E(ARC)[/code]. При уровне 1: 1.0.
func ability_power() -> float:
	return 0.83 + 0.034 * effective(total_arc())

## Шанс крита %. Формула: [code]min(50, E(LCK) + skill_crit_bonus)[/code].
func crit_chance() -> float:
	return minf(50.0, effective(total_lck()) + _skill_crit_bonus)

## Множитель крит-урона. Формула: [code]1.4 + 0.02*E(LCK)[/code]. При уровне 1: 1.5x.
func crit_multiplier() -> float:
	return 1.4 + 0.02 * effective(total_lck())

# ---------------------------------------------------------------------------
# Публичный API: очки атрибутов
# ---------------------------------------------------------------------------

## Начисляет очки атрибутов (вызывается системой уровней и XP).
func add_attribute_points(amount: int) -> void:
	attribute_points += amount
	PlayerData.saved_attr_points = attribute_points

## Тратит [param amount] очков на атрибут [param attr_name].
## [br]Возвращает [code]false[/code] если нет очков или атрибут на хард капе.
func spend_points(attr_name: String, amount: int = 1) -> bool:
	if attribute_points < amount:
		return false
	match attr_name:
		"strength":
			if strength >= HARD_CAP:
				return false
			strength = minf(strength + amount, HARD_CAP)
		"dexterity":
			if dexterity >= HARD_CAP:
				return false
			dexterity = minf(dexterity + amount, HARD_CAP)
		"endurance":
			if endurance >= HARD_CAP:
				return false
			endurance = minf(endurance + amount, HARD_CAP)
		"intelligence":
			if intelligence >= HARD_CAP:
				return false
			intelligence = minf(intelligence + amount, HARD_CAP)
		"arcana":
			if arcana >= HARD_CAP:
				return false
			arcana = minf(arcana + amount, HARD_CAP)
		"luck":
			if luck >= HARD_CAP:
				return false
			luck = minf(luck + amount, HARD_CAP)
		_:
			push_error("StatsComponent: неизвестный атрибут '%s'" % attr_name)
			return false
	attribute_points -= amount
	_save_to_player_data()
	stats_changed.emit()
	return true

# ---------------------------------------------------------------------------
# Публичный API: бонусы экипировки
# ---------------------------------------------------------------------------

## Применяет бонусы экипированного предмета. Вызывается системой инвентаря.
func apply_equipment_bonus(str_b: float, dex_b: float, end_b: float,
		int_b: float, arc_b: float, lck_b: float) -> void:
	_equip_str += str_b
	_equip_dex += dex_b
	_equip_end += end_b
	_equip_int += int_b
	_equip_arc += arc_b
	_equip_lck += lck_b
	stats_changed.emit()

## Снимает бонусы снятого предмета. Вызывается системой инвентаря.
func remove_equipment_bonus(str_b: float, dex_b: float, end_b: float,
		int_b: float, arc_b: float, lck_b: float) -> void:
	_equip_str -= str_b
	_equip_dex -= dex_b
	_equip_end -= end_b
	_equip_int -= int_b
	_equip_arc -= arc_b
	_equip_lck -= lck_b
	stats_changed.emit()

# ---------------------------------------------------------------------------
# Бонусы от навыков
# ---------------------------------------------------------------------------

## Суммарный % бонус к макс HP от пассивов (0.10 = +10%).
var _skill_hp_pct: float = 0.0
## Суммарный % бонус к физ. урону от пассивов (0.20 = +20%).
var _skill_dmg_pct: float = 0.0
## Снижение получаемого урона от пассивов (0.15 = -15%).
var _skill_dmg_red: float = 0.0
## Плоский бонус к шансу крита (%).
var _skill_crit_bonus: float = 0.0
## Бонус к урону светом (Паладин). Используется CombatComponent.
var _skill_light_dmg: float = 0.0
## Триггерные пассивы: id → значение. Читаются через [method get_passive].
var _passives: Dictionary = {}

## Применяет постоянный бонус пассивного навыка из SkillTree.
## Вызывается SkillTree._apply_node_effect(). Стакается при повторном вызове.
## [br]Пример: [code]stats.apply_skill_passive("general_0")[/code]
func apply_skill_passive(passive_id: String) -> void:
	match passive_id:
		# ── Общие (все классы) ─────────────────────────────────────────────
		"general_0", "general_1":
			_skill_hp_pct  += 0.05   # +5% макс HP
			_skill_dmg_pct += 0.05   # +5% физ. урон
		# ── Воин: Берсерк ─────────────────────────────────────────────────
		"warrior_berserk_1":   # +15% урона при HP < 50% (триггер в CombatComponent)
			_passives["low_hp_dmg_bonus"] = _passives.get("low_hp_dmg_bonus", 0.0) + 0.15
		"warrior_berserk_3":   # Убийство: +5% HP (триггер в Main.wire_enemy)
			_passives["kill_heal_pct"] = _passives.get("kill_heal_pct", 0.0) + 0.05
		# ── Воин: Танк ────────────────────────────────────────────────────
		"warrior_tank_1":
			_skill_hp_pct  += 0.20   # +20% макс HP
		"warrior_tank_3":
			_skill_dmg_red += 0.15   # -15% входящий урон
		# ── Воин: Паладин ─────────────────────────────────────────────────
		"warrior_paladin_1":
			_skill_light_dmg += 10.0  # +10 к урону светом
		"warrior_paladin_3":   # Убийство светом: +3% HP (триггер)
			_passives["light_kill_heal_pct"] = _passives.get("light_kill_heal_pct", 0.0) + 0.03
		# ── Плут: Стеклянная пушка ────────────────────────────────────────
		"rogue_glass_1":
			_skill_dmg_pct += 0.20   # +20% урона
			_skill_hp_pct  -= 0.10   # -10% HP
		"rogue_glass_3":
			_skill_crit_bonus += 15.0  # +15% шанс крита
		_:
			push_warning("StatsComponent: неизвестный passive_id '%s'" % passive_id)
			return
	stats_changed.emit()

## Возвращает значение триггерного пассива (0.0 если не активен).
## [br]Пример: [code]stats.get_passive("low_hp_dmg_bonus")[/code]
func get_passive(id: String) -> float:
	return float(_passives.get(id, 0.0))

## Возвращает множитель снижения входящего урона от навыков (0.0–1.0).
func skill_dmg_reduction() -> float:
	return clampf(_skill_dmg_red, 0.0, 0.75)

## Возвращает бонус к урону светом от навыков (Паладин).
func skill_light_dmg() -> float:
	return _skill_light_dmg

func _save_to_player_data() -> void:
	PlayerData.saved_str        = strength
	PlayerData.saved_dex        = dexterity
	PlayerData.saved_end        = endurance
	PlayerData.saved_int        = intelligence
	PlayerData.saved_arc        = arcana
	PlayerData.saved_lck        = luck
	PlayerData.saved_attr_points = attribute_points
