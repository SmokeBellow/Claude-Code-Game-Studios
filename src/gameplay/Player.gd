class_name Player
extends CharacterBody2D

## Контроллер движения игрока.
## Рывок встроен как базовое умение (Shift). Неуязвимость на время рывка.

# ---------------------------------------------------------------------------
# Экспортируемые параметры
# ---------------------------------------------------------------------------

## StatsComponent игрока. Если не заполнен — используется move_speed_fallback.
@export var stats: StatsComponent
## HealthComponent игрока.
@export var health: HealthComponent

## Резервная скорость для тестирования без StatsComponent.
@export var move_speed_fallback: float = 180.0
## Коэффициент сглаживания инерции.
@export var acceleration: float = 15.0

# ---------------------------------------------------------------------------
# Рывок — базовое умение всех персонажей
# ---------------------------------------------------------------------------

const DASH_DISTANCE: float  = 150.0
const DASH_DURATION: float  = 0.20
const DASH_COOLDOWN: float  = 0.80

var _dash_timer: float      = 0.0
var _dash_cooldown: float   = 0.0
var _is_dashing: bool       = false
var _dash_velocity: Vector2 = Vector2.ZERO

# ---------------------------------------------------------------------------
# Константы
# ---------------------------------------------------------------------------

const MAX_DELTA: float              = 0.1
const MIN_FACING_DISTANCE_SQ: float = 1.0

# ---------------------------------------------------------------------------
# Публичное состояние
# ---------------------------------------------------------------------------

## Нормализованное направление к курсору.
var facing_direction: Vector2 = Vector2.RIGHT
## Флаг блокировки движения (устанавливается Боевой системой).
var is_movement_locked: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	add_to_group("player")
	if health != null:
		health.died.connect(on_died)
	# Спрайт игрока — загружаем PNG вместо PlaceholderTexture2D
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		var tex_path := "res://assets/art/characters/player.png"
		if ResourceLoader.exists(tex_path):
			var ptex: Texture2D = load(tex_path)
			sprite.texture = ptex
			# Масштабируем так, чтобы спрайт занимал ~32×40 пикселей в мире
			sprite.scale = Vector2(32.0 / ptex.get_width(), 40.0 / ptex.get_height())
	var _light := PointLight2D.new()
	_light.name = "TorchLight"
	_light.texture = WallTorch.make_radial_texture(128)
	_light.texture_scale = 4.5
	_light.energy = 1.0
	_light.color = Color(1.0, 0.88, 0.65)
	_light.shadow_enabled = true
	_light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	_light.shadow_filter_smooth = 4.0
	_light.enabled = false
	add_child(_light)


func _physics_process(delta: float) -> void:
	var safe_delta: float = minf(delta, MAX_DELTA)
	_update_facing()
	_update_dash(safe_delta)

	if _is_dashing:
		velocity = _dash_velocity
	elif is_movement_locked:
		velocity = Vector2.ZERO
	else:
		_update_movement(safe_delta)

	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	# DEV CHEAT: F2 = +3 уровня
	if OS.is_debug_build() and event is InputEventKey \
			and event.pressed and not event.echo \
			and event.keycode == KEY_F2:
		_cheat_level_up(3)
	if event.is_action_pressed("ability_primary"):
		_activate_dash()
	if event.is_action_pressed("use_potion_1"):
		use_potion(0)
	elif event.is_action_pressed("use_potion_2"):
		use_potion(1)
	elif event.is_action_pressed("use_potion_3"):
		use_potion(2)
	elif event.is_action_pressed("use_potion_4"):
		use_potion(3)

# ---------------------------------------------------------------------------
# Публичный API
# ---------------------------------------------------------------------------

## Блокирует / разблокирует движение.
func set_movement_locked(value: bool) -> void:
	is_movement_locked = value
	if value:
		velocity = Vector2.ZERO


## Вызывается при смерти.
func on_died() -> void:
	is_movement_locked = true
	velocity = Vector2.ZERO
	modulate = Color(1.0, 1.0, 1.0, 0.4)
	await get_tree().create_timer(1.5).timeout
	PlayerData.was_resurrected = true
	if health != null:
		health.respawn()
	get_tree().change_scene_to_file("res://scenes/town.tscn")


## Использует зелье здоровья из слота [param slot] (0–3).
func use_potion(slot: int) -> void:
	if not PlayerData.use_potion(slot):
		return
	if health != null:
		health.heal(50.0)


## Кулдаун рывка (0.0–1.0, 1.0 = готов).
func dash_cooldown_progress() -> float:
	if DASH_COOLDOWN <= 0.0:
		return 1.0
	return 1.0 - clampf(_dash_cooldown / DASH_COOLDOWN, 0.0, 1.0)


## DEV: добавить [param levels] уровней (работает только в debug-сборке).
func _cheat_level_up(levels: int) -> void:
	var lxp_nodes := get_tree().get_nodes_in_group("level_xp")
	if lxp_nodes.is_empty():
		return
	var lxp := lxp_nodes[0] as LevelXPSystem
	if lxp == null:
		return
	for i in levels:
		var needed: int = lxp.xp_to_next_level(lxp.current_level)
		lxp.add_xp(needed - lxp.current_xp + 1)
	print("CHEAT: level → %d" % lxp.current_level)



# ---------------------------------------------------------------------------
# Приватные методы
# ---------------------------------------------------------------------------

func _activate_dash() -> void:
	if _is_dashing or _dash_cooldown > 0.0:
		return

	# Направление: WASD если нажато, иначе взгляд.
	var dir := Vector2(
		float(Input.is_action_pressed("move_right")) - float(Input.is_action_pressed("move_left")),
		float(Input.is_action_pressed("move_down"))  - float(Input.is_action_pressed("move_up"))
	).normalized()
	if dir == Vector2.ZERO:
		dir = facing_direction

	_dash_velocity  = dir * (DASH_DISTANCE / DASH_DURATION)
	_dash_timer     = DASH_DURATION
	_dash_cooldown  = DASH_COOLDOWN
	_is_dashing     = true

	if health != null:
		health.set_invincible(true)


func _update_dash(delta: float) -> void:
	if _dash_cooldown > 0.0:
		_dash_cooldown = maxf(0.0, _dash_cooldown - delta)

	if not _is_dashing:
		return

	_dash_timer -= delta
	if _dash_timer <= 0.0:
		_is_dashing   = false
		_dash_timer   = 0.0
		velocity      = Vector2.ZERO
		if health != null:
			health.set_invincible(false)


func _update_movement(delta: float) -> void:
	var input_dir := Vector2(
		float(Input.is_action_pressed("move_right")) - float(Input.is_action_pressed("move_left")),
		float(Input.is_action_pressed("move_down"))  - float(Input.is_action_pressed("move_up"))
	)
	var speed: float = stats.move_speed() if stats != null else move_speed_fallback
	_target_velocity = input_dir.normalized() * speed
	velocity = velocity.lerp(_target_velocity, acceleration * delta)

var _target_velocity: Vector2 = Vector2.ZERO


func _update_facing() -> void:
	var mouse_offset: Vector2 = get_global_mouse_position() - global_position
	if mouse_offset.length_squared() > MIN_FACING_DISTANCE_SQ:
		facing_direction = mouse_offset.normalized()
