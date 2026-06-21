class_name WallTorch
extends Node2D

## Настенный факел. Мигающий PointLight2D с тенями + простой визуал.
## Свет горит всегда и не проходит сквозь стены (shadow_enabled).
## Визуал факела (пламя + палка) скрывается если между игроком и факелом стена.

var _light: PointLight2D
var _visual: Node2D          # контейнер для flame + stick
var _time: float = 0.0
var _player: Node2D = null

const CULL_DIST_SQ: float   = 750.0 * 750.0
const RAYCAST_INTERVAL: float = 0.25

var _raycast_timer: float = 0.0

static var _tex_cache: ImageTexture = null


func _ready() -> void:
	_build_visual()
	_light = PointLight2D.new()
	_light.texture = make_radial_texture(128)
	_light.texture_scale = 4.5
	_light.energy = 1.6
	_light.color = Color(1.0, 0.75, 0.4)
	_light.shadow_enabled = true
	_light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	_light.shadow_filter_smooth = 4.0
	_light.enabled = true
	add_child(_light)
	_raycast_timer = randf() * RAYCAST_INTERVAL


func _build_visual() -> void:
	_visual = Node2D.new()
	add_child(_visual)

	var stick := ColorRect.new()
	stick.color = Color(0.40, 0.27, 0.13)
	stick.size = Vector2(5.0, 10.0)
	stick.position = Vector2(-2.5, -10.0)
	_visual.add_child(stick)

	var flame := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(6):
		pts.append(Vector2(cos(i * TAU / 6.0), sin(i * TAU / 6.0)) * 4.5)
	flame.polygon = pts
	flame.color = Color(1.0, 0.6, 0.1)
	flame.position = Vector2(0.0, -16.0)
	_visual.add_child(flame)


func _process(delta: float) -> void:
	_time += delta

	if _player == null or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group("player")
		_player = players[0] as Node2D if not players.is_empty() else null

	_raycast_timer -= delta
	if _raycast_timer <= 0.0:
		_raycast_timer = RAYCAST_INTERVAL
		_update_visual_visibility()

	_light.energy = 1.6 + 0.25 * sin(_time * 8.1) + 0.1 * sin(_time * 15.3)


func _update_visual_visibility() -> void:
	if _player == null:
		_visual.visible = true
		return

	var dist_sq := _player.global_position.distance_squared_to(global_position)
	if dist_sq > CULL_DIST_SQ:
		_visual.visible = false
		return

	var space_state := get_world_2d().direct_space_state
	var player_rid: RID = (_player as CollisionObject2D).get_rid()
	var query := PhysicsRayQueryParameters2D.create(
		_player.global_position,
		global_position,
		0xFFFFFFFF,
		[player_rid]
	)
	var result := space_state.intersect_ray(query)
	_visual.visible = result.is_empty()


## Создаёт радиальную градиентную текстуру (кэшируется).
static func make_radial_texture(size: int) -> ImageTexture:
	if _tex_cache != null:
		return _tex_cache
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := size * 0.5
	for x in range(size):
		for y in range(size):
			var t := clampf(1.0 - Vector2(x, y).distance_to(Vector2(half, half)) / half, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, t * t))
	_tex_cache = ImageTexture.create_from_image(img)
	return _tex_cache
