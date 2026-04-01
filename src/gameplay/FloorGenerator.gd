class_name FloorGenerator
extends RefCounted

## Генерирует тайловые планировки трёх этажей данжа.
## Этаж 1: DFS-лабиринт 7×5 комнат — только обычные враги.
## Этаж 2: DFS-лабиринт 5×4 комнат — элитные враги в дальних комнатах.
## Этаж 3: фиксированный — прихожая → стражи → [ворота] → босс.

const TILE    := 20   ## пикселей на тайл
const ROOM_T  := 13   ## сторона стандартной комнаты в тайлах (260×260 px)
const CORR_T  := 4    ## ширина коридора в тайлах (80 px)
const STEP    := ROOM_T + CORR_T   ## шаг сетки = 17
const BORDER  := 1    ## граничные тайлы

const T_WALL  := 0
const T_FLOOR := 1


# ---------------------------------------------------------------------------
# FloorLayout — данные планировки
# ---------------------------------------------------------------------------

class FloorLayout extends RefCounted:
	var width: int = 0
	var height: int = 0
	var tiles: PackedByteArray

	## Тайловая позиция спавна игрока
	var entry_tile: Vector2i = Vector2i.ZERO
	## Тайловая позиция портала на следующий этаж (-1,-1 = нет портала)
	var portal_tile: Vector2i = Vector2i(-1, -1)
	## Тайловые позиции центров сундуков
	var chest_tiles: Array[Vector2i] = []
	## Группы спавна: {rect:Rect2i, type:String, count:int}
	## type = "normal" | "elite" | "boss"
	var spawn_groups: Array[Dictionary] = []
	## Прямоугольники для NavigationRegion2D (тайловые)
	var nav_rects: Array[Rect2i] = []

	## Только этаж 3
	var gate_rect: Rect2i = Rect2i()
	var guardian_rect: Rect2i = Rect2i()

	func init(w: int, h: int) -> void:
		width = w; height = h
		tiles.resize(w * h)
		tiles.fill(T_WALL)

	func set_tile(x: int, y: int, v: int) -> void:
		if x >= 0 and x < width and y >= 0 and y < height:
			tiles[y * width + x] = v

	func get_tile(x: int, y: int) -> int:
		if x < 0 or x >= width or y < 0 or y >= height:
			return T_WALL
		return int(tiles[y * width + x])

	func fill_rect_tiles(rect: Rect2i, v: int) -> void:
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			for y in range(rect.position.y, rect.position.y + rect.size.y):
				set_tile(x, y, v)

	## Мировые координаты центра тайла
	func world_center(tile: Vector2i) -> Vector2:
		return Vector2((tile.x + 0.5) * TILE, (tile.y + 0.5) * TILE)

	## Мировой прямоугольник тайлового rect
	func world_rect(tile_rect: Rect2i) -> Rect2:
		return Rect2(
			Vector2(tile_rect.position.x * TILE, tile_rect.position.y * TILE),
			Vector2(tile_rect.size.x * TILE,     tile_rect.size.y * TILE)
		)


# ---------------------------------------------------------------------------
# Публичные генераторы
# ---------------------------------------------------------------------------

static func generate_floor_1() -> FloorLayout:
	return _gen_labyrinth(7, 5, "floor_1")

static func generate_floor_2() -> FloorLayout:
	return _gen_labyrinth(5, 4, "floor_2")

static func generate_floor_3() -> FloorLayout:
	return _gen_floor_3()


# ---------------------------------------------------------------------------
# DFS-лабиринт
# ---------------------------------------------------------------------------

static func _gen_labyrinth(gcols: int, grows: int, floor_id: String) -> FloorLayout:
	var w := BORDER + gcols * ROOM_T + (gcols - 1) * CORR_T + BORDER
	var h := BORDER + grows * ROOM_T + (grows - 1) * CORR_T + BORDER

	var layout := FloorLayout.new()
	layout.init(w, h)

	# Заполняем комнаты случайных форм
	var spawn_rects: Dictionary = {}
	for gc in range(gcols):
		for gr in range(grows):
			var shape := randi() % 6
			spawn_rects[Vector2i(gc, gr)] = _fill_room_shape(layout, gc, gr, shape)

	# DFS-лабиринт — получаем список коридоров
	var corridors := _dfs_maze(gcols, grows)
	for c in corridors:
		var cr: Rect2i
		if c["dir"] == "h":
			cr = _h_corr_tile_rect(c["gc"], c["gr"])
		else:
			cr = _v_corr_tile_rect(c["gc"], c["gr"])
		layout.fill_rect_tiles(cr, T_FLOOR)
		layout.nav_rects.append(cr)

	# Граф смежности и BFS
	var adj := _build_adj(corridors, gcols, grows)
	var dist := _bfs(adj, Vector2i(0, 0))

	var farthest := _farthest(dist)
	var dead_end := _pick_dead_end(adj, [Vector2i(0, 0), farthest])
	var elite_rooms: Array[Vector2i] = []
	if floor_id == "floor_2":
		elite_rooms = _rooms_near(adj, farthest, 2, [Vector2i(0, 0)])

	# Вход
	layout.entry_tile = _room_tile_rect(0, 0).get_center()
	# Портал
	layout.portal_tile = _room_tile_rect(farthest.x, farthest.y).get_center()
	# Сундук в тупике
	if dead_end != Vector2i(-1, -1):
		layout.chest_tiles = [_room_tile_rect(dead_end.x, dead_end.y).get_center()]

	# Спавн врагов (пропускаем стартовую, портальную, сундучную комнаты)
	var special: Array[Vector2i] = [Vector2i(0, 0), farthest]
	if dead_end != Vector2i(-1, -1):
		special.append(dead_end)

	for gc in range(gcols):
		for gr in range(grows):
			var cell := Vector2i(gc, gr)
			if special.has(cell):
				continue
			layout.spawn_groups.append({
				"rect":  spawn_rects[cell],
				"type":  "elite" if elite_rooms.has(cell) else "normal",
				"count": 1 + randi() % 2
			})

	return layout


# ---------------------------------------------------------------------------
# Этаж 3 (фиксированный)
# ---------------------------------------------------------------------------

static func _gen_floor_3() -> FloorLayout:
	const E_W := 12;  const E_H := 20   # прихожая
	const G_W := 16;  const G_H := 20   # стражи
	const GATE_W := 4
	const B_W := 20;  const B_H := 20   # босс
	const COR := 3
	const BORD := 1

	var total_w := BORD + E_W + COR + G_W + COR + GATE_W + COR + B_W + BORD
	var total_h := BORD + E_H + BORD

	var layout := FloorLayout.new()
	layout.init(total_w, total_h)

	var y0 := BORD
	# X-позиции зон
	var ex   := BORD
	var c1x  := ex + E_W
	var gx   := c1x + COR
	var c2x  := gx + G_W
	var gatex := c2x + COR
	var c3x  := gatex + GATE_W
	var bx   := c3x + COR

	# Высота коридора (центр по вертикали)
	var cy := y0 + E_H / 2 - COR / 2

	# Прихожая
	layout.fill_rect_tiles(Rect2i(ex, y0, E_W, E_H), T_FLOOR)
	layout.nav_rects.append(Rect2i(ex, y0, E_W, E_H))
	# Коридор → стражи
	layout.fill_rect_tiles(Rect2i(c1x, cy, COR, COR), T_FLOOR)
	layout.nav_rects.append(Rect2i(c1x, cy, COR, COR))
	# Комната стражей
	layout.fill_rect_tiles(Rect2i(gx, y0, G_W, G_H), T_FLOOR)
	layout.nav_rects.append(Rect2i(gx, y0, G_W, G_H))
	# Коридор стражи → ворота
	layout.fill_rect_tiles(Rect2i(c2x, cy, COR, COR), T_FLOOR)
	layout.nav_rects.append(Rect2i(c2x, cy, COR, COR))
	# Проход ворот (тайл-пол; коллизию перекрывает BossGate)
	layout.fill_rect_tiles(Rect2i(gatex, cy, GATE_W, COR), T_FLOOR)
	layout.nav_rects.append(Rect2i(gatex, cy, GATE_W, COR))
	# Коридор → босс
	layout.fill_rect_tiles(Rect2i(c3x, cy, COR, COR), T_FLOOR)
	layout.nav_rects.append(Rect2i(c3x, cy, COR, COR))
	# Комната босса
	layout.fill_rect_tiles(Rect2i(bx, y0, B_W, B_H), T_FLOOR)
	layout.nav_rects.append(Rect2i(bx, y0, B_W, B_H))

	layout.entry_tile  = Vector2i(ex + E_W / 2, y0 + E_H / 2)
	layout.portal_tile = Vector2i(-1, -1)
	layout.gate_rect   = Rect2i(gatex, cy, GATE_W, COR)
	layout.guardian_rect = Rect2i(gx, y0, G_W, G_H)

	layout.spawn_groups = [
		{"rect": Rect2i(gx, y0, G_W, G_H), "type": "elite", "count": 3},
		{"rect": Rect2i(bx, y0, B_W, B_H), "type": "boss",  "count": 1},
	]

	return layout


# ---------------------------------------------------------------------------
# Формы комнат
# ---------------------------------------------------------------------------

## Заполняет тайлы и nav_rects для одной комнаты заданной формы.
## Возвращает Rect2i (абс. тайловые коорд.) безопасной зоны спавна врагов.
## cm = ROOM_T/2 - CORR_T/2 = смещение коридорной полосы (= 4 при ROOM_T=13, CORR_T=4).
## Каждая форма обязательно включает крест шириной CORR_T через центр,
## чтобы коридоры со всех 4 сторон всегда упирались в пол.
static func _fill_room_shape(layout: FloorLayout, gc: int, gr: int, shape: int) -> Rect2i:
	var ox := BORDER + gc * STEP
	var oy := BORDER + gr * STEP
	var cm := ROOM_T / 2 - CORR_T / 2   # = 4

	match shape:
		0:  # Квадрат — вся клетка
			_fn(layout, Rect2i(ox, oy, ROOM_T, ROOM_T))
			return Rect2i(ox + 1, oy + 1, ROOM_T - 2, ROOM_T - 2)
		1:  # Широкий горизонтальный зал + вертикальный крест
			_fn(layout, Rect2i(ox, oy + 2, ROOM_T, 9))
			_fn(layout, Rect2i(ox + cm, oy, CORR_T, ROOM_T))
			return Rect2i(ox + 1, oy + 3, ROOM_T - 2, 7)
		2:  # Высокий вертикальный зал + горизонтальный крест
			_fn(layout, Rect2i(ox + 2, oy, 9, ROOM_T))
			_fn(layout, Rect2i(ox, oy + cm, ROOM_T, CORR_T))
			return Rect2i(ox + 3, oy + 1, 7, ROOM_T - 2)
		3:  # Плюс — широкий крест + центральная площадка
			_fn(layout, Rect2i(ox + cm, oy, CORR_T + 1, ROOM_T))
			_fn(layout, Rect2i(ox, oy + cm, ROOM_T, CORR_T + 1))
			_fn(layout, Rect2i(ox + 2, oy + 2, 9, 9))
			return Rect2i(ox + 3, oy + 3, 7, 7)
		4:  # Г-образная: большой угол вверху-слева
			_fn(layout, Rect2i(ox, oy, 10, 10))
			_fn(layout, Rect2i(ox + cm, oy, CORR_T, ROOM_T))
			_fn(layout, Rect2i(ox, oy + cm, ROOM_T, CORR_T))
			return Rect2i(ox + 1, oy + 1, 8, 8)
		5:  # Г-образная: большой угол внизу-справа
			_fn(layout, Rect2i(ox + 3, oy + 3, 10, 10))
			_fn(layout, Rect2i(ox + cm, oy, CORR_T, ROOM_T))
			_fn(layout, Rect2i(ox, oy + cm, ROOM_T, CORR_T))
			return Rect2i(ox + 4, oy + 4, 8, 8)

	# Дефолт — квадрат
	_fn(layout, Rect2i(ox, oy, ROOM_T, ROOM_T))
	return Rect2i(ox + 1, oy + 1, ROOM_T - 2, ROOM_T - 2)


## Вспомогательный: заполнить тайлы и добавить в nav_rects.
static func _fn(layout: FloorLayout, rect: Rect2i) -> void:
	layout.fill_rect_tiles(rect, T_FLOOR)
	layout.nav_rects.append(rect)


# ---------------------------------------------------------------------------
# Тайловые прямоугольники
# ---------------------------------------------------------------------------

static func _room_tile_rect(gc: int, gr: int) -> Rect2i:
	return Rect2i(BORDER + gc * STEP, BORDER + gr * STEP, ROOM_T, ROOM_T)

static func _h_corr_tile_rect(gc: int, gr: int) -> Rect2i:
	var x := BORDER + gc * STEP + ROOM_T
	var y := BORDER + gr * STEP + ROOM_T / 2 - CORR_T / 2
	return Rect2i(x, y, CORR_T, CORR_T)

static func _v_corr_tile_rect(gc: int, gr: int) -> Rect2i:
	var x := BORDER + gc * STEP + ROOM_T / 2 - CORR_T / 2
	var y := BORDER + gr * STEP + ROOM_T
	return Rect2i(x, y, CORR_T, CORR_T)


# ---------------------------------------------------------------------------
# DFS и граф
# ---------------------------------------------------------------------------

static func _dfs_maze(gcols: int, grows: int) -> Array[Dictionary]:
	var visited := PackedByteArray()
	visited.resize(gcols * grows)
	visited.fill(0)
	var corridors: Array[Dictionary] = []
	var stack: Array[Vector2i] = [Vector2i(0, 0)]
	visited[0] = 1

	while not stack.is_empty():
		var cur := stack[-1]
		var nbrs: Array[Vector2i] = []
		for d: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var nb := cur + d
			if nb.x >= 0 and nb.x < gcols and nb.y >= 0 and nb.y < grows:
				if visited[nb.y * gcols + nb.x] == 0:
					nbrs.append(nb)
		if nbrs.is_empty():
			stack.pop_back()
		else:
			var nb := nbrs[randi() % nbrs.size()]
			visited[nb.y * gcols + nb.x] = 1
			stack.append(nb)
			var diff := nb - cur
			if diff.x == 1:
				corridors.append({"gc": cur.x, "gr": cur.y, "dir": "h"})
			elif diff.x == -1:
				corridors.append({"gc": nb.x, "gr": nb.y, "dir": "h"})
			elif diff.y == 1:
				corridors.append({"gc": cur.x, "gr": cur.y, "dir": "v"})
			else:
				corridors.append({"gc": nb.x, "gr": nb.y, "dir": "v"})

	return corridors


static func _build_adj(corridors: Array[Dictionary], gcols: int, grows: int) -> Dictionary:
	var adj: Dictionary = {}
	for gc in range(gcols):
		for gr in range(grows):
			adj[Vector2i(gc, gr)] = []
	for c in corridors:
		var a := Vector2i(c["gc"], c["gr"])
		var b := a + (Vector2i(1, 0) if c["dir"] == "h" else Vector2i(0, 1))
		(adj[a] as Array).append(b)
		(adj[b] as Array).append(a)
	return adj


static func _bfs(adj: Dictionary, start: Vector2i) -> Dictionary:
	var dist: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for nb: Vector2i in adj.get(cur, []):
			if not dist.has(nb):
				dist[nb] = dist[cur] + 1
				queue.append(nb)
	return dist


static func _farthest(dist: Dictionary) -> Vector2i:
	var best := Vector2i.ZERO
	var best_d := -1
	for cell: Vector2i in dist.keys():
		if dist[cell] > best_d:
			best_d = dist[cell]
			best = cell
	return best


static func _pick_dead_end(adj: Dictionary, exclude: Array[Vector2i]) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in adj.keys():
		if exclude.has(cell):
			continue
		if (adj[cell] as Array).size() == 1:
			candidates.append(cell)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates[randi() % candidates.size()]


static func _rooms_near(adj: Dictionary, center: Vector2i, count: int, exclude: Array[Vector2i]) -> Array[Vector2i]:
	var visited: Dictionary = {center: true}
	var queue: Array[Vector2i] = [center]
	var result: Array[Vector2i] = []
	while not queue.is_empty() and result.size() < count:
		var cur: Vector2i = queue.pop_front()
		if cur != center and not exclude.has(cur):
			result.append(cur)
		for nb: Vector2i in adj.get(cur, []):
			if not visited.has(nb):
				visited[nb] = true
				queue.append(nb)
	return result
