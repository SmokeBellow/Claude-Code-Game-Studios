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
var _canvas_mod: CanvasModulate = null   # читкод F3 — скрыть затемнение
var _wall_mat: ShaderMaterial = null     # шейдер яркости стен по расстоянию
var _player_cache: Node2D = null


## Вызывается FloorManager. Строит тайлмап, коллизии, навигацию.
func setup(layout: FloorGenerator.FloorLayout, floor_index: int) -> void:
	_layout = layout
	_floor_index = floor_index
	_build_tilemap()
	_build_collision()
	_build_occluders()
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

	# Пол — освещается TorchLight (с тенями), базовый ambient = 2% от CanvasModulate.
	var floor_ts := TileSet.new()
	floor_ts.tile_size = Vector2i(TILE, TILE)
	var floor_src := TileSetAtlasSource.new()
	floor_src.texture = _make_solid_tex(floor_color)
	floor_src.texture_region_size = Vector2i(TILE, TILE)
	floor_src.create_tile(Vector2i(0, 0))
	floor_ts.add_source(floor_src)
	var floor_tml := TileMapLayer.new()
	floor_tml.name = "FloorTileMapLayer"
	floor_tml.z_index = -1
	floor_tml.tile_set = floor_ts
	add_child(floor_tml)

	# Стены — TorchLight не достигает их (окклюдеры), но modulate×CanvasModulate = 0.75.
	# Формула: wall_modulate = 0.75 / CanvasModulate(0.02) = 37.5
	var wall_ts := TileSet.new()
	wall_ts.tile_size = Vector2i(TILE, TILE)
	var wall_src := TileSetAtlasSource.new()
	var wall_tex := _load_scaled_tex("res://assets/art/environment/wall_stone.png")
	wall_src.texture = wall_tex if wall_tex != null else _make_solid_tex(WALL_COLOR)
	wall_src.texture_region_size = Vector2i(TILE, TILE)
	wall_src.create_tile(Vector2i(0, 0))
	wall_ts.add_source(wall_src)
	var wall_tml := TileMapLayer.new()
	wall_tml.name = "WallTileMapLayer"
	wall_tml.z_index = -1
	wall_tml.tile_set = wall_ts

	# Шейдер: 100% яркости внутри радиуса факела, 1% снаружи.
	# Факторы компенсируют CanvasModulate=0.02: 50*0.02=1.0 и 0.5*0.02=0.01.
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec2 player_world_pos = vec2(0.0, 0.0);
uniform float light_radius : hint_range(0.0, 2000.0) = 288.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float dist = length(world_pos - player_world_pos);
	float t = clamp(dist / light_radius, 0.0, 1.0);
	float factor = mix(50.0, 0.5, t);
	COLOR = col * factor;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("light_radius", 288.0)
	wall_tml.material = mat
	_wall_mat = mat

	add_child(wall_tml)

	for x in range(_layout.width):
		for y in range(_layout.height):
			if _layout.get_tile(x, y) == T_FLOOR:
				floor_tml.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
			elif _has_floor_neighbor(x, y):
				wall_tml.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))


func _make_solid_tex(color: Color) -> ImageTexture:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _load_scaled_tex(path: String) -> ImageTexture:
	if not ResourceLoader.exists(path):
		return null
	var res: Texture2D = load(path)
	if res == null:
		return null
	var img: Image = res.get_image()
	if img == null:
		return null
	img.resize(TILE, TILE, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


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


func _process(_delta: float) -> void:
	if _wall_mat == null:
		return
	if _player_cache == null or not is_instance_valid(_player_cache):
		_player_cache = get_tree().get_first_node_in_group("player") as Node2D
	if _player_cache != null:
		_wall_mat.set_shader_parameter("player_world_pos", _player_cache.global_position)


func _build_lighting() -> void:
	var mod := CanvasModulate.new()
	# 2% ambient для пола за стенами. Стены управляются шейдером (100% / 1%) независимо.
	mod.color = Color(0.02, 0.02, 0.02)
	add_child(mod)
	_canvas_mod = mod
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


# ---------------------------------------------------------------------------
# Окклюдеры: линии на границах стена→пол (не заливка тайла, чтобы стена была видна)
# ---------------------------------------------------------------------------

func _build_occluders() -> void:
	# Собираем направленные рёбра на границе стена→пол (обход против часовой, пол слева).
	# Это гарантирует связность: рёбра соседних тайлов разделяют вершины и образуют замкнутые петли.
	var edge_map: Dictionary = {}  # Vector2 start → Vector2 end

	for y in range(_layout.height):
		for x in range(_layout.width):
			if _layout.get_tile(x, y) != T_WALL:
				continue
			var x0 := float(x * TILE)
			var y0 := float(y * TILE)
			var x1 := float((x + 1) * TILE)
			var y1 := float((y + 1) * TILE)

			# Пол снизу (y+1): ребро идёт ВЛЕВО по нижней грани стены
			if y + 1 < _layout.height and _layout.get_tile(x, y + 1) == T_FLOOR:
				edge_map[Vector2(x1, y1)] = Vector2(x0, y1)
			# Пол сверху (y-1): ребро идёт ВПРАВО по верхней грани
			if y - 1 >= 0 and _layout.get_tile(x, y - 1) == T_FLOOR:
				edge_map[Vector2(x0, y0)] = Vector2(x1, y0)
			# Пол справа (x+1): ребро идёт ВНИЗ по правой грани
			if x + 1 < _layout.width and _layout.get_tile(x + 1, y) == T_FLOOR:
				edge_map[Vector2(x1, y0)] = Vector2(x1, y1)
			# Пол слева (x-1): ребро идёт ВВЕРХ по левой грани
			if x - 1 >= 0 and _layout.get_tile(x - 1, y) == T_FLOOR:
				edge_map[Vector2(x0, y1)] = Vector2(x0, y0)

	# Обходим цепочки рёбер и формируем замкнутые полигоны
	var visited: Dictionary = {}
	for start: Vector2 in edge_map:
		if start in visited:
			continue
		var polygon: PackedVector2Array = PackedVector2Array()
		var current := start
		var guard := edge_map.size() + 1
		while current not in visited and guard > 0:
			guard -= 1
			visited[current] = true
			polygon.append(current)
			current = edge_map.get(current, start)
		if polygon.size() >= 3:
			var occ := LightOccluder2D.new()
			var poly := OccluderPolygon2D.new()
			poly.polygon = polygon
			occ.occluder = poly
			occ.occluder_light_mask = 1
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
		chest.floor_index = _floor_index
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


# ---------------------------------------------------------------------------
# Читкод: F3 — отключить/включить затемнение
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			if _canvas_mod != null:
				_canvas_mod.visible = not _canvas_mod.visible
			get_viewport().set_input_as_handled()
