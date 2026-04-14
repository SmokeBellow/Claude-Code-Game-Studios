class_name LootTable
extends Resource

## Таблица дропа. Хранит вероятность и пул предметов по редкости.
## Предметы указываются по ID (имя файла без .tres).
## Файлы ищутся в res://assets/data/items/.

@export var drop_chance: float = 0.30

@export var common_items:   Array[String] = []
@export var uncommon_items: Array[String] = []
@export var rare_items:     Array[String] = []
@export var epic_items:     Array[String] = []

# Веса редкостей (должны суммироваться в 1.0).
@export var weight_common:   float = 0.70
@export var weight_uncommon: float = 0.25
@export var weight_rare:     float = 0.05
@export var weight_epic:     float = 0.00


## Бросок на дроп. Возвращает ItemResource или null.
func roll() -> ItemResource:
	if randf() > drop_chance:
		return null
	var item_id: String = _pick_id()
	if item_id.is_empty():
		return null
	return _load_item(item_id)


func _pick_id() -> String:
	var r: float = randf()
	var pool: Array[String]

	if r < weight_epic:
		pool = epic_items if not epic_items.is_empty() else rare_items
	elif r < weight_epic + weight_rare:
		pool = rare_items if not rare_items.is_empty() else uncommon_items
	elif r < weight_epic + weight_rare + weight_uncommon:
		pool = uncommon_items if not uncommon_items.is_empty() else common_items
	else:
		pool = common_items

	if pool.is_empty():
		return ""
	return pool.pick_random()


func _load_item(id: String) -> ItemResource:
	var path: String = "res://assets/data/items/%s.tres" % id
	if not ResourceLoader.exists(path):
		push_warning("LootTable: предмет не найден: %s" % path)
		return null
	return load(path) as ItemResource
