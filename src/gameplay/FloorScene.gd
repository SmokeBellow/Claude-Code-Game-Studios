class_name FloorScene
extends Node2D

## Рендерит один этаж данжа: тайлмап, коллизии, навигацию, врагов, порталы.
## Создаётся и настраивается FloorManager.

const TILE    := FloorGenerator.TILE
const T_FLOOR := FloorGenerator.T_FLOOR
const T_WALL  := FloorGenerator.T_WALL

const FLOOR_COLORS: Array[Color] = [
	Color(0.20, 0.22, 0.28),   # этаж 1
	Color(0.22, 0.16, 0.28),   # этаж 2
	Color(0.28, 0.14, 0.14),   # этаж 3
]
const WALL_COLOR := Color(0.11, 0.10, 0.09)

## Сцены врагов — выставляются FloorManager до setup()
var melee_scene:  PackedScene
var ranged_scene: PackedScene
var elite_scene:  PackedScene
var boss_scene:   PackedScene

## Испускается когда все стражи убиты (только этаж 3)
signal all_guardians_died

var _layout: FloorGenerator.FloorLayout
var _floor_index: int = 1
var _guardian_alive: int = 0
var _boss_gate: BossGate = null
var _boss_room_center: Vector2 = Vector2.ZERO


## Вызывается FloorManager. Строит тайлмап, коллизии, навигацию.
func setup(layout: FloorGenerator.FloorLayout, floor_index: int) -> void:
	_layout = layout
	_floor_index = floor_index
	_build_tilemap()
	_build_collision()
	_build_lighting()
	_build_nav()
	_setup_camera()


## Спавнит всё динамическое. Вызывается deferred из FloorManager.
func spawn_entities() -> void:
	_spawn_enemies()
	_spawn_portals()
	_spawn_chests()
	_spawn_dungeon_exit()
	if _floor_index == 3:
		_spawn_boss_gate()
	_spawn_torches()


## Мировая позиция входа (для размещения игрока).
func entry_world_pos() -> Vector2:
	return _layout.world_center(_layout.entry_tile)


# ---------------------------------------------------------------------------
# Тайлмап
# ---------------------------------------------------------------------------

func _build_tilemap() -> void:
	var floor_color := FLOOR_COLORS[clampi(_floor_index - 1, 0, 2)]

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var img := Image.create(TILE * 2, TILE, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0,    0, TILE, TILE), floor_color)
	img.fill_rect(Rect2i(TILE, 0, TILE, TILE), WALL_COLOR)
	var tex := ImageTexture.create_from_image(img)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	src.create_tile(Vector2i(0, 0))
	src.create_tile(Vector2i(1, 0))
	var src_id := ts.add_source(src)

	var tml := TileMapLayer.new()
	tml.name = "TileMapLayer"
	tml.z_index = -1
	tml.tile_set = ts
	add_child(tml)

	for x in range(_layout.width):
		for y in range(_layout.height):
			if _layout.get_tile(x, y) == T_FLOOR:
				tml.set_cell(Vector2i(x, y), src_id, Vector2i(0, 0))
			elif _has_floor_neighbor(x, y):
				tml.set_cell(Vector2i(x, y), src_id, Vector2i(1, 0))


func _has_floor_neighbor(x: int, y: int) -> bool:
	for d: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		if _layout.get_tile(x + d.x, y + d.y) == T_FLOOR:
			return true
	return false


# ---------------------------------------------------------------------------
# Коллизия (горизонтальные слияния стеновых тайлов)
# ---------------------------------------------------------------------------

func _build_collision() -> void:
	for y in range(_layout.height):
		var run_x := -1
		for x in range(_layout.width + 1):
			var is_wall_border := (
				x < _layout.width
				and _layout.get_tile(x, y) == T_WALL
				and _has_floor_neighbor(x, y)
			)
			if is_wall_border:
				if run_x == -1:
					run_x = x
			else:
				if run_x != -1:
					_add_wall_body(run_x, y, x - run_x, 1)
					run_x = -1


func _build_lighting() -> void:
	if _floor_index == 3:
		return
	var mod := CanvasModulate.new()
	mod.color = Color(0.03, 0.02, 0.05)
	add_child(mod)
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		var light := player.get_node_or_null("TorchLight") as PointLight2D
		if light != null:
			light.enabled = true


func _add_wall_body(tx: int, ty: int, tw: int, th: int) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2((tx + tw * 0.5) * TILE, (ty + th * 0.5) * TILE)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(tw * TILE, th * TILE)
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	var wx0 := float(tx * TILE)
	var wy0 := float(ty * TILE)
	var wx1 := float((tx + tw) * TILE)
	var wy1 := float((ty + th) * TILE)
	poly.polygon = PackedVector2Array([
		Vector2(wx0, wy0), Vector2(wx1, wy0),
		Vector2(wx1, wy1), Vector2(wx0, wy1)
	])
	occ.occluder = poly
	add_child(occ)


# ---------------------------------------------------------------------------
# Навигация (один NavigationRegion2D на каждый rect из layout.nav_rects)
# ---------------------------------------------------------------------------

func _build_nav() -> void:
	for tile_rect: Rect2i in _layout.nav_rects:
		var x0 := float(tile_rect.position.x * TILE)
		var y0 := float(tile_rect.position.y * TILE)
		var x1 := float((tile_rect.position.x + tile_rect.size.x) * TILE)
		var y1 := float((tile_rect.position.y + tile_rect.size.y) * TILE)

		var nav := NavigationRegion2D.new()
		nav.navigation_layers = 1
		var poly := NavigationPolygon.new()
		poly.vertices = PackedVector2Array([
			Vector2(x0, y0), Vector2(x1, y0),
			Vector2(x1, y1), Vector2(x0, y1),
		])
		poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))
		nav.navigation_polygon = poly
		add_child(nav)


# ---------------------------------------------------------------------------
# Камера
# ---------------------------------------------------------------------------

func _setup_camera() -> void:
	var cam := get_tree().get_first_node_in_group("game_camera")
	if cam == null or not cam is Camera2D:
		return
	cam.limit_left   = 0
	cam.limit_top    = 0
	cam.limit_right  = _layout.width  * TILE
	cam.limit_bottom = _layout.height * TILE


# ---------------------------------------------------------------------------
# Спавн врагов
# ---------------------------------------------------------------------------

func _spawn_enemies() -> void:
	var main := get_tree().get_first_node_in_group("main")
	for group in _layout.spawn_groups:
		var rect: Rect2i = group["rect"]
		var etype: String = group["type"]
		var cnt: int = group["count"]
		for _i in range(cnt):
			var scene := _pick_scene(etype)
			if scene == null:
				continue
			var enemy: Node = scene.instantiate()
			# Случайная позиция внутри комнаты (отступ 1 тайл от края)
			var tx := rect.position.x + 1 + randi() % maxi(rect.size.x - 2, 1)
			var ty := rect.position.y + 1 + randi() % maxi(rect.size.y - 2, 1)
			enemy.position = Vector2((tx + 0.5) * TILE, (ty + 0.5) * TILE)
			add_child(enemy)
			if _floor_index == 3 and etype == "elite":
				_guardian_alive += 1
				if enemy is BaseEnemy:
					(enemy as BaseEnemy).enemy_died.connect(_on_guardian_died)
			if _floor_index == 3 and etype == "boss":
				_boss_room_center = Vector2(
					(rect.position.x + rect.size.x / 2.0) * TILE,
					(rect.position.y + rect.size.y / 2.0) * TILE
				)
				if enemy is BaseEnemy:
					(enemy as BaseEnemy).enemy_died.connect(_on_boss_died)
			if main != null and main.has_method("wire_enemy"):
				main.wire_enemy(enemy)


func _on_boss_died(_xp: int, _data: EnemyData) -> void:
	var exit := DungeonExit.new()
	exit.position = _boss_room_center
	add_child(exit)


func _on_guardian_died(_xp: int, _data: EnemyData) -> void:
	_guardian_alive -= 1
	if _guardian_alive <= 0:
		all_guardians_died.emit()


func _pick_scene(etype: String) -> PackedScene:
	match etype:
		"normal":
			var pool: Array[PackedScene] = []
			if melee_scene  != null: pool.append(melee_scene)
			if ranged_scene != null: pool.append(ranged_scene)
			if pool.is_empty(): return null
			return pool[randi() % pool.size()]
		"elite": return elite_scene
		"boss":  return boss_scene
	return null


# ---------------------------------------------------------------------------
# Порталы, сундуки, выход, ворота босса
# ---------------------------------------------------------------------------

func _spawn_portals() -> void:
	if _layout.portal_tile.x < 0:
		return
	var portal := FloorPortal.new()
	portal.target_floor = _floor_index + 1
	portal.position = _layout.world_center(_layout.portal_tile)
	add_child(portal)


func _spawn_chests() -> void:
	for ct: Vector2i in _layout.chest_tiles:
		var chest := FloorChest.new()
		# Этаж 2 — более ценный сундук
		chest.gold_reward = 120 if _floor_index == 2 else 60
		chest.position = _layout.world_center(ct)
		add_child(chest)


func _spawn_dungeon_exit() -> void:
	# Только на первом этаже: портал возврата в город рядом со входом
	if _floor_index != 1:
		return
	var de := DungeonExit.new()
	de.position = _layout.world_center(_layout.entry_tile) + Vector2(-80, 0)
	add_child(de)


func _spawn_boss_gate() -> void:
	_boss_gate = BossGate.new()
	var gr := _layout.gate_rect
	_boss_gate.gate_width  = gr.size.x * TILE
	_boss_gate.gate_height = gr.size.y * TILE
	_boss_gate.position = Vector2(gr.position.x * TILE, gr.position.y * TILE)
	add_child(_boss_gate)
	all_guardians_died.connect(_boss_gate.open)


func _spawn_torches() -> void:
	if _floor_index == 3:
		return
	# Вход — 2 факела
	var ep := _layout.world_center(_layout.entry_tile)
	_place_torch(ep + Vector2(TILE * 2.5, 0.0))
	_place_torch(ep + Vector2(-TILE * 2.5, 0.0))

	# Портал — 2 факела
	if _layout.portal_tile.x >= 0:
		var pp := _layout.world_center(_layout.portal_tile)
		_place_torch(pp + Vector2(TILE * 2.5, 0.0))
		_place_torch(pp + Vector2(-TILE * 2.5, 0.0))

	# Сундуки — 1 факел рядом
	for ct: Vector2i in _layout.chest_tiles:
		_place_torch(_layout.world_center(ct) + Vector2(TILE * 2.0, 0.0))

	# Этаж 3: стражники и ворота
	if _floor_index == 3 and _layout.guardian_rect.size.x > 0:
		var gr := _layout.guardian_rect
		var gp := Vector2(
			(gr.position.x + gr.size.x / 2.0) * TILE,
			(gr.position.y + gr.size.y / 2.0) * TILE
		)
		_place_torch(gp + Vector2(TILE * 2.5, 0.0))
		_place_torch(gp + Vector2(-TILE * 2.5, 0.0))


func _place_torch(world_pos: Vector2) -> void:
	# Привязка к ближайшему пограничному тайлу стены в радиусе 2 тайлов
	var tx := int(world_pos.x / TILE)
	var ty := int(world_pos.y / TILE)
	var snapped := world_pos
	for radius in range(1, 3):
		var found := false
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var nx := tx + dx
				var ny := ty + dy
				if _layout.get_tile(nx, ny) == T_WALL and _has_floor_neighbor(nx, ny):
					snapped = Vector2((nx + 0.5) * TILE, (ny + 0.5) * TILE)
					found = true
					break
			if found:
				break
		if found:
			break
	var torch := WallTorch.new()
	torch.position = snapped
	add_child(torch)
