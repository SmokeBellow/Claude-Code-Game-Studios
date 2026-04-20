class_name StaticFloorData
extends RefCounted

## Статичные (всегда одинаковые) планировки трёх этажей данжа.
## Заменяет случайную генерацию FloorGenerator для воспроизводимого лабиринта.
##
## Этаж 1: 7 комнат, 3×3 сетка, обычные враги.
## Этаж 2: 6 комнат, 4×3 сетка, элитные враги.
## Этаж 3: прихожая → стражи → ворота → босс (без изменений).

const _ROOM := FloorGenerator.ROOM_T   ## 13 тайлов — сторона комнаты
const _CORR := FloorGenerator.CORR_T   ## 4 тайла  — ширина коридора
const _STEP := FloorGenerator.STEP     ## 17 тайлов — шаг сетки
const _BORD := FloorGenerator.BORDER   ## 1 тайл   — граница карты
const _F    := FloorGenerator.T_FLOOR
const _W    := FloorGenerator.T_WALL


# ---------------------------------------------------------------------------
# Этаж 1
# ---------------------------------------------------------------------------

## Сетка 3×3, 7 комнат:
##
##   (0,0)@ ─── (1,0) ─── (2,0)$
##               │
##   (0,1)   ─── (1,1) ─── (2,1)
##               │
##            (1,2)>
##
## @ = вход, > = портал, $ = сундук, без метки = враги (обычные)
static func floor_1() -> FloorGenerator.FloorLayout:
	const GC := 3; const GR := 3
	var lay := _make(GC, GR)

	var cells: Array[Vector2i] = [
		Vector2i(0,0), Vector2i(1,0), Vector2i(2,0),
		Vector2i(0,1), Vector2i(1,1), Vector2i(2,1),
		Vector2i(1,2),
	]
	var srects := _fill_rooms(lay, cells)

	_corridors(lay, [
		[0,0,"h"], [1,0,"h"],   # строка 0: (0,0)─(1,0)─(2,0)
		[0,1,"h"], [1,1,"h"],   # строка 1: (0,1)─(1,1)─(2,1)
		[1,0,"v"], [1,1,"v"],   # столбец 1: (1,0)─(1,1)─(1,2)
	])

	lay.entry_tile  = _center(0, 0)
	lay.portal_tile = _center(1, 2)
	lay.chest_tiles = [_center(2, 0)]

	for rc: Vector2i in [Vector2i(1,0), Vector2i(0,1), Vector2i(1,1), Vector2i(2,1)]:
		lay.spawn_groups.append({"rect": srects[rc], "type": "normal", "count": 2})

	return lay


# ---------------------------------------------------------------------------
# Этаж 2
# ---------------------------------------------------------------------------

## Сетка 4×3, 6 комнат:
##
##   (0,0)@ ─── (1,0)E ─── (2,0)E ─── (3,0)>
##               │
##            (1,1)E
##               │
##            (1,2)$
##
## @ = вход, > = портал, $ = сундук, E = элитный враг
static func floor_2() -> FloorGenerator.FloorLayout:
	const GC := 4; const GR := 3
	var lay := _make(GC, GR)

	var cells: Array[Vector2i] = [
		Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(3,0),
		Vector2i(1,1),
		Vector2i(1,2),
	]
	var srects := _fill_rooms(lay, cells)

	_corridors(lay, [
		[0,0,"h"], [1,0,"h"], [2,0,"h"],   # верхний ряд
		[1,0,"v"], [1,1,"v"],              # вертикальная ветка
	])

	lay.entry_tile  = _center(0, 0)
	lay.portal_tile = _center(3, 0)
	lay.chest_tiles = [_center(1, 2)]

	for rc: Vector2i in [Vector2i(1,0), Vector2i(2,0), Vector2i(1,1)]:
		lay.spawn_groups.append({"rect": srects[rc], "type": "elite", "count": 2})

	return lay


# ---------------------------------------------------------------------------
# Этаж 3 — без изменений
# ---------------------------------------------------------------------------

## Прихожая → стражи → ворота → босс (логика в FloorGenerator._gen_floor_3).
static func floor_3() -> FloorGenerator.FloorLayout:
	return FloorGenerator.generate_floor_3()


# ---------------------------------------------------------------------------
# Приватные хелперы
# ---------------------------------------------------------------------------

## Создаёт пустой FloorLayout нужного размера для сетки GC×GR комнат.
static func _make(gc_count: int, gr_count: int) -> FloorGenerator.FloorLayout:
	var w := _BORD + gc_count * _ROOM + (gc_count - 1) * _CORR + _BORD
	var h := _BORD + gr_count * _ROOM + (gr_count - 1) * _CORR + _BORD
	var lay := FloorGenerator.FloorLayout.new()
	lay.init(w, h)
	return lay


## Заполняет тайлы всех переданных комнат. Возвращает словарь Vector2i→Rect2i спавн-зон.
static func _fill_rooms(lay: FloorGenerator.FloorLayout,
		cells: Array[Vector2i]) -> Dictionary:
	var srects: Dictionary = {}
	for rc: Vector2i in cells:
		var r := _room_rect(rc.x, rc.y)
		lay.fill_rect_tiles(r, _F)
		lay.nav_rects.append(r)
		# Спавн-зона — 1 тайл отступа от стен
		srects[rc] = Rect2i(r.position + Vector2i(1, 1), r.size - Vector2i(2, 2))
	return srects


## Добавляет коридоры. Каждый элемент specs: [gc, gr, "h"|"v"].
static func _corridors(lay: FloorGenerator.FloorLayout, specs: Array) -> void:
	for s: Array in specs:
		var gc: int    = s[0]
		var gr: int    = s[1]
		var dir: String = s[2]
		var cr: Rect2i
		if dir == "h":
			cr = Rect2i(
				_BORD + gc * _STEP + _ROOM,
				_BORD + gr * _STEP + _ROOM / 2 - _CORR / 2,
				_CORR, _CORR
			)
		else:
			cr = Rect2i(
				_BORD + gc * _STEP + _ROOM / 2 - _CORR / 2,
				_BORD + gr * _STEP + _ROOM,
				_CORR, _CORR
			)
		lay.fill_rect_tiles(cr, _F)
		lay.nav_rects.append(cr)


## Тайловый прямоугольник комнаты (gc, gr).
static func _room_rect(gc: int, gr: int) -> Rect2i:
	return Rect2i(_BORD + gc * _STEP, _BORD + gr * _STEP, _ROOM, _ROOM)


## Центральный тайл комнаты (gc, gr) — используется как entry/portal/chest.
static func _center(gc: int, gr: int) -> Vector2i:
	return _room_rect(gc, gr).get_center()
