class_name Main
extends Node2D

## Главная сцена игры. Соединяет все системы вместе.
## [br]
## Добавь [LevelXPSystem] как дочерний узел и заполни поле [member level_xp].

@export var level_xp: LevelXPSystem
@export var hud: HUD

func _ready() -> void:
	# Находим CombatComponent игрока один раз.
	var combat: CombatComponent = null
	for player in get_tree().get_nodes_in_group("player"):
		combat = player.get_node_or_null("CombatComponent") as CombatComponent
		break

	# Подключаем всех уже существующих врагов.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is BaseEnemy:
			if level_xp != null:
				level_xp.connect_enemy(enemy)
			if combat != null:
				combat.connect_enemy(enemy)

	if level_xp == null:
		return

	# Подключаем HealthComponent игрока для штрафа смерти и HUD.
	for player in get_tree().get_nodes_in_group("player"):
		var health := player.get_node_or_null("HealthComponent") as HealthComponent
		if health != null:
			level_xp.connect_player_health(health)
			if hud != null:
				hud.connect_components(health, level_xp)

	# Логируем level_up для теста.
	level_xp.level_up.connect(func(lvl, pts):
		print("LEVEL UP! Уровень: ", lvl, " | Получено очков: ", pts)
	)
	level_xp.xp_gained.connect(func(amount, source):
		print("+", amount, " XP (", source, ") | Всего: ", level_xp.current_xp)
	)
