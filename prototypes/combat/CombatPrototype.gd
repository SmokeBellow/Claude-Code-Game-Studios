# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does real-time top-down combat feel satisfying in Godot 4.6?
# Date: 2026-03-23
#
# Main scene controller. Attach to root Node2D.
# Scene tree expected:
#
#   CombatPrototype (Node2D)  <-- this script
#   ├── Player (CharacterBody2D + Player.gd)
#   │     └── CollisionShape2D (capsule or circle ~14px)
#   ├── Enemies (Node2D, container)
#   │     ├── Enemy (CharacterBody2D + Enemy.gd) x3
#   │     │     └── CollisionShape2D (circle ~12px)
#   ├── UI (CanvasLayer)
#   │     ├── PlayerHP (ProgressBar)
#   │     ├── AbilityCD (Label)  "Ability: READY" / "3.0s"
#   │     └── KillCount (Label)
#   └── RespawnLabel (Label, centered, hidden)

extends Node2D

@onready var player         : CharacterBody2D = $Player
@onready var enemies_root   : Node2D          = $Enemies
@onready var player_hp_bar  : ProgressBar     = $UI/PlayerHP
@onready var ability_label  : Label           = $UI/AbilityCD
@onready var kill_label     : Label           = $UI/KillCount
@onready var respawn_label  : Label           = $RespawnLabel

var kill_count := 0

func _ready() -> void:
	# Connect player signals
	player.hp_changed.connect(_on_player_hp_changed)
	player.damage_taken.connect(_on_damage_taken)
	player.died.connect(_on_player_died)
	# Init HP bar directly (signal fires before connection in child _ready)
	player_hp_bar.min_value = 0
	player_hp_bar.max_value = player.MAX_HP
	player_hp_bar.value     = player.MAX_HP

	# Connect enemy signals
	for enemy in enemies_root.get_children():
		_connect_enemy(enemy)

	_update_kill_label()
	if respawn_label:
		respawn_label.visible = false

func _process(_delta: float) -> void:
	# Update ability cooldown display
	if is_instance_valid(player):
		var cd: float = player.ability_cd_timer
		ability_label.text = "Ability [RMB]: " + ("READY" if cd <= 0 else "%.1fs" % cd)

func _connect_enemy(enemy: Node) -> void:
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)
	if enemy.has_signal("damage_taken"):
		enemy.damage_taken.connect(_on_damage_taken)

func _on_player_hp_changed(new_hp: int, max_hp: int) -> void:
	player_hp_bar.max_value = max_hp
	player_hp_bar.value = new_hp

func _on_damage_taken(amount: int, world_pos: Vector2) -> void:
	DamageNumber.spawn(self, amount, world_pos)

func _on_enemy_died(_enemy: Node) -> void:
	kill_count += 1
	_update_kill_label()

func _on_player_died() -> void:
	if respawn_label:
		respawn_label.visible = true
		respawn_label.text = "You died.\n[R] Restart"

func _update_kill_label() -> void:
	kill_label.text = "Kills: %d" % kill_count

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
