class_name DungeonMap
extends CanvasLayer

## Полноэкранная карта данжа с туманом войны.
## Открывается/закрывается клавишей M.
## Туман раскрывается по мере посещения тайлов.

const TILE       := FloorGenerator.TILE
const T_FLOOR    := FloorGenerator.T_FLOOR
const VIS_RADIUS := 4            ## радиус видимости в тайлах вокруг игрока
const MAP_PAD    := 60.0         ## отступ карты от края экрана
const MIN_CELL   := 5.0          ## минимальный размер тайла на карте (px)
const MAX_CELL   := 12.0         ## максимальный размер тайла на карте (px)

# Цвета карты
const C_BG         := Color(0.04, 0.03, 0.06, 0.92)
const C_FLOOR      := Color(0.65, 0.62, 0.75)
const C_FLOOR_DIM  := Color(0.25, 0.23, 0.30)   ## видели, но давно (не используется пока)
const C_WALL       := Color(0.18, 0.15, 0.22)
const C_PLAYER     := Color(0.95, 0.85, 0.2)
const C_BORDER     := Color(0.40, 0.35, 0.55)

## Туман войны: { floor_num: { "x,y": true } }
var _visited: Dictionary = {}
## Открыта ли карта сейчас.
var _is_open: bool = false
## Нода рисования.
var _canvas: _MapCanvas

## Флаг: карта была открыта до паузы другим источником (PauseMenu и т.п.)
var _was_already_paused: bool = false


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Регистрируем action если не задан в project.godot
	if not InputMap.has_action("toggle_map"):
		InputMap.add_action("toggle_map")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_M
		InputMap.action_add_event("toggle_map", ev)

	_canvas = _MapCanvas.new()
	_canvas.map_node = self
	add_child(_canvas)
	_canvas.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"):
		if _is_open:
			_close()
		else:
			_open()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _is_open:
		_update_fog()
	else:
		_canvas.queue_redraw()


# ---------------------------------------------------------------------------
# Туман войны
# ---------------------------------------------------------------------------

func _update_fog() -> void:
	var fm := _get_floor_manager()
	if fm == null:
		return
	var floor_num: int = fm.get_current_floor()
	var layout: FloorGenerator.FloorLayout = fm.get_layout()
	if layout == null:
		return
	var player := _get_player()
	if player == null:
		return

	var player_tile := Vector2i(
		int(player.global_position.x / TILE),
		int(player.global_position.y / TILE)
	)

	if not _visited.has(floor_num):
		_visited[floor_num] = {}

	var visited_floor: Dictionary = _visited[floor_num]
	for dx: int in range(-VIS_RADIUS, VIS_RADIUS + 1):
		for dy: int in range(-VIS_RADIUS, VIS_RADIUS + 1):
			var tx: int = player_tile.x + dx
			var ty: int = player_tile.y + dy
			if layout.get_tile(tx, ty) == T_FLOOR:
				visited_floor["%d,%d" % [tx, ty]] = true


# ---------------------------------------------------------------------------
# Открытие / закрытие
# ---------------------------------------------------------------------------

func _open() -> void:
	_is_open = true
	_was_already_paused = get_tree().paused
	if not _was_already_paused:
		get_tree().paused = true
	_canvas.show()
	_canvas.queue_redraw()


func _close() -> void:
	_is_open = false
	if not _was_already_paused:
		get_tree().paused = false
	_canvas.hide()


# ---------------------------------------------------------------------------
# Вспомогательные
# ---------------------------------------------------------------------------

func _get_floor_manager() -> Node:
	var nodes := get_tree().get_nodes_in_group("floor_manager")
	return nodes[0] if nodes.size() > 0 else null


func _get_player() -> Node2D:
	var nodes := get_tree().get_nodes_in_group("player")
	return nodes[0] as Node2D if nodes.size() > 0 else null


# ---------------------------------------------------------------------------
# Внутренний класс рисования
# ---------------------------------------------------------------------------

class _MapCanvas extends Control:
	var map_node: DungeonMap

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if map_node == null:
			return
		var fm := map_node._get_floor_manager()
		if fm == null:
			return
		var floor_num: int = fm.get_current_floor()
		var layout: FloorGenerator.FloorLayout = fm.get_layout()
		if layout == null:
			return
		var visited_floor: Dictionary = map_node._visited.get(floor_num, {})
		var player := map_node._get_player()

		var vp_size: Vector2 = get_viewport_rect().size
		var pad := DungeonMap.MAP_PAD

		# Вычисляем размер тайла чтобы карта вписалась в экран
		var cell_w: float = (vp_size.x - pad * 2.0) / float(layout.width)
		var cell_h: float = (vp_size.y - pad * 2.0) / float(layout.height)
		var cell: float = clampf(minf(cell_w, cell_h),
				DungeonMap.MIN_CELL, DungeonMap.MAX_CELL)

		var map_w: float = cell * layout.width
		var map_h: float = cell * layout.height
		var origin := Vector2(
			(vp_size.x - map_w) * 0.5,
			(vp_size.y - map_h) * 0.5
		)

		# Фон
		draw_rect(Rect2(Vector2.ZERO, vp_size), DungeonMap.C_BG)

		# Рамка карты
		draw_rect(Rect2(origin - Vector2(2, 2), Vector2(map_w + 4, map_h + 4)),
				DungeonMap.C_BORDER, false, 1.5)

		# Тайлы
		for y: int in range(layout.height):
			for x: int in range(layout.width):
				var key: String = "%d,%d" % [x, y]
				var is_visited: bool = visited_floor.has(key)
				if not is_visited:
					continue
				var tile_type: int = layout.get_tile(x, y)
				var color: Color = DungeonMap.C_FLOOR if tile_type == T_FLOOR \
						else DungeonMap.C_WALL
				var rect := Rect2(
					origin + Vector2(x, y) * cell,
					Vector2(cell - 0.5, cell - 0.5)
				)
				draw_rect(rect, color)

		# Позиция игрока
		if player != null:
			var pt := Vector2i(
				int(player.global_position.x / DungeonMap.TILE),
				int(player.global_position.y / DungeonMap.TILE)
			)
			var player_screen := origin + Vector2(pt.x + 0.5, pt.y + 0.5) * cell
			draw_circle(player_screen, maxf(cell * 0.6, 3.0), DungeonMap.C_PLAYER)

		# Заголовок
		var font := ThemeDB.fallback_font
		var font_size: int = 14
		draw_string(font, Vector2(origin.x, origin.y - 10.0),
				"Этаж %d  [M] — закрыть" % floor_num,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DungeonMap.C_BORDER)
