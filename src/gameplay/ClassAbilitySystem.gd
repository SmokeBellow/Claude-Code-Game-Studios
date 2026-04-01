class_name ClassAbilitySystem
extends Node

## Система классовых умений. 3 слота (R / F / G), каждый с отдельным cooldown.
## [br]
## Воин:  Щит (оглушение), Мощный удар (×2 урон), Укрепление (временный HP бонус)
## Маг:   Огненный шар (AOE), Ледяная стрела (замедление), Магический щит (поглощение)
## Плут:  Дымовая бомба (туман — снижает точность врагов), Веер клинков, (парирование — отдельно)

# ---------------------------------------------------------------------------
# Экспорт
# ---------------------------------------------------------------------------

@export var player: CharacterBody2D
@export var stats: StatsComponent
@export var health: HealthComponent

# ---------------------------------------------------------------------------
# Cooldowns (секунды)
# ---------------------------------------------------------------------------

const COOLDOWN: Array[float] = [
	# slot 0       slot 1      slot 2
	8.0,           12.0,       15.0,   # Warrior
]

# Cooldown по классу × слоту
const COOLDOWNS: Dictionary = {
	1: [8.0,  12.0, 15.0],   # Warrior: Bash / Heavy / Fortify
	2: [6.0,  10.0, 14.0],   # Mage: Fireball / Ice Arrow / Arcane Shield
	3: [7.0,  9.0,  12.0],   # Rogue: Smoke Bomb / Fan of Knives / (parry handled by CombatComponent)
}

# Параметры умений (AOE-радиусы, длительности)
const WARRIOR_BASH_RADIUS:    float = 100.0
const WARRIOR_BASH_STUN:      float = 1.5
const WARRIOR_HEAVY_MULT:     float = 3.0   # следующая атака ×3
const WARRIOR_FORTIFY_HP:     float = 40.0
const WARRIOR_FORTIFY_DUR:    float = 8.0

const MAGE_FIREBALL_RADIUS:   float = 120.0
const MAGE_FIREBALL_DMG:      float = 60.0
const MAGE_ICE_DMG:           float = 25.0
const MAGE_ICE_SLOW:          float = 3.0
const MAGE_ICE_MULT:          float = 0.3
const MAGE_SHIELD_ABS:        float = 50.0

const ROGUE_SMOKE_RADIUS:     float = 130.0
const ROGUE_SMOKE_DUR:        float = 4.0
const ROGUE_SMOKE_CHANCE:     float = 0.6
const ROGUE_FAN_COUNT:        int   = 5
const ROGUE_FAN_ARC_DEG:      float = 120.0

# ---------------------------------------------------------------------------
# Состояние
# ---------------------------------------------------------------------------

var _cooldowns: Array[float] = [0.0, 0.0, 0.0]
## Если > 0 — следующая атака Воина усилена.
var _heavy_strike_ready: float = 0.0

# ---------------------------------------------------------------------------
# Сигналы
# ---------------------------------------------------------------------------

## Испускается при использовании умения. UI слушает для обновления кулдаунов.
signal ability_used(slot: int, cooldown: float)

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	for i in 3:
		if _cooldowns[i] > 0.0:
			_cooldowns[i] -= delta
	if _heavy_strike_ready > 0.0:
		_heavy_strike_ready -= delta
		if _heavy_strike_ready <= 0.0:
			# Время вышло — сбрасываем усиление и гасим индикатор.
			var combat: CombatComponent = _get_combat()
			if combat != null:
				combat.pending_damage_mult = 1.0
			if player != null and player.has_method("hide_heavy_indicator"):
				player.hide_heavy_indicator()

# ---------------------------------------------------------------------------
# Публичный API
# ---------------------------------------------------------------------------

func use_ability(slot: int) -> void:
	if slot < 0 or slot > 2:
		return
	if not PlayerData.ability_unlocked[slot]:
		return
	if _cooldowns[slot] > 0.0:
		return
	var audio := _find_audio()
	if audio != null:
		audio.play_ability()
	match PlayerData.player_class:
		PlayerData.CLASS_WARRIOR: _warrior(slot)
		PlayerData.CLASS_MAGE:    _mage(slot)
		PlayerData.CLASS_ROGUE:   _rogue(slot)


func get_cooldown(slot: int) -> float:
	return _cooldowns[slot]


func get_max_cooldown(slot: int) -> float:
	var pc: int = PlayerData.player_class
	var table: Array = COOLDOWNS.get(pc, [8.0, 12.0, 15.0])
	return table[slot]

# ---------------------------------------------------------------------------
# Воин
# ---------------------------------------------------------------------------

func _warrior(slot: int) -> void:
	match slot:
		0: _warrior_bash()
		1: _warrior_heavy()
		2: _warrior_fortify()


func _warrior_bash() -> void:
	# Оглушение + урон ближним врагам
	if player == null:
		return
	var phys_bonus: float = stats.phys_damage_bonus() if stats != null else 0.0
	var bash_dmg: float = 30.0 + phys_bonus
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is BaseEnemy:
			continue
		var dist: float = (enemy as Node2D).global_position.distance_to(player.global_position)
		if dist <= WARRIOR_BASH_RADIUS:
			(enemy as BaseEnemy).apply_stun(WARRIOR_BASH_STUN)
			var hp := (enemy as Node).get_node_or_null("HealthComponent") as HealthComponent
			if hp != null and not hp.is_dead:
				hp.take_damage(bash_dmg)
	AbilityVFX.spawn_warrior_bash(get_tree(), player.global_position, WARRIOR_BASH_RADIUS)
	_set_cooldown(0)


func _warrior_heavy() -> void:
	# Следующая атака нанесёт ×3 урон (флаг на кастомном сигнале)
	_heavy_strike_ready = 5.0   # 5 секунд чтобы использовать
	_set_cooldown(1)
	# Устанавливаем одноразовый множитель следующего удара.
	var combat: CombatComponent = _get_combat()
	if combat != null:
		combat.pending_damage_mult = WARRIOR_HEAVY_MULT
	if player != null:
		AbilityVFX.spawn_warrior_heavy(get_tree(), player.global_position)
		if player.has_method("show_heavy_indicator"):
			player.show_heavy_indicator()


func _warrior_fortify() -> void:
	if health == null:
		_set_cooldown(2)
		return
	health.add_temp_hp(WARRIOR_FORTIFY_HP, WARRIOR_FORTIFY_DUR)
	if player != null:
		AbilityVFX.spawn_warrior_fortify(get_tree(), player.global_position)
	_set_cooldown(2)

# ---------------------------------------------------------------------------
# Маг
# ---------------------------------------------------------------------------

func _mage(slot: int) -> void:
	match slot:
		0: _mage_fireball()
		1: _mage_ice_arrow()
		2: _mage_arcane_shield()


func _mage_fireball() -> void:
	if player == null:
		_set_cooldown(0)
		return
	var mouse: Vector2 = player.get_global_mouse_position()
	var dir: Vector2 = (mouse - player.global_position).normalized()

	var proj: PlayerProjectile = PlayerProjectile.new()
	player.get_tree().root.add_child(proj)
	proj.global_position = player.global_position
	proj.init(dir, MAGE_FIREBALL_DMG, 380.0, 600.0,
			  PlayerProjectile.Effect.AOE, 0.0, MAGE_FIREBALL_RADIUS,
			  Color(1.0, 0.4, 0.0))
	_set_cooldown(0)


func _mage_ice_arrow() -> void:
	if player == null:
		_set_cooldown(1)
		return
	var mouse: Vector2 = player.get_global_mouse_position()
	var dir: Vector2 = (mouse - player.global_position).normalized()

	var proj: PlayerProjectile = PlayerProjectile.new()
	player.get_tree().root.add_child(proj)
	proj.global_position = player.global_position
	proj.init(dir, MAGE_ICE_DMG, 500.0, 700.0,
			  PlayerProjectile.Effect.SLOW, MAGE_ICE_SLOW, MAGE_ICE_MULT,
			  Color(0.5, 0.85, 1.0))
	_set_cooldown(1)


func _mage_arcane_shield() -> void:
	if health != null:
		health.add_temp_hp(MAGE_SHIELD_ABS, 10.0)
	if player != null:
		AbilityVFX.spawn_mage_arcane_shield(get_tree(), player.global_position)
	_set_cooldown(2)

# ---------------------------------------------------------------------------
# Плут
# ---------------------------------------------------------------------------

func _rogue(slot: int) -> void:
	match slot:
		0: _rogue_smoke_bomb()
		1: _rogue_fan_of_knives()
		2: pass  # Парирование — уже в CombatComponent (ПКМ)


func _rogue_smoke_bomb() -> void:
	# Накладываем «туман» (снижение точности) на всех ближних врагов
	if player == null:
		_set_cooldown(0)
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is BaseEnemy:
			continue
		var dist: float = (enemy as Node2D).global_position.distance_to(player.global_position)
		if dist <= ROGUE_SMOKE_RADIUS:
			(enemy as BaseEnemy).apply_miss_chance(ROGUE_SMOKE_DUR, ROGUE_SMOKE_CHANCE)
	AbilityVFX.spawn_rogue_smoke(get_tree(), player.global_position, ROGUE_SMOKE_RADIUS)
	_set_cooldown(0)


func _rogue_fan_of_knives() -> void:
	# 5 снарядов равномерно в 120° дуге перед игроком
	if player == null:
		_set_cooldown(1)
		return
	var facing: Vector2 = player.facing_direction
	var spread_rad: float = deg_to_rad(ROGUE_FAN_ARC_DEG)
	var step: float = spread_rad / (ROGUE_FAN_COUNT - 1)
	var start_angle: float = facing.angle() - spread_rad * 0.5

	var phys_bonus: float = stats.phys_damage_bonus() if stats != null else 0.0
	var dmg: float = (15.0 + phys_bonus) * 0.7   # Каждый нож немного слабее основной атаки

	for i in ROGUE_FAN_COUNT:
		var angle: float = start_angle + step * i
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		var proj: PlayerProjectile = PlayerProjectile.new()
		player.get_tree().root.add_child(proj)
		proj.global_position = player.global_position
		proj.init(dir, dmg, 500.0, 300.0,
				  PlayerProjectile.Effect.NONE, 0.0, 0.0, Color(0.8, 0.8, 0.2))

	AbilityVFX.spawn_rogue_fan_activation(get_tree(), player.global_position, facing)
	_set_cooldown(1)

# ---------------------------------------------------------------------------
# Вспомогательные
# ---------------------------------------------------------------------------

func _set_cooldown(slot: int) -> void:
	var pc: int = PlayerData.player_class
	var table: Array = COOLDOWNS.get(pc, [8.0, 12.0, 15.0])
	_cooldowns[slot] = table[slot]
	ability_used.emit(slot, _cooldowns[slot])


func _get_combat() -> CombatComponent:
	if player == null:
		return null
	return player.get_node_or_null("CombatComponent") as CombatComponent


func _find_audio() -> Node:
	# Сначала — Autoload, затем — созданный Main'ом локальный экземпляр.
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		return am
	var main := get_tree().get_first_node_in_group("main")
	if main != null:
		return main.get_node_or_null("AudioManager")
	return null
