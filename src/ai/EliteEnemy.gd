class_name EliteEnemy
extends BaseEnemy

const _LootPickupScene = preload("res://scenes/loot_pickup.tscn")
const _SealRes = preload("res://assets/data/items/elite_seal.tres")

## Элитный враг. Добавляет Ground Slam (AOE + стан) и фазу ярости при низком HP.
## [br]
## Ground Slam: каждые [member slam_cooldown]с в радиусе [member slam_radius] наносит урон и станит.
## Ярость: при ≤ [member enrage_threshold] HP — скорость и урон ×1.35, фиолетовый → красный.

# ---------------------------------------------------------------------------
# Настройка Ground Slam
# ---------------------------------------------------------------------------

## Период между ударами (с).
@export var slam_cooldown: float  = 5.0
## Радиус AOE (px).
@export var slam_radius: float    = 90.0
## Урон от удара.
@export var slam_damage: float    = 12.0
## Длительность стана жертвы (с).
@export var slam_stun_dur: float  = 0.8
## Длительность телеграфа перед ударом (с).
@export var slam_windup: float    = 0.5

# ---------------------------------------------------------------------------
# Настройка ярости
# ---------------------------------------------------------------------------

## Порог HP (доля 0–1) для перехода в ярость.
@export var enrage_threshold: float = 0.40

# ---------------------------------------------------------------------------
# Внутреннее состояние
# ---------------------------------------------------------------------------

var _slam_cd: float    = 2.0   # небольшой разогрев в начале
var _slamming: bool    = false
var _slam_timer: float = 0.0
var _is_enraged: bool  = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	if data != null:
		data = data.duplicate()   # изолируем ресурс чтобы не портить других
	super._ready()


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return

	# Переход в ярость.
	if not _is_enraged and health != null:
		var frac: float = health.current_hp / health._get_max_hp()
		if frac <= enrage_threshold:
			_enrage()

	# Ground Slam — телеграф + удар.
	if _slamming:
		_slam_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		if _slam_timer <= 0.0:
			_do_slam()
		return

	# Обновляем cooldown слэма только в преследовании.
	if _state == State.CHASE:
		_slam_cd -= delta
		if _slam_cd <= 0.0 and _target != null:
			var dist: float = global_position.distance_to(_target.global_position)
			if dist <= slam_radius * 1.4:
				_begin_slam()
				return

	super._physics_process(delta)


# ---------------------------------------------------------------------------
# Ground Slam
# ---------------------------------------------------------------------------

func _begin_slam() -> void:
	_slamming  = true
	_slam_timer = slam_windup
	modulate = Color(1.0, 0.85, 0.0)   # Жёлтый — телеграф
	AbilityVFX.spawn_warrior_bash(get_tree(), global_position, slam_radius * 0.6)


func _do_slam() -> void:
	_slamming = false
	_slam_cd  = slam_cooldown

	# Сброс цвета.
	modulate = Color(1.0, 0.1, 0.1) if _is_enraged else Color(0.65, 0.2, 1.0)

	# AOE урон + стан.
	for enemy_node in get_tree().get_nodes_in_group("player"):
		if enemy_node is Node2D:
			var dist: float = global_position.distance_to((enemy_node as Node2D).global_position)
			if dist <= slam_radius:
				var hp: HealthComponent = enemy_node.get_node_or_null("HealthComponent") as HealthComponent
				if hp != null and not hp.is_dead:
					hp.take_damage(slam_damage * (1.35 if _is_enraged else 1.0))

	# VFX удара.
	AbilityVFX.spawn_warrior_bash(get_tree(), global_position, slam_radius)
	_change_state(State.CHASE)


# ---------------------------------------------------------------------------
# Ярость
# ---------------------------------------------------------------------------

## Переопределяем смерть чтобы дропнуть квестовый предмет при стадии 2.
func _on_died() -> void:
	super._on_died()
	if PlayerData.quest_stage == 2 and not PlayerData.quest_has_seal:
		_drop_seal()


func _drop_seal() -> void:
	var pickup = _LootPickupScene.instantiate()
	var main := get_tree().get_first_node_in_group("main")
	if main != null:
		main.add_child(pickup)
	else:
		get_tree().root.add_child(pickup)
	pickup.global_position = global_position
	pickup.init(_SealRes)


func _enrage() -> void:
	_is_enraged       = true
	data.move_speed   *= 1.35
	data.attack_damage *= 1.35
	modulate = Color(1.0, 0.1, 0.1)   # Красный

	# Пульсация масштаба как сигнал перехода.
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.12)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.12)
