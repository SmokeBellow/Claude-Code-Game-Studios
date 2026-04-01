class_name Room
extends Node2D

## Комната данжа.
## TileMapLayer — визуальный слой.
## StaticBody2D — физические стены.
## NavigationRegion2D — навигация врагов.

const TILE := 20
const COLS := 80   # 1600 / 20  (шире viewport 1280 → камера может двигаться)
const ROWS := 50   # 1000 / 20  (выше viewport 720  → камера может двигаться)

## Дверные проёмы в пикселях (5 тайлов = 100px, центрированы)
const DOOR_X0 := 760.0   # col 38
const DOOR_X1 := 860.0   # col 43 (не включая)
const DOOR_Y0 := 440.0   # row 22
const DOOR_Y1 := 540.0   # row 27 (не включая)

## Индексы тайлов в атласе
const ATLAS_FLOOR := Vector2i(0, 0)
const ATLAS_WALL  := Vector2i(1, 0)

## Цвета пола
const _FLOOR_COLORS := {
	RoomData.RoomType.START:  Color(0.18, 0.28, 0.20),
	RoomData.RoomType.NORMAL: Color(0.20, 0.22, 0.28),
	RoomData.RoomType.ELITE:  Color(0.22, 0.16, 0.28),
	RoomData.RoomType.BOSS:   Color(0.28, 0.14, 0.14),
}
const WALL_COLOR := Color(0.11, 0.10, 0.09)

## Формы комнат
const SHAPE_RECT       := 0
const SHAPE_L_BR       := 1   ## L: вырезан правый нижний угол (cols≥40, rows≥22)
const SHAPE_L_BL       := 2   ## L: вырезан левый нижний угол  (cols<24,  rows≥22)
const SHAPE_L_TR       := 3   ## L: вырезан правый верхний угол (cols≥40, rows<14)
const SHAPE_L_TL       := 4   ## L: вырезан левый верхний угол  (cols<24,  rows<14)
const SHAPE_CORRIDOR_V := 5   ## Верт. коридор: top+bottom chamber (только N/S exits)
const SHAPE_CORRIDOR_H := 6   ## Гориз. коридор: left+right chamber (только E/W exits)

## Размер вырезаемого угла для L-форм (в тайлах)
const _L_CUT_C := 27   # cols  53-79 (x ≥ 1060) или cols 0-26 (x < 540)
const _L_CUT_R := 16   # rows 34-49 (y ≥ 680) или rows 0-15 (y < 320)

## CORRIDOR_V: строки зазора и столбцы коридора
const _CV_R0 := 22;  const _CV_R1 := 27   # совпадают с W/E дверными строками
const _CV_C0 := 34;  const _CV_C1 := 46

## CORRIDOR_H: столбцы зазора и строки коридора
const _CH_C0 := 28;  const _CH_C1 := 52
const _CH_R0 := 22;  const _CH_R1 := 27

var _shape := SHAPE_RECT


func setup(room_data: RoomData, _manager: RoomManager) -> void:
	_shape = room_data.room_shape
	var exits := room_data.exits
	var fc: Color = _FLOOR_COLORS.get(room_data.room_type,
			_FLOOR_COLORS[RoomData.RoomType.NORMAL])
	_build_tilemap(fc, exits)
	_build_walls(exits)
	_build_nav()
	_setup_camera()


## Является ли тайл (c, r) проходимым полом для данной формы.
func is_floor_tile(c: int, r: int) -> bool:
	match _shape:
		SHAPE_L_BR:
			if c >= COLS - _L_CUT_C and r >= ROWS - _L_CUT_R: return false
		SHAPE_L_BL:
			if c < _L_CUT_C and r >= ROWS - _L_CUT_R: return false
		SHAPE_L_TR:
			if c >= COLS - _L_CUT_C and r < _L_CUT_R: return false
		SHAPE_L_TL:
			if c < _L_CUT_C and r < _L_CUT_R: return false
		SHAPE_CORRIDOR_V:
			if r >= _CV_R0 and r <= _CV_R1:
				if c < _CV_C0 or c > _CV_C1: return false
		SHAPE_CORRIDOR_H:
			if c >= _CH_C0 and c <= _CH_C1:
				if r < _CH_R0 or r > _CH_R1: return false
	return true


## Проверяет, находится ли мировая позиция на проходимом тайле (не стена, не пустота).
func is_walkable_pos(world_pos: Vector2) -> bool:
	var c := int(world_pos.x / TILE)
	var r := int(world_pos.y / TILE)
	if c <= 0 or c >= COLS - 1 or r <= 0 or r >= ROWS - 1:
		return false
	return is_floor_tile(c, r)


# ---------------------------------------------------------------------------
# Тайлмап (визуальный)
# ---------------------------------------------------------------------------

func _build_tilemap(floor_color: Color, exits: Array[String]) -> void:
	var tml := TileMapLayer.new()
	tml.name = "TileMapLayer"
	tml.z_index = -1
	tml.tile_set = _make_tileset(floor_color)
	add_child(tml)

	# Пол
	for c in range(COLS):
		for r in range(ROWS):
			if is_floor_tile(c, r):
				tml.set_cell(Vector2i(c, r), 0, ATLAS_FLOOR)

	# Периметровые стены (только там, где есть пол)
	for c in range(COLS):
		if is_floor_tile(c, 0):
			if not (exits.has("north") and c >= 38 and c <= 42):
				tml.set_cell(Vector2i(c, 0), 0, ATLAS_WALL)
		if is_floor_tile(c, ROWS - 1):
			if not (exits.has("south") and c >= 38 and c <= 42):
				tml.set_cell(Vector2i(c, ROWS - 1), 0, ATLAS_WALL)
	for r in range(ROWS):
		if is_floor_tile(0, r):
			if not (exits.has("west") and r >= 22 and r <= 26):
				tml.set_cell(Vector2i(0, r), 0, ATLAS_WALL)
		if is_floor_tile(COLS - 1, r):
			if not (exits.has("east") and r >= 22 and r <= 26):
				tml.set_cell(Vector2i(COLS - 1, r), 0, ATLAS_WALL)

	# Внутренние стены на границе пол/пустота (только для сложных форм)
	if _shape != SHAPE_RECT:
		for c in range(1, COLS - 1):
			for r in range(1, ROWS - 1):
				if is_floor_tile(c, r):
					continue
				if _has_floor_neighbor(c, r):
					tml.set_cell(Vector2i(c, r), 0, ATLAS_WALL)


func _has_floor_neighbor(c: int, r: int) -> bool:
	for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var nc: int = c + d.x
		var nr: int = r + d.y
		if nc >= 0 and nc < COLS and nr >= 0 and nr < ROWS:
			if is_floor_tile(nc, nr):
				return true
	return false


func _make_tileset(floor_color: Color) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var img := Image.create(TILE * 2, TILE, false, Image.FORMAT_RGBA8)
	for x in range(TILE):
		for y in range(TILE):
			img.set_pixel(x, y, floor_color)
	for x in range(TILE, TILE * 2):
		for y in range(TILE):
			img.set_pixel(x, y, WALL_COLOR)
	var tex := ImageTexture.create_from_image(img)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	src.create_tile(ATLAS_FLOOR)
	src.create_tile(ATLAS_WALL)
	ts.add_source(src, 0)
	return ts


# ---------------------------------------------------------------------------
# Физические стены
# ---------------------------------------------------------------------------

func _build_walls(exits: Array[String]) -> void:
	var w := float(COLS * TILE)
	var h := float(ROWS * TILE)
	var t := float(TILE)

	# Периметр с дверными проёмами
	for seg in _h_segs(exits.has("north"), 0.0, w, DOOR_X0, DOOR_X1):
		_add_wall(seg[0], 0.0, seg[1], t)
	for seg in _h_segs(exits.has("south"), 0.0, w, DOOR_X0, DOOR_X1):
		_add_wall(seg[0], h - t, seg[1], t)
	for seg in _v_segs(exits.has("west"), t, h - t, DOOR_Y0, DOOR_Y1):
		_add_wall(0.0, seg[0], t, seg[1])
	for seg in _v_segs(exits.has("east"), t, h - t, DOOR_Y0, DOOR_Y1):
		_add_wall(w - t, seg[0], t, seg[1])

	# Внутренние стены (закрываем вырезанные регионы)
	match _shape:
		SHAPE_L_BR:
			var cx := float((COLS - _L_CUT_C) * TILE)
			var cy := float((ROWS - _L_CUT_R) * TILE)
			_add_wall(cx, cy, float(_L_CUT_C * TILE), float(_L_CUT_R * TILE))
		SHAPE_L_BL:
			var cy := float((ROWS - _L_CUT_R) * TILE)
			_add_wall(0.0, cy, float(_L_CUT_C * TILE), float(_L_CUT_R * TILE))
		SHAPE_L_TR:
			var cx := float((COLS - _L_CUT_C) * TILE)
			_add_wall(cx, 0.0, float(_L_CUT_C * TILE), float(_L_CUT_R * TILE))
		SHAPE_L_TL:
			_add_wall(0.0, 0.0, float(_L_CUT_C * TILE), float(_L_CUT_R * TILE))
		SHAPE_CORRIDOR_V:
			var r0 := float(_CV_R0 * TILE)
			var rh := float((_CV_R1 - _CV_R0 + 1) * TILE)
			_add_wall(0.0, r0, float(_CV_C0 * TILE), rh)
			_add_wall(float((_CV_C1 + 1) * TILE), r0, w - float((_CV_C1 + 1) * TILE), rh)
		SHAPE_CORRIDOR_H:
			var c0 := float(_CH_C0 * TILE)
			var cw := float((_CH_C1 - _CH_C0 + 1) * TILE)
			_add_wall(c0, 0.0, cw, float(_CH_R0 * TILE))
			var ry := float((_CH_R1 + 1) * TILE)
			_add_wall(c0, ry, cw, h - ry)


func _h_segs(has_door: bool, x0: float, x1: float, d0: float, d1: float) -> Array:
	if not has_door:
		return [[x0, x1 - x0]]
	var segs: Array = []
	if d0 > x0: segs.append([x0, d0 - x0])
	if d1 < x1: segs.append([d1, x1 - d1])
	return segs


func _v_segs(has_door: bool, y0: float, y1: float, d0: float, d1: float) -> Array:
	if not has_door:
		return [[y0, y1 - y0]]
	var segs: Array = []
	if d0 > y0: segs.append([y0, d0 - y0])
	if d1 < y1: segs.append([d1, y1 - d1])
	return segs


func _add_wall(x: float, y: float, ww: float, wh: float) -> void:
	if ww <= 0.0 or wh <= 0.0:
		return
	var body := StaticBody2D.new()
	body.position = Vector2(x + ww * 0.5, y + wh * 0.5)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(ww, wh)
	col.shape = shape
	body.add_child(col)
	add_child(body)


# ---------------------------------------------------------------------------
# NavigationRegion2D
# ---------------------------------------------------------------------------

func _build_nav() -> void:
	var nav := NavigationRegion2D.new()
	nav.name = "NavRegion"
	nav.navigation_layers = 1
	add_child(nav)

	var poly := NavigationPolygon.new()
	var t := float(TILE)
	var W := float(COLS * TILE)
	var H := float(ROWS * TILE)

	match _shape:
		SHAPE_L_BR:
			var cx := float((COLS - _L_CUT_C) * TILE)
			var cy := float((ROWS - _L_CUT_R) * TILE)
			poly.vertices = PackedVector2Array([
				Vector2(t, t), Vector2(W - t, t),
				Vector2(W - t, cy), Vector2(cx, cy),
				Vector2(cx, H - t), Vector2(t, H - t),
			])
			poly.add_polygon(PackedInt32Array([0, 1, 2, 3, 4, 5]))
		SHAPE_L_BL:
			var cy := float((ROWS - _L_CUT_R) * TILE)
			poly.vertices = PackedVector2Array([
				Vector2(t, t), Vector2(W - t, t),
				Vector2(W - t, H - t), Vector2(float(_L_CUT_C * TILE), H - t),
				Vector2(float(_L_CUT_C * TILE), cy), Vector2(t, cy),
			])
			poly.add_polygon(PackedInt32Array([0, 1, 2, 3, 4, 5]))
		SHAPE_L_TR:
			var cx := float((COLS - _L_CUT_C) * TILE)
			var cy := float(_L_CUT_R * TILE)
			poly.vertices = PackedVector2Array([
				Vector2(t, t), Vector2(cx, t),
				Vector2(cx, cy), Vector2(W - t, cy),
				Vector2(W - t, H - t), Vector2(t, H - t),
			])
			poly.add_polygon(PackedInt32Array([0, 1, 2, 3, 4, 5]))
		SHAPE_L_TL:
			var cy := float(_L_CUT_R * TILE)
			poly.vertices = PackedVector2Array([
				Vector2(t, cy), Vector2(float(_L_CUT_C * TILE), cy),
				Vector2(float(_L_CUT_C * TILE), t), Vector2(W - t, t),
				Vector2(W - t, H - t), Vector2(t, H - t),
			])
			poly.add_polygon(PackedInt32Array([0, 1, 2, 3, 4, 5]))
		SHAPE_CORRIDOR_V:
			# H-образная фигура (12 вершин)
			var gr0 := float(_CV_R0 * TILE)
			var gr1 := float((_CV_R1 + 1) * TILE)
			var cc0 := float(_CV_C0 * TILE)
			var cc1 := float((_CV_C1 + 1) * TILE)
			poly.vertices = PackedVector2Array([
				Vector2(t, t),    Vector2(W - t, t),
				Vector2(W - t, gr0), Vector2(cc1, gr0),
				Vector2(cc1, gr1), Vector2(W - t, gr1),
				Vector2(W - t, H - t), Vector2(t, H - t),
				Vector2(t, gr1), Vector2(cc0, gr1),
				Vector2(cc0, gr0), Vector2(t, gr0),
			])
			poly.add_polygon(PackedInt32Array([0,1,2,3,4,5,6,7,8,9,10,11]))
		SHAPE_CORRIDOR_H:
			# H-образная фигура (12 вершин, повёрнутая)
			var gc0 := float(_CH_C0 * TILE)
			var gc1 := float((_CH_C1 + 1) * TILE)
			var cr0 := float(_CH_R0 * TILE)
			var cr1 := float((_CH_R1 + 1) * TILE)
			poly.vertices = PackedVector2Array([
				Vector2(t, t),    Vector2(gc0, t),
				Vector2(gc0, cr0), Vector2(gc1, cr0),
				Vector2(gc1, t),  Vector2(W - t, t),
				Vector2(W - t, H - t), Vector2(gc1, H - t),
				Vector2(gc1, cr1), Vector2(gc0, cr1),
				Vector2(gc0, H - t), Vector2(t, H - t),
			])
			poly.add_polygon(PackedInt32Array([0,1,2,3,4,5,6,7,8,9,10,11]))
		_:
			# SHAPE_RECT
			poly.vertices = PackedVector2Array([
				Vector2(t, t), Vector2(W - t, t),
				Vector2(W - t, H - t), Vector2(t, H - t),
			])
			poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))

	nav.navigation_polygon = poly


# ---------------------------------------------------------------------------
# Камера
# ---------------------------------------------------------------------------

func _setup_camera() -> void:
	var cam := get_tree().get_first_node_in_group("game_camera")
	if cam == null or not cam is Camera2D:
		return
	# Комната 1600×1000 > viewport 1280×720.
	# Camera2D держит VIEW в пределах комнаты → эффект Stardew Valley.
	cam.limit_left   = 0
	cam.limit_top    = 0
	cam.limit_right  = COLS * TILE   # 1600
	cam.limit_bottom = ROWS * TILE   # 1000
