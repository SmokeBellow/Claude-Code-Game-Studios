class_name LootSystem
extends Node

## Слушает сигналы смерти врагов и спавнит LootPickup.
## Лут-таблицы загружаются по соглашению:
## EnemyData.loot_table_id → res://assets/data/loot/{id}.tres

const _PickupScene = preload("res://scenes/loot_pickup.tscn")

# Кеш загруженных таблиц.
var _table_cache: Dictionary = {}


## Подключает врага к системе лута. Вызывается из Main.wire_enemy().
func wire_enemy(enemy: Node) -> void:
	if not enemy is BaseEnemy:
		return
	var data: EnemyData = (enemy as BaseEnemy).data
	if data == null or data.loot_table_id.is_empty():
		return
	enemy.enemy_died.connect(_on_enemy_died.bind(enemy, data.loot_table_id))


func _on_enemy_died(_xp: int, _data: EnemyData, enemy: Node, table_id: String) -> void:
	if not is_instance_valid(enemy):
		return
	var death_pos: Vector2 = (enemy as Node2D).global_position
	var table: LootTable = _get_table(table_id)
	if table == null:
		return

	var item: ItemResource = table.roll()
	if item == null:
		return

	_spawn_pickup(item, death_pos)


func _spawn_pickup(item: ItemResource, world_pos: Vector2) -> void:
	var pickup: Node = _PickupScene.instantiate()
	# Добавляем в Main чтобы пикап пережил переход комнаты.
	var main := get_tree().get_first_node_in_group("main")
	if main != null:
		main.add_child(pickup)
	else:
		get_tree().root.add_child(pickup)
	pickup.global_position = world_pos + Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
	pickup.init(item)


func _get_table(id: String) -> LootTable:
	if _table_cache.has(id):
		return _table_cache[id]
	var path: String = "res://assets/data/loot/%s.tres" % id
	if not ResourceLoader.exists(path):
		return null
	var table: LootTable = load(path) as LootTable
	_table_cache[id] = table
	return table
