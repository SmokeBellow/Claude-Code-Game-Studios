class_name RoomManager
extends Node

## Управляет загрузкой/выгрузкой комнат и переходами между ними.
## Добавь как дочерний узел главной сцены.

signal room_changed(new_pos: Vector2i, room_data: RoomData)

## Количество комнат в данже (включая старт и босса).
@export var dungeon_size: int = 8
## Шаблон данных обычной комнаты.
@export var normal_room_data: RoomData
## Шаблон данных боссовой комнаты.
@export var boss_room_data: RoomData
## Сцена врага для спавна (можно расширить до массива).
@export var enemy_scene: PackedScene
## Ссылка на игрока для перемещения при переходе.
@export var player: CharacterBody2D

# Позиции дверей внутри комнаты (в локальных координатах комнаты).
const DOOR_OFFSETS: Dictionary = {
	"north": Vector2(0, -300),
	"south": Vector2(0,  300),
	"west":  Vector2(-500, 0),
	"east":  Vector2( 500, 0),
}
# Куда ставить игрока при входе с противоположной стороны.
const SPAWN_OFFSETS: Dictionary = {
	"north": Vector2(0, -240),
	"south": Vector2(0,  240),
	"west":  Vector2(-440, 0),
	"east":  Vector2( 440, 0),
}

var _layout: Dictionary = {}
var _current_pos: Vector2i = Vector2i(0, 0)
var _current_room: Node = null

func _ready() -> void:
	if normal_room_data == null or boss_room_data == null:
		push_error("RoomManager: заполни normal_room_data и boss_room_data")
		return
	_generate_and_load()


## Генерирует данжн и загружает стартовую комнату.
func _generate_and_load() -> void:
	_layout = DungeonGenerator.generate(dungeon_size, normal_room_data, boss_room_data)
	_load_room(Vector2i(0, 0), "")


## Загружает комнату в позиции [param grid_pos].
## [param entered_from] — направление откуда пришёл игрок (для позиционирования).
func _load_room(grid_pos: Vector2i, entered_from: String) -> void:
	# Выгружаем текущую комнату.
	if _current_room != null:
		_current_room.queue_free()
		_current_room = null

	_current_pos = grid_pos
	var data: RoomData = _layout.get(grid_pos)
	if data == null:
		push_error("RoomManager: нет комнаты на позиции %s" % grid_pos)
		return

	# Загружаем сцену.
	if data.scene == null:
		push_error("RoomManager: RoomData.scene не заполнен")
		return

	_current_room = data.scene.instantiate()
	add_child(_current_room)

	# Передаём данные комнате если она их принимает.
	if _current_room.has_method("setup"):
		_current_room.setup(data, self)

	# Прописываем room_manager во все двери и скрываем неактивные выходы.
	for child in _current_room.get_children():
		if child is DoorTrigger:
			child.room_manager = self
			child.visible = data.exits.has(child.direction)
			child.monitoring = data.exits.has(child.direction)

	# Спавним врагов.
	_spawn_enemies(data)

	# Ставим игрока.
	if player != null and entered_from != "":
		var opposite: String = DungeonGenerator.OPPOSITE.get(entered_from, "")
		var spawn_offset: Vector2 = SPAWN_OFFSETS.get(opposite, Vector2.ZERO)
		player.global_position = _current_room.global_position + spawn_offset

	room_changed.emit(grid_pos, data)


## Вызывается дверью при касании игрока.
func on_door_entered(direction: String) -> void:
	var dir_vec: Vector2i = _dir_to_vec(direction)
	var next_pos: Vector2i = _current_pos + dir_vec
	if not _layout.has(next_pos):
		return
	_load_room(next_pos, direction)


func _spawn_enemies(data: RoomData) -> void:
	if data.max_enemies <= 0 or enemy_scene == null or _current_room == null:
		return

	# Ищем SpawnPoints в комнате.
	var spawn_points: Array[Node] = []
	for child in _current_room.get_children():
		if child.is_in_group("spawn_point"):
			spawn_points.append(child)

	if spawn_points.is_empty():
		return

	spawn_points.shuffle()
	var count: int = mini(data.max_enemies, spawn_points.size())
	for i in range(count):
		var enemy: Node = enemy_scene.instantiate()
		_current_room.add_child(enemy)
		enemy.global_position = spawn_points[i].global_position

		# Подключаем к LevelXPSystem если есть.
		var level_xp := get_tree().get_first_node_in_group("level_xp") as LevelXPSystem
		if level_xp != null and enemy is BaseEnemy:
			level_xp.connect_enemy(enemy)


func _dir_to_vec(dir: String) -> Vector2i:
	match dir:
		"north": return Vector2i(0, -1)
		"south": return Vector2i(0,  1)
		"west":  return Vector2i(-1, 0)
		"east":  return Vector2i( 1, 0)
	return Vector2i(0, 0)
