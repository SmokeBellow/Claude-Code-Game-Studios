# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does real-time top-down combat feel satisfying in Godot 4.6?
# Date: 2026-03-23

extends CharacterBody2D

# --- Hardcoded values ---
const PATROL_SPEED    := 50.0
const CHASE_SPEED     := 110.0
const DETECT_RANGE    := 200.0   # pixels — player enters vision
const ATTACK_RANGE    := 40.0    # pixels — melee reach
const ATTACK_DAMAGE   := 12
const ATTACK_COOLDOWN := 1.2     # seconds
const MAX_HP          := 60

# --- State machine ---
enum State { PATROL, CHASE, ATTACK, DEAD }
var state            := State.PATROL

var hp               := MAX_HP
var attack_cd_timer  := 0.0
var patrol_timer     := 0.0
var patrol_direction := Vector2.RIGHT
var player: CharacterBody2D = null

signal died(enemy: Node)
signal damage_taken(amount: int, position: Vector2)

func _ready() -> void:
	patrol_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	patrol_timer = randf_range(1.5, 3.0)
	# Find player (prototype: assume it's in group "player")
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	attack_cd_timer = max(0.0, attack_cd_timer - delta)
	_update_state()
	_execute_state(delta)
	move_and_slide()

func _update_state() -> void:
	if player == null:
		return
	var dist := global_position.distance_to(player.global_position)
	match state:
		State.PATROL:
			if dist < DETECT_RANGE:
				state = State.CHASE
		State.CHASE:
			if dist <= ATTACK_RANGE:
				state = State.ATTACK
			elif dist > DETECT_RANGE * 1.4:  # hysteresis — don't flicker
				state = State.PATROL
		State.ATTACK:
			if dist > ATTACK_RANGE * 1.2:
				state = State.CHASE

func _execute_state(delta: float) -> void:
	match state:
		State.PATROL:
			_patrol(delta)
		State.CHASE:
			_chase()
		State.ATTACK:
			velocity = Vector2.ZERO
			if attack_cd_timer <= 0.0:
				_do_attack()

func _patrol(delta: float) -> void:
	patrol_timer -= delta
	if patrol_timer <= 0.0:
		patrol_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		patrol_timer = randf_range(1.5, 3.0)
	velocity = patrol_direction * PATROL_SPEED

func _chase() -> void:
	if player == null:
		return
	velocity = global_position.direction_to(player.global_position) * CHASE_SPEED

func _do_attack() -> void:
	attack_cd_timer = ATTACK_COOLDOWN
	# Simple: directly damage player if still in range
	if player and global_position.distance_to(player.global_position) <= ATTACK_RANGE * 1.2:
		if player.has_method("take_damage"):
			player.take_damage(ATTACK_DAMAGE)
	# Attack flash
	modulate = Color(2.0, 0.8, 0.2)
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE

func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return
	hp = max(0, hp - amount)
	damage_taken.emit(amount, global_position)
	# Hit flash
	modulate = Color(2.5, 0.3, 0.3)
	await get_tree().create_timer(0.08).timeout
	if state != State.DEAD:
		modulate = Color.WHITE
	# Aggro when hit
	if state == State.PATROL:
		state = State.CHASE
	if hp <= 0:
		_die()

func _die() -> void:
	state = State.DEAD
	died.emit(self)
	# Simple death: fade out and free
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
