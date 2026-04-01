class_name DungeonGenerator
extends RefCounted

## Генерирует граф комнат для данжна.
## Возвращает Dictionary: ключ = Vector2i (позиция на сетке), значение = RoomData.

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),  # север
	Vector2i(0,  1),  # юг
	Vector2i(-1, 0),  # запад
	Vector2i( 1, 0),  # восток
]
const DIR_NAMES: Array[String] = ["north", "south", "west", "east"]
const OPPOSITE: Dictionary = {
	"north": "south", "south": "north",
	"west": "east",   "east": "west",
}

## Генерирует данжн с [param room_count] комнатами.
## [param normal_data] — шаблон обычной комнаты, [param boss_data] — боссовой.
## [param elite_data] — шаблон элитной комнаты (необязателен; при null — без элитных).
static func generate(room_count: int, normal_data: RoomData,
		boss_data: RoomData, elite_data: RoomData = null) -> Dictionary:
	var layout: Dictionary = {}
	var frontier: Array[Vector2i] = []

	# Стартовая комната.
	var start := Vector2i(0, 0)
	var start_data: RoomData = normal_data.duplicate()
	start_data.room_type = RoomData.RoomType.START
	start_data.max_enemies = 0
	layout[start] = start_data
	frontier.append(start)

	# Расширяем граф.
	var placed: int = 1
	while placed < room_count - 1 and frontier.size() > 0:
		var current: Vector2i = frontier.pick_random()
		var shuffled: Array[Vector2i] = DIRECTIONS.duplicate()
		shuffled.shuffle()

		for dir in shuffled:
			var neighbor: Vector2i = current + dir
			if layout.has(neighbor):
				continue
			var data: RoomData = normal_data.duplicate()
			layout[neighbor] = data
			frontier.append(neighbor)
			placed += 1
			break

	# Боссовая комната — самая далёкая от старта.
	var farthest: Vector2i = start
	var max_dist: int = 0
	for pos in layout.keys():
		var d: int = abs(pos.x) + abs(pos.y)
		if d > max_dist:
			max_dist = d
			farthest = pos
	layout[farthest] = boss_data.duplicate()
	layout[farthest].room_type = RoomData.RoomType.BOSS

	# Элитные комнаты — 1-2 обычных комнаты на дистанции ≥2 от старта.
	if elite_data != null:
		var candidates: Array[Vector2i] = []
		for pos in layout.keys():
			var dist: int = abs(pos.x) + abs(pos.y)
			if dist >= 2 and layout[pos].room_type == RoomData.RoomType.NORMAL:
				candidates.append(pos)
		candidates.shuffle()
		var elite_count: int = mini(2, candidates.size())
		for i in range(elite_count):
			layout[candidates[i]] = elite_data.duplicate()
			layout[candidates[i]].room_type = RoomData.RoomType.ELITE

	# Проставляем exits между соседними комнатами.
	for pos in layout.keys():
		var data: RoomData = layout[pos]
		data.exits = []
		for i in range(DIRECTIONS.size()):
			if layout.has(pos + DIRECTIONS[i]):
				data.exits.append(DIR_NAMES[i])

	return layout
