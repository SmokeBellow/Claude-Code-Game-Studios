class_name ItemResource
extends Resource

## Предмет экипировки. Сохраняется как .tres в assets/data/items/.

enum Rarity { COMMON, UNCOMMON, RARE, EPIC }
enum Slot { WEAPON, HELMET, ARMOR, GLOVES, BOOTS, RING1, RING2, AMULET }

@export var item_id: String = ""
@export var display_name: String = "Предмет"
@export_enum("COMMON", "UNCOMMON", "RARE", "EPIC") var rarity: int = Rarity.COMMON
@export_enum("WEAPON", "HELMET", "ARMOR", "GLOVES", "BOOTS", "RING1", "RING2", "AMULET") var slot: int = Slot.WEAPON
@export var required_level: int = 1

# Бонусы к атрибутам (передаются в StatsComponent.apply_equipment_bonus).
@export var bonus_strength: float = 0.0
@export var bonus_dexterity: float = 0.0
@export var bonus_endurance: float = 0.0
@export var bonus_intelligence: float = 0.0
@export var bonus_arcana: float = 0.0
@export var bonus_luck: float = 0.0

## Если true — предмет нельзя экипировать, только продать. Цену задаёт junk_value.
@export var is_junk: bool = false
@export var junk_value: int = 5


## Цвет редкости для UI.
func rarity_color() -> Color:
	match rarity:
		Rarity.UNCOMMON: return Color(0.4, 0.9, 0.4)
		Rarity.RARE:     return Color(0.4, 0.6, 1.0)
		Rarity.EPIC:     return Color(0.8, 0.3, 1.0)
		_:               return Color(0.85, 0.85, 0.85)


## Цена продажи предмета торговцу (зависит от редкости; для мусора — junk_value).
func sell_value() -> int:
	if is_junk:
		return junk_value
	match rarity:
		Rarity.UNCOMMON: return 25
		Rarity.RARE:     return 60
		Rarity.EPIC:     return 150
		_:               return 10  # COMMON


## Короткое описание бонусов для UI.
func bonus_summary() -> String:
	var parts: Array[String] = []
	if bonus_strength    != 0.0: parts.append("+%d СИЛ" % int(bonus_strength))
	if bonus_dexterity   != 0.0: parts.append("+%d ЛОВ" % int(bonus_dexterity))
	if bonus_endurance   != 0.0: parts.append("+%d ВЫН" % int(bonus_endurance))
	if bonus_intelligence != 0.0: parts.append("+%d ИНТ" % int(bonus_intelligence))
	if bonus_arcana      != 0.0: parts.append("+%d АРК" % int(bonus_arcana))
	if bonus_luck        != 0.0: parts.append("+%d УДА" % int(bonus_luck))
	return "  ".join(parts)
