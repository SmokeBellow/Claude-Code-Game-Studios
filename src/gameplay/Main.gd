class_name Main
extends Node2D

## Главная сцена игры. Соединяет все системы вместе.

const _DmgNum = preload("res://src/ui/DamageNumber.gd")
const _GameOverScreen = preload("res://src/ui/GameOverScreen.gd")
const _LootSystem = preload("res://src/gameplay/LootSystem.gd")
const _Inventory = preload("res://src/gameplay/Inventory.gd")
const _SidePanel = preload("res://src/ui/SidePanel.gd")
const _ClassSelectionScreen = preload("res://src/ui/ClassSelectionScreen.gd")
const _AudioManager = preload("res://src/core/AudioManager.gd")

@export var level_xp: LevelXPSystem
@export var hud: HUD
@export var attribute_screen: AttributeScreen

var _win_screen: WinScreen
var _loot_system: Node
var _class_selection: ClassSelectionScreen
var _audio_mgr: Node

func _ready() -> void:
	add_to_group("main")
	get_tree().paused = false

	# AudioManager — создаём локально, Autoload не обязателен.
	_audio_mgr = get_node_or_null("/root/AudioManager")
	if _audio_mgr == null:
		_audio_mgr = _AudioManager.new()
		_audio_mgr.name = "AudioManager"
		add_child(_audio_mgr)

	_win_screen = WinScreen.new()
	add_child(_win_screen)

	add_child(_GameOverScreen.new())

	_loot_system = _LootSystem.new()
	add_child(_loot_system)
	add_child(_Inventory.new())
	add_child(_SidePanel.new())

	_class_selection = _ClassSelectionScreen.new()
	add_child(_class_selection)

	# Находим CombatComponent игрока один раз.
	var combat: CombatComponent = null
	for player in get_tree().get_nodes_in_group("player"):
		combat = player.get_node_or_null("CombatComponent") as CombatComponent

		# Добавляем ClassAbilitySystem как дочерний к игроку.
		var cas := ClassAbilitySystem.new()
		cas.name = "ClassAbilitySystem"
		cas.player = player as CharacterBody2D
		cas.stats  = player.get_node_or_null("StatsComponent") as StatsComponent
		cas.health = player.get_node_or_null("HealthComponent") as HealthComponent
		player.add_child(cas)
		break

	# FloorManager спавнит врагов deferred и сам вызывает wire_enemy().
	# Здесь только обычные враги из группы (если они уже в сцене).

	if level_xp == null:
		return

	# Подключаем HealthComponent игрока для штрафа смерти и HUD.
	for player in get_tree().get_nodes_in_group("player"):
		var health := player.get_node_or_null("HealthComponent") as HealthComponent
		if health != null:
			level_xp.connect_player_health(health)
			if hud != null:
				hud.connect_components(health, level_xp)
			var p := player as Node2D
			health.damaged.connect(func(amt): _spawn_dmg(p.global_position, amt, true))
			health.damaged.connect(func(_amt): _audio_call("play_player_hurt"))

	# Звук level-up.
	level_xp.level_up.connect(func(_lvl: int, _pts: int): _audio_call("play_level_up"))

	# Показываем экран прокачки при level up.
	level_xp.level_up.connect(func(lvl: int, pts: int):
		# Разблокируем умения на 3/6/9 уровне.
		PlayerData.unlock_abilities_for_level(lvl)

		# На 3-м уровне — сначала выбор класса, AttributeScreen — после него.
		if lvl == 3 and PlayerData.player_class == PlayerData.CLASS_NONE \
				and is_instance_valid(_class_selection):
			_class_selection.class_chosen.connect(func(_c: int):
				if attribute_screen != null:
					attribute_screen.show_level_up(lvl, pts)
			, CONNECT_ONE_SHOT)
			_class_selection.show_selection()
			return
		if attribute_screen != null:
			attribute_screen.show_level_up(lvl, pts)
	)


## Вызывается FloorScene при спавне каждого нового врага.
func wire_enemy(enemy: Node) -> void:
	var combat: CombatComponent = null
	for player in get_tree().get_nodes_in_group("player"):
		combat = player.get_node_or_null("CombatComponent") as CombatComponent
		break
	_wire_enemy(enemy, combat)


func _wire_enemy(enemy: Node, combat: CombatComponent) -> void:
	if not enemy is BaseEnemy:
		return
	# Победа при убийстве босса — подключаем ПЕРВЫМ, чтобы WinScreen
	# появился раньше AttributeScreen (который показывается через level_xp).
	if enemy is BossEnemy:
		enemy.enemy_died.connect(_on_boss_died)
	if level_xp != null:
		level_xp.connect_enemy(enemy)
	if combat != null:
		combat.connect_enemy(enemy)
	if _loot_system != null:
		_loot_system.wire_enemy(enemy)
	# Числа урона над врагом (белые).
	var enemy_hp := enemy.get_node_or_null("HealthComponent") as HealthComponent
	if enemy_hp != null:
		var e := enemy as Node2D
		enemy_hp.damaged.connect(func(amt): _spawn_dmg(e.global_position, amt, false))
		enemy_hp.damaged.connect(func(_amt): _audio_call("play_hit"))
		enemy_hp.died.connect(func(): _audio_call("play_enemy_die"))
		enemy_hp.died.connect(func(): QuestSystem.notify_enemy_killed())


func _on_boss_died(_xp: int, data: EnemyData) -> void:
	QuestSystem.notify_boss_killed()
	if _win_screen != null:
		_win_screen.show_win(data)


## Безопасный вызов метода AudioManager.
func _audio_call(method: String) -> void:
	if _audio_mgr != null and is_instance_valid(_audio_mgr):
		_audio_mgr.call(method)


## Спавнит число урона. [param is_player] = true -> красный цвет.
func _spawn_dmg(world_pos: Vector2, amount: float, is_player: bool) -> void:
	var dn: Node2D = _DmgNum.new()
	dn.z_index = 10
	add_child(dn)
	dn.global_position = world_pos + Vector2(randf_range(-12.0, 12.0), -16.0)
	dn.init(amount, is_player)
