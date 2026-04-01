class_name Minimap
extends Control

## Миникарта данжна. Рисует все комнаты (туман войны) и текущую позицию.
## RoomManager подключается автоматически через группу "room_manager".

var room_manager: RoomManager

# Размер одной ячейки комнаты в пикселях.
const CELL_SIZE: float = 14.0
# Отступ между ячейками.
const CELL_GAP: float = 4.0
# Отступ от края экрана.
const MARGIN: float = 10.0
# Цвета посещённых комнат.
const COLOR_CURRENT:   Color = Color(1.0, 1.0, 1.0)
const COLOR_VISITED:   Color = Color(0.55, 0.55, 0.55)
const COLOR_BOSS:      Color = Color(0.9, 0.2, 0.2)
const COLOR_START:     Color = Color(0.2, 0.8, 0.4)
const COLOR_CORRIDOR:  Color = Color(0.35, 0.35, 0.35)
# Цвета непосещённых комнат (туман войны).
const COLOR_FOG_ROOM:  Color = Color(0.18, 0.18, 0.18)
const COLOR_FOG_LINE:  Color = Color(0.14, 0.14, 0.14)
const COLOR_BG:        Color = Color(0.0, 0.0, 0.0, 0.75)

var _visited: Dictionary = {}       # Vector2i → RoomData
var _current_pos: Vector2i = Vector2i(0, 0)
var _layout: Dictionary = {}        # Vector2i → RoomData (весь граф)

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(150, 150)
	# Ждём следующего кадра — RoomManager должен успеть добавиться в группу.
	await get_tree().process_frame
	var rm := get_tree().get_first_node_in_group("room_manager") as RoomManager
	if rm != null:
		setup(rm)
	# Прижимаем к правому верхнему углу экрана.
	_reposition()


func _reposition() -> void:
	var vp := get_viewport_rect().size
	position = Vector2(vp.x - custom_minimum_size.x - MARGIN, MARGIN)


func setup(rm: RoomManager) -> void:
	room_manager = rm
	_connect_manager()


func _connect_manager() -> void:
	if room_manager.room_changed.is_connected(_on_room_changed):
		return
	room_manager.room_changed.connect(_on_room_changed)
	# Синхронизируем уже известный layout.
	_layout = room_manager._layout
	# Отмечаем стартовую комнату как посещённую.
	var start := Vector2i(0, 0)
	if _layout.has(start):
		_visited[start] = _layout[start]
		_current_pos = start
	queue_redraw()


func _on_room_changed(new_pos: Vector2i, data: RoomData) -> void:
	_current_pos = new_pos
	_visited[new_pos] = data
	queue_redraw()


func _draw() -> void:
	if _layout.is_empty():
		return

	var step: float = CELL_SIZE + CELL_GAP

	# Вычисляем общие границы всего layout.
	var min_x: int = 0
	var min_y: int = 0
	var max_x: int = 0
	var max_y: int = 0
	for pos in _layout.keys():
		min_x = mini(min_x, pos.x)
		min_y = mini(min_y, pos.y)
		max_x = maxi(max_x, pos.x)
		max_y = maxi(max_y, pos.y)

	var map_size: Vector2 = custom_minimum_size

	# Фон миникарты.
	draw_rect(Rect2(Vector2.ZERO, map_size), COLOR_BG)

	# Центрируем весь layout.
	var grid_w: float = (max_x - min_x) * step + CELL_SIZE
	var grid_h: float = (max_y - min_y) * step + CELL_SIZE
	var offset: Vector2 = Vector2(
		(map_size.x - grid_w) * 0.5 - min_x * step,
		(map_size.y - grid_h) * 0.5 - min_y * step
	)

	const DIRS: Array = [Vector2i(1, 0), Vector2i(0, 1)]

	# --- Туман войны: все коридоры ---
	for pos in _layout.keys():
		for dir in DIRS:
			var neighbor: Vector2i = pos + dir
			if not _layout.has(neighbor):
				continue
			var p1: Vector2 = offset + Vector2(pos.x * step, pos.y * step) + Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
			var p2: Vector2 = offset + Vector2(neighbor.x * step, neighbor.y * step) + Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
			draw_line(p1, p2, COLOR_FOG_LINE, 3.0)

	# --- Туман войны: все комнаты ---
	for pos in _layout.keys():
		if _visited.has(pos):
			continue
		var rect_pos: Vector2 = offset + Vector2(pos.x * step, pos.y * step)
		draw_rect(Rect2(rect_pos, Vector2(CELL_SIZE, CELL_SIZE)), COLOR_FOG_ROOM)

	# --- Посещённые: коридоры ---
	for pos in _visited.keys():
		for dir in DIRS:
			var neighbor: Vector2i = pos + dir
			if not _visited.has(neighbor):
				continue
			var p1: Vector2 = offset + Vector2(pos.x * step, pos.y * step) + Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
			var p2: Vector2 = offset + Vector2(neighbor.x * step, neighbor.y * step) + Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
			draw_line(p1, p2, COLOR_CORRIDOR, 3.0)

	# --- Посещённые: комнаты ---
	for pos in _visited.keys():
		var data: RoomData = _visited[pos]
		var rect_pos: Vector2 = offset + Vector2(pos.x * step, pos.y * step)
		var color: Color
		if pos == _current_pos:
			color = COLOR_CURRENT
		elif data.room_type == RoomData.RoomType.BOSS:
			color = COLOR_BOSS
		elif data.room_type == RoomData.RoomType.START:
			color = COLOR_START
		else:
			color = COLOR_VISITED
		draw_rect(Rect2(rect_pos, Vector2(CELL_SIZE, CELL_SIZE)), color)
