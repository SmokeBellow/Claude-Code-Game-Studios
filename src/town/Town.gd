class_name Town
extends Node2D

## Главный скрипт сцены города.
## Генерирует тайловую карту-плейсхолдер, расставляет NPC и ворота данжа,
## настраивает камеру.

const COLS: int = 120
const ROWS: int = 80
const TILE: int = 20

const _SidePanel = preload("res://src/ui/SidePanel.gd")
const _Inventory  = preload("res://src/gameplay/Inventory.gd")

# Атлас тайлов (те же что в Room.gd)
const ATLAS_FLOOR: Vector2i = Vector2i(0, 0)
const ATLAS_WALL: Vector2i  = Vector2i(1, 0)

# Размер города в пикселях
const TOWN_W: float = COLS * TILE  # 2400
const TOWN_H: float = ROWS * TILE  # 1600

var _tilemap: TileMapLayer
var _player: Node2D = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	add_to_group("town")
	_build_tilemap()
	_build_collision_walls()
	_place_buildings()
	_place_npcs()
	_place_dungeon_gate()
	_spawn_player()
	_setup_camera()
	_show_resurrection_notice()
	add_child(_Inventory.new())
	add_child(_SidePanel.new())


# ---------------------------------------------------------------------------
# Генерация тайловой карты
# ---------------------------------------------------------------------------

func _build_tilemap() -> void:
	_tilemap = TileMapLayer.new()
	add_child(_tilemap)

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)

	# --- Трава (пол) — загружаем PNG или fallback solid color ---
	var floor_src := TileSetAtlasSource.new()
	var grass_tex := _load_scaled_tex("res://assets/art/environment/grass.png")
	floor_src.texture = grass_tex if grass_tex != null else _make_solid_tex(Color(0.45, 0.52, 0.30))
	floor_src.texture_region_size = Vector2i(TILE, TILE)
	floor_src.create_tile(Vector2i(0, 0))
	var floor_id: int = ts.add_source(floor_src)

	# --- Стена (периметр) — solid dark stone ---
	var wall_src := TileSetAtlasSource.new()
	wall_src.texture = _make_solid_tex(Color(0.22, 0.20, 0.18))
	wall_src.texture_region_size = Vector2i(TILE, TILE)
	wall_src.create_tile(Vector2i(0, 0))
	var wall_id: int = ts.add_source(wall_src)

	_tilemap.tile_set = ts

	# Заполняем: стены по периметру, трава внутри
	for r in range(ROWS):
		for c in range(COLS):
			var is_wall: bool = (c == 0 or c == COLS - 1 or r == 0 or r == ROWS - 1)
			_tilemap.set_cell(Vector2i(c, r), wall_id if is_wall else floor_id, Vector2i(0, 0))


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


func _build_collision_walls() -> void:
	# Четыре статических тела по периметру
	var thickness: float = TILE
	var bodies: Array[Array] = [
		# top
		[Vector2(TOWN_W * 0.5, thickness * 0.5), Vector2(TOWN_W, thickness)],
		# bottom
		[Vector2(TOWN_W * 0.5, TOWN_H - thickness * 0.5), Vector2(TOWN_W, thickness)],
		# left
		[Vector2(thickness * 0.5, TOWN_H * 0.5), Vector2(thickness, TOWN_H)],
		# right
		[Vector2(TOWN_W - thickness * 0.5, TOWN_H * 0.5), Vector2(thickness, TOWN_H)],
	]
	for b: Array in bodies:
		var sb := StaticBody2D.new()
		sb.position = b[0]
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = b[1]
		cs.shape = rect
		sb.add_child(cs)
		add_child(sb)


func _place_buildings() -> void:
	# Несколько прямоугольных зданий-плейсхолдеров
	var buildings: Array[Dictionary] = [
		{"pos": Vector2(300, 200), "size": Vector2(200, 160), "color": Color(0.5, 0.35, 0.2), "label": "Таверна"},
		{"pos": Vector2(800, 180), "size": Vector2(160, 140), "color": Color(0.55, 0.4, 0.25), "label": "Лавка"},
		{"pos": Vector2(1400, 250), "size": Vector2(180, 150), "color": Color(0.4, 0.35, 0.3), "label": "Кузница"},
		{"pos": Vector2(600, 600), "size": Vector2(220, 180), "color": Color(0.45, 0.4, 0.35), "label": "Мэрия"},
		{"pos": Vector2(1100, 700), "size": Vector2(160, 130), "color": Color(0.5, 0.45, 0.35), "label": "Дом"},
		{"pos": Vector2(200, 900), "size": Vector2(150, 120), "color": Color(0.45, 0.38, 0.28), "label": "Дом"},
		{"pos": Vector2(1700, 500), "size": Vector2(160, 140), "color": Color(0.4, 0.33, 0.25), "label": "Склад"},
	]
	for bdata: Dictionary in buildings:
		_make_building(bdata["pos"], bdata["size"], bdata["color"], bdata["label"])


func _make_building(pos: Vector2, size: Vector2, color: Color, label: String) -> void:
	var sb := StaticBody2D.new()
	sb.position = pos

	# Спрайт здания — PNG или fallback ColorRect
	var bld_tex := _load_building_tex(label)
	if bld_tex != null:
		var spr := Sprite2D.new()
		spr.texture = bld_tex
		spr.scale = size / Vector2(bld_tex.get_width(), bld_tex.get_height())
		sb.add_child(spr)
	else:
		var vis := ColorRect.new()
		vis.color = color
		vis.size = size
		vis.position = -size * 0.5
		sb.add_child(vis)

	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	sb.add_child(cs)

	var lbl := Label.new()
	lbl.text = label
	lbl.position = Vector2(-size.x * 0.5, -size.y * 0.5 - 20)
	lbl.size = Vector2(size.x, 20)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	sb.add_child(lbl)

	add_child(sb)


func _load_building_tex(label: String) -> Texture2D:
	var path: String
	match label:
		"Таверна", "Мэрия":
			path = "res://assets/art/environment/building_large.png"
		"Лавка", "Кузница", "Склад":
			path = "res://assets/art/environment/building_medium.png"
		_:  # Дом
			path = "res://assets/art/environment/building_house.png"
	if ResourceLoader.exists(path):
		return load(path)
	return null


# ---------------------------------------------------------------------------
# NPC и ворота
# ---------------------------------------------------------------------------

func _place_npcs() -> void:
	var merchant := MerchantNPC.new()
	merchant.position = Vector2(820, 320)
	add_child(merchant)

	var blacksmith := BlacksmithNPC.new()
	blacksmith.position = Vector2(1420, 380)
	add_child(blacksmith)

	var elder := ElderNPC.new()
	elder.position = Vector2(640, 700)
	add_child(elder)


func _place_dungeon_gate() -> void:
	var gate := DungeonGate.new()
	gate.position = Vector2(2200, 800)
	add_child(gate)

	# Табличка
	var lbl := Label.new()
	lbl.text = "▼ К данжу"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	lbl.position = Vector2(2160, 880)
	lbl.size = Vector2(100, 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)


# ---------------------------------------------------------------------------
# Игрок и камера
# ---------------------------------------------------------------------------

func _spawn_player() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	if player_scene == null:
		push_error("Town: не могу загрузить res://scenes/player.tscn")
		return
	_player = player_scene.instantiate()
	if PlayerData.returned_from_dungeon:
		PlayerData.returned_from_dungeon = false
		_player.global_position = Vector2(2080, 800)   # Рядом с воротами данжа (2200, 800)
	elif PlayerData.was_resurrected:
		_player.global_position = Vector2(TOWN_W * 0.5, TOWN_H * 0.5)
	else:
		_player.global_position = Vector2(300, TOWN_H * 0.5)
	add_child(_player)

	# Дерево навыков — добавляем к игроку чтобы SidePanel мог находить его через группу.
	var stats := _player.get_node_or_null("StatsComponent") as StatsComponent
	var skill_tree := SkillTree.new()
	skill_tree.name = "SkillTree"
	_player.add_child(skill_tree)
	skill_tree.setup(stats, null, null)


func _setup_camera() -> void:
	var cam := Camera2D.new()
	cam.limit_left   = 0
	cam.limit_top    = 0
	cam.limit_right  = int(TOWN_W)
	cam.limit_bottom = int(TOWN_H)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 5.0
	if _player != null:
		_player.add_child(cam)
		cam.make_current()
	else:
		add_child(cam)


# ---------------------------------------------------------------------------
# Воскрешение
# ---------------------------------------------------------------------------

func _show_resurrection_notice() -> void:
	if not PlayerData.was_resurrected:
		return
	PlayerData.was_resurrected = false

	# Ищем DialogueScreen
	await get_tree().process_frame
	var nodes := get_tree().get_nodes_in_group("dialogue_screen")
	if nodes.is_empty():
		return
	var dlg := nodes[0] as DialogueScreen
	var tree: Dictionary = {
		"start": {
			"speaker": "Мистический голос",
			"portrait_color": Color(0.5, 0.3, 0.7),
			"text": "...Герой, твоя судьба ещё не исполнена. Боги вернули тебя в мир живых. Восстановись в городе и продолжи путь.",
			"choices": [{"label": "Продолжить", "next": ""}]
		}
	}
	dlg.start(tree, "start")
