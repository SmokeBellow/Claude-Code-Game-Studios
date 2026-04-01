class_name Inventory
extends Node

## Инвентарь персонажа: экипировка + сумка.
## LootPickup кладёт предметы в сумку (без автоэкипировки).
## Игрок экипирует вручную через BagScreen.

signal item_added_to_bag(item: ItemResource)
signal item_equipped(slot: int, item: ItemResource)
signal item_unequipped(slot: int, item: ItemResource)

# slot (int) → ItemResource
var _equipped: Dictionary = {}
# Неэкипированные предметы
var _bag: Array[ItemResource] = []
var _stats: StatsComponent = null


func _ready() -> void:
	add_to_group("inventory")
	await get_tree().process_frame
	for p in get_tree().get_nodes_in_group("player"):
		_stats = p.get_node_or_null("StatsComponent") as StatsComponent
		if _stats != null:
			break


## Добавляет предмет в сумку (вызывается LootPickup).
func pickup_item(item: ItemResource) -> void:
	if item == null:
		return
	_bag.append(item)
	item_added_to_bag.emit(item)
	# Квестовые предметы — уведомляем PlayerData.
	if item.item_id == "elite_seal":
		PlayerData.notify_seal_picked()


## Экипирует предмет из сумки. Если слот занят — старый уходит в сумку.
func equip_item(item: ItemResource) -> void:
	if item == null or not _bag.has(item):
		return
	var slot: int = item.slot
	if _equipped.has(slot):
		unequip_slot(slot)
	_bag.erase(item)
	_equipped[slot] = item
	_apply_bonuses(item)
	item_equipped.emit(slot, item)


## Снимает предмет из слота → возвращает в сумку.
func unequip_slot(slot: int) -> void:
	if not _equipped.has(slot):
		return
	var old: ItemResource = _equipped[slot] as ItemResource
	_equipped.erase(slot)
	_bag.append(old)
	_remove_bonuses(old)
	item_unequipped.emit(slot, old)


func get_equipped_item(slot: int) -> ItemResource:
	return _equipped.get(slot) as ItemResource


func get_bag() -> Array[ItemResource]:
	return _bag.duplicate()


func get_all_equipped() -> Dictionary:
	return _equipped.duplicate()


## Удаляет предмет из сумки (выброс на землю — без продажи).
func drop_item(item: ItemResource) -> void:
	if item == null:
		return
	_bag.erase(item)


## Продаёт предмет из сумки торговцу. Возвращает полученное золото (0 если предмет не найден).
func sell_item_from_bag(item: ItemResource) -> int:
	if item == null or not _bag.has(item):
		return 0
	_bag.erase(item)
	var value: int = item.sell_value()
	PlayerData.add_gold(value)
	return value


func _apply_bonuses(item: ItemResource) -> void:
	if _stats == null:
		return
	_stats.apply_equipment_bonus(
		item.bonus_strength, item.bonus_dexterity, item.bonus_endurance,
		item.bonus_intelligence, item.bonus_arcana, item.bonus_luck
	)


func _remove_bonuses(item: ItemResource) -> void:
	if _stats == null:
		return
	_stats.remove_equipment_bonus(
		item.bonus_strength, item.bonus_dexterity, item.bonus_endurance,
		item.bonus_intelligence, item.bonus_arcana, item.bonus_luck
	)
