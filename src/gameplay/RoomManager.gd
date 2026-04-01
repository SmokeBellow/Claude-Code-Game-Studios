class_name RoomManager
extends Node

## Управляет загрузкой/выгрузкой комнат и переходами между ними.
## Добавь как дочерний узел главной сцены.

signal room_changed(new_pos: Vector2i, room_data: RoomData)

const _DungeonExit = preload("res://src/gameplay/DungeonExit.gd")

## Количество комнат в данже (включая старт и босса).
@export var dungeon_size: int = 8
## Шаблон данных обычной комнаты.
@export var normal_room_data: RoomData
## Шаблон данных боссовой комнаты.
@export var boss_room_data: RoomData
## Шаблон данных элитной комнаты (необязателен).
@export var elite_room_data: RoomData
## Сцена врага для спавна (можно расширить до массива).
@export var enemy_scene: PackedScene
## Ссылка на игрока для перемещения при переходе.
@export var player: CharacterBody2D

# Размер комнаты (1280×720 = весь viewport).
const ROOM_SIZE: Vector2 = Vector2(1600, 1000)
const SPAWN_OFFSETS: Dictionary = {
	"north": Vector2(800,  80),
	"south": Vector2(800, 920),
	"west":  Vector2( 80, 500),
	"east":  Vector2(1520, 500),
}

## Время (секунды) до возрождения врагов после зачистки комнаты.
const RESPAWN_TIME: float = 45.0

var _layout: Dictionary = {}
var _current_pos: Vector2i = Vector2i(0, 0)
var _current_room: Node = null
var _is_transitioning: bool = false
# Враги хранятся здесь, а не внутри комнаты — для явного контроля жизненного цикла.
var _current_enemies: Array[Node] = []
# room_pos → время зачистки (Engine.get_process_frames() не годится, используем float секунды).
var _room_cleared_at: Dictionary = {}   # Vector2i → float
# room_pos → сколько врагов ещё живы в текущей загруженной комнате.
var _alive_count: int = 0

func _ready() -> void:
	add_to_group("room_manager")
	if normal_room_data == null or boss_room_data == null:
		push_error("RoomManager: заполни normal_room_data и boss_room_data")
		return
	_generate_and_load()


## Генерирует данжн и загружает стартовую комнату.
func _generate_and_load() -> void:
	_layout = DungeonGenerator.generate(dungeon_size, normal_room_data, boss_room_data, elite_room_data)
	_assign_room_shapes()
	_load_room(Vector2i(0, 0), "")


## Назначает форму комнаты исходя из набора exits.
func _assign_room_shapes() -> void:
	for pos in _layout.keys():
		var data: RoomData = _layout[pos]
		# Старт и босс — всегда прямоугольные
		if data.room_type == RoomData.RoomType.START or data.room_type == RoomData.RoomType.BOSS:
			data.room_shape = Room.SHAPE_RECT
			continue

		var exits := data.exits
		var has_n := exits.has("north")
		var has_s := exits.has("south")
		var has_w := exits.has("west")
		var has_e := exits.has("east")

		# Туннель: только N+S → вертикальный коридор (50% шанс)
		if has_n and has_s and not has_w and not has_e and randf() < 0.5:
			data.room_shape = Room.SHAPE_CORRIDOR_V
			continue

		# Туннель: только W+E → горизонтальный коридор (50% шанс)
		if has_w and has_e and not has_n and not has_s and randf() < 0.5:
			data.room_shape = Room.SHAPE_CORRIDOR_H
			continue

		# Угол: ровно 2 смежных выхода → L-форма (60% шанс)
		if exits.size() == 2 and not (has_n and has_s) and not (has_w and has_e):
			if randf() < 0.6:
				# Вырезаем угол, противоположный exits
				if has_n and has_e:      data.room_shape = Room.SHAPE_L_BL
				elif has_n and has_w:    data.room_shape = Room.SHAPE_L_BR
				elif has_s and has_e:    data.room_shape = Room.SHAPE_L_TL
				elif has_s and has_w:    data.room_shape = Room.SHAPE_L_TR
				else:                    data.room_shape = Room.SHAPE_RECT
				continue

		data.room_shape = Room.SHAPE_RECT


## Загружает комнату в позиции [param grid_pos].
## [param entered_from] — направление откуда пришёл игрок (для позиционирования).
func _load_room(grid_pos: Vector2i, entered_from: String) -> void:
	# Явно уничтожаем всех врагов текущей комнаты ПЕРЕД выгрузкой комнаты.
	# Враги — дети RoomManager, не комнаты, поэтому room.queue_free() их не затрагивает.
	for enemy in _current_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_current_enemies.clear()

	# Выгружаем текущую комнату.
	if _current_room != null:
		_current_room.hide()
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

	# Спавним врагов на следующем кадре — NavigationRegion2D успевает
	# зарегистрироваться в NavigationServer до первого pathfinding-запроса.
	_spawn_enemies.call_deferred(data)

	# Портал выхода — только в стартовой комнате.
	if grid_pos == Vector2i(0, 0):
		var exit := _DungeonExit.new()
		# Верхний левый угол, вдали от всех дверных проёмов (N: x 760-860, W: y 440-540).
		exit.position = Vector2(120.0, 200.0)
		_current_room.add_child(exit)

	# Ставим игрока.
	if player != null:
		if entered_from != "":
			# Появляемся у ПРОТИВОПОЛОЖНОЙ стены от входа (чтобы не триггерить ту же дверь).
			var opposite: String = DungeonGenerator.OPPOSITE.get(entered_from, "")
			var spawn_offset: Vector2 = SPAWN_OFFSETS.get(opposite, ROOM_SIZE * 0.5)
			player.global_position = _current_room.global_position + spawn_offset
		else:
			# Стартовая комната — центрируем.
			player.global_position = _current_room.global_position + ROOM_SIZE * 0.5

	room_changed.emit(grid_pos, data)


## Вызывается дверью при касании игрока.
func on_door_entered(direction: String) -> void:
	if _is_transitioning:
		return
	var dir_vec: Vector2i = _dir_to_vec(direction)
	var next_pos: Vector2i = _current_pos + dir_vec
	if not _layout.has(next_pos):
		return
	_is_transitioning = true
	_load_room(next_pos, direction)
	# Держим флаг ещё 2 кадра — физ. движок должен успеть «устояться»
	# прежде чем двери нового помещения смогут сработать.
	await get_tree().process_frame
	await get_tree().process_frame
	_is_transitioning = false


func _spawn_enemies(data: RoomData) -> void:
	_alive_count = 0

	if data.max_enemies <= 0 or _current_room == null:
		return

	# Комната недавно зачищена — ждём RESPAWN_TIME.
	if _room_cleared_at.has(_current_pos):
		var elapsed: float = Time.get_ticks_msec() / 1000.0 - _room_cleared_at[_current_pos]
		if elapsed < RESPAWN_TIME:
			return

	# Определяем набор сцен: per-room список или глобальная сцена.
	var scenes_to_use: Array[PackedScene] = []
	if data.enemy_scenes.size() > 0:
		scenes_to_use = data.enemy_scenes
	elif enemy_scene != null:
		scenes_to_use = [enemy_scene]
	else:
		return

	# Ищем SpawnPoints в комнате.
	var spawn_points: Array[Node] = []
	for child in _current_room.get_children():
		if child.is_in_group("spawn_point"):
			spawn_points.append(child)

	if spawn_points.is_empty():
		return

	# Фильтруем точки спавна: пропускаем те, что попали в пустоту (сложные формы)
	if _current_room.has_method("is_walkable_pos"):
		spawn_points = spawn_points.filter(func(sp: Node) -> bool:
			return _current_room.is_walkable_pos(sp.global_position))
	if spawn_points.is_empty():
		return

	spawn_points.shuffle()
	var count: int = mini(data.max_enemies, spawn_points.size())
	_alive_count = count

	var main := get_tree().get_first_node_in_group("main")
	for i in range(count):
		var scene: PackedScene = scenes_to_use[i % scenes_to_use.size()]
		var enemy: Node = scene.instantiate()
		# Позиция ДО add_child — чтобы _ready() получил правильный _start_position.
		var jitter := Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
		enemy.position = spawn_points[i].global_position + jitter
		add_child(enemy)
		_current_enemies.append(enemy)

		# Следим за гибелью — чтобы понять когда комната зачищена.
		if enemy is BaseEnemy:
			enemy.enemy_died.connect(_on_enemy_died.bind(_current_pos))

		if main != null and main.has_method("wire_enemy"):
			main.wire_enemy(enemy)


func _on_enemy_died(_xp: int, _data: EnemyData, room_pos: Vector2i) -> void:
	if room_pos != _current_pos:
		return   # Игрок уже ушёл из этой комнаты
	_alive_count -= 1
	if _alive_count <= 0:
		_room_cleared_at[room_pos] = Time.get_ticks_msec() / 1000.0
	PlayerData.notify_enemy_killed()


func _dir_to_vec(dir: String) -> Vector2i:
	match dir:
		"north": return Vector2i(0, -1)
		"south": return Vector2i(0,  1)
		"west":  return Vector2i(-1, 0)
		"east":  return Vector2i( 1, 0)
	return Vector2i(0, 0)
