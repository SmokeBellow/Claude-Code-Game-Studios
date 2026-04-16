class_name Inventory
extends Node

## Инвентарь персонажа: сумка (до 20 слотов) + 8 слотов экипировки.
## Implements: design/gdd/inventory.md
##
## LootPickup кладёт предметы в сумку через pickup_item().
## Игрок экипирует вручную через BagScreen → equip_item().
##
## Сериализация (SaveSystem):
##   Вызывается SaveSystem; данные хранятся как массив item_id (String).
##   При загрузке из меню SaveSystem держит данные в буфере до появления ноды.
##
## Пример использования:
##   inventory.pickup_item(item)        # добавить в сумку (false если полна)
##   inventory.equip_item(item)         # экипировать из сумки
##   inventory.is_bag_full()            # проверить вместимость
##   var data := inventory.serialize()  # для SaveSystem

# ---------------------------------------------------------------------------
# Константы
# ---------------------------------------------------------------------------

const BAG_MAX_SIZE: int = 20
const ITEM_DIR     := "res://assets/data/items/"

# ---------------------------------------------------------------------------
# Сигналы
# ---------------------------------------------------------------------------

signal item_added_to_bag(item: ItemResource)
signal item_equipped(slot: int, item: ItemResource)
signal item_unequipped(slot: int, item: ItemResource)
signal bag_full()   ## Эмитируется при попытке добавить предмет в полную сумку

# ---------------------------------------------------------------------------
# Хранилище
# ---------------------------------------------------------------------------

## slot (ItemResource.Slot int) → ItemResource
var _equipped: Dictionary = {}
## Неэкипированные предметы (ограничено BAG_MAX_SIZE)
var _bag: Array[ItemResource] = []
## Ссылка на StatsComponent игрока (для применения бонусов экипировки)
var _stats: StatsComponent = null

# ---------------------------------------------------------------------------
# Жизненный цикл
# ---------------------------------------------------------------------------

func _ready() -> void:
	add_to_group("inventory")
	await get_tree().process_frame
	for p: Node in get_tree().get_nodes_in_group("player"):
		_stats = p.get_node_or_null("StatsComponent") as StatsComponent
		if _stats != null:
			break

	# Подхватываем pending-данные от SaveSystem (загрузка из главного меню)
	if SaveSystem.has_pending_inventory():
		deserialize(SaveSystem.take_pending_inventory())

# ---------------------------------------------------------------------------
# Публичный API — добавление / удаление
# ---------------------------------------------------------------------------

## Добавляет предмет в сумку (вызывается LootPickup).
## Возвращает false если сумка заполнена — предмет остаётся лежать на земле.
func pickup_item(item: ItemResource) -> bool:
	if item == null:
		return false
	if _bag.size() >= BAG_MAX_SIZE:
		bag_full.emit()
		return false
	_bag.append(item)
	item_added_to_bag.emit(item)
	# Квестовые предметы — уведомляем QuestSystem
	if item.item_id == "elite_seal":
		QuestSystem.notify_seal_picked()
	return true


## Экипирует предмет из сумки. Если слот занят — старый уходит в сумку.
func equip_item(item: ItemResource) -> void:
	if item == null or not _bag.has(item):
		return
	if item.is_junk:
		return
	var slot: int = item.slot
	if _equipped.has(slot):
		unequip_slot(slot)
	_bag.erase(item)
	_equipped[slot] = item
	_apply_bonuses(item)
	item_equipped.emit(slot, item)


## Снимает предмет из слота → возвращает в сумку (если есть место).
func unequip_slot(slot: int) -> void:
	if not _equipped.has(slot):
		return
	var old: ItemResource = _equipped[slot] as ItemResource
	_equipped.erase(slot)
	if _bag.size() < BAG_MAX_SIZE:
		_bag.append(old)
	_remove_bonuses(old)
	item_unequipped.emit(slot, old)


## Удаляет предмет из сумки (выброс на землю — без продажи).
func drop_item(item: ItemResource) -> void:
	if item == null:
		return
	_bag.erase(item)


## Продаёт предмет из сумки торговцу. Возвращает полученное золото (0 если не найден).
func sell_item_from_bag(item: ItemResource) -> int:
	if item == null or not _bag.has(item):
		return 0
	_bag.erase(item)
	var value: int = item.sell_value()
	PlayerData.add_gold(value)
	return value

# ---------------------------------------------------------------------------
# Публичный API — запросы
# ---------------------------------------------------------------------------

## Возвращает true если сумка заполнена (BAG_MAX_SIZE предметов).
func is_bag_full() -> bool:
	return _bag.size() >= BAG_MAX_SIZE


## Возвращает число свободных слотов в сумке.
func bag_free_slots() -> int:
	return BAG_MAX_SIZE - _bag.size()


func get_equipped_item(slot: int) -> ItemResource:
	return _equipped.get(slot) as ItemResource


func get_bag() -> Array[ItemResource]:
	return _bag.duplicate()


func get_all_equipped() -> Dictionary:
	return _equipped.duplicate()

# ---------------------------------------------------------------------------
# Сериализация (SaveSystem)
# ---------------------------------------------------------------------------

## Сериализует состояние инвентаря в Dictionary для SaveSystem.
func serialize() -> Dictionary:
	var bag_ids: Array[String] = []
	for item: ItemResource in _bag:
		bag_ids.append(item.item_id)

	var equipped_ids: Dictionary = {}
	for slot: int in _equipped.keys():
		var item: ItemResource = _equipped[slot] as ItemResource
		equipped_ids[str(slot)] = item.item_id

	return {
		"version": 1,
		"bag":      bag_ids,
		"equipped": equipped_ids,
	}


## Восстанавливает состояние инвентаря из Dictionary (SaveSystem).
## Вызывается либо из _ready() (через pending-буфер), либо напрямую если нода уже активна.
func deserialize(data: Dictionary) -> void:
	_bag.clear()
	_equipped.clear()

	# Восстанавливаем сумку
	var bag_ids: Array = data.get("bag", [])
	for id: Variant in bag_ids:
		var item: ItemResource = _load_item(str(id))
		if item != null and _bag.size() < BAG_MAX_SIZE:
			_bag.append(item)

	# Восстанавливаем экипировку (бонусы не применяем — это делает _reapply_equipment_bonuses)
	var equipped_ids: Dictionary = data.get("equipped", {})
	for slot_str: String in equipped_ids.keys():
		var item: ItemResource = _load_item(str(equipped_ids[slot_str]))
		if item != null:
			_equipped[int(slot_str)] = item


## Повторно применяет бонусы экипированных предметов к StatsComponent.
## Вызывается SaveSystem._try_reapply_equipment() после полной загрузки данных.
func _reapply_equipment_bonuses() -> void:
	# Переинициализируем _stats на случай если при deserialize() нода ещё не была ready
	if _stats == null:
		for p: Node in get_tree().get_nodes_in_group("player"):
			_stats = p.get_node_or_null("StatsComponent") as StatsComponent
			if _stats != null:
				break
	for item: ItemResource in _equipped.values():
		_apply_bonuses(item)

# ---------------------------------------------------------------------------
# Приватные методы
# ---------------------------------------------------------------------------

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


func _load_item(item_id: String) -> ItemResource:
	if item_id.is_empty():
		return null
	var path: String = ITEM_DIR + item_id + ".tres"
	if not ResourceLoader.exists(path):
		push_warning("Inventory: предмет не найден: %s" % path)
		return null
	return load(path) as ItemResource
