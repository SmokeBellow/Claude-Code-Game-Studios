# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does real-time top-down combat feel satisfying in Godot 4.6?
# Date: 2026-03-23

extends CharacterBody2D

const PATROL_SPEED    := 50.0
const CHASE_SPEED     := 110.0
const DETECT_RANGE    := 160.0
const ATTACK_RANGE    := 40.0
const ATTACK_DAMAGE   := 12
const ATTACK_COOLDOWN := 1.2
const MAX_HP          := 60

enum State { PATROL, CHASE, ATTACK, DEAD }
var state            := State.PATROL
var hp               := MAX_HP
var attack_cd_timer  := 0.0
var patrol_timer     := 0.0
var patrol_direction := Vector2.RIGHT
var player           = null

var _activation_delay := 0.0
var _flash_color_val  := Color(0.9, 0.1, 0.1)
var _flash_timer      := 0.0
var _spawn_pos        := Vector2.ZERO

signal died(enemy: Node)
signal damage_taken(amount: int, position: Vector2)

func _ready() -> void:
	add_to_group("enemies")
	patrol_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	patrol_timer = randf_range(1.0, 4.0)
	_activation_delay = randf_range(1.0, 4.0)
	# Hide any editor ColorRect children — we draw manually
	for child in get_children():
		if child is ColorRect:
			child.visible = false
	_spawn_pos = position
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and state != State.DEAD:
			_flash_color_val = Color(0.9, 0.1, 0.1)
	queue_redraw()

func _draw() -> void:
	# Body
	draw_rect(Rect2(-12, -12, 24, 24), _flash_color_val)
	# HP bar background
	draw_rect(Rect2(-14, -20, 28, 4), Color(0.2, 0.2, 0.2))
	# HP bar fill
	var fill_w := 28.0 * (float(hp) / float(MAX_HP))
	draw_rect(Rect2(-14, -20, fill_w, 4), Color(0.1, 0.9, 0.1))

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if _activation_delay > 0.0:
		_activation_delay -= delta
		velocity = patrol_direction * PATROL_SPEED
		move_and_slide()
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
			elif dist > DETECT_RANGE * 1.5:
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
		# Return toward spawn if wandered too far
		if position.distance_to(_spawn_pos) > 150.0:
			patrol_direction = position.direction_to(_spawn_pos)
		else:
			patrol_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		patrol_timer = randf_range(1.5, 3.0)
	velocity = patrol_direction * PATROL_SPEED

func _chase() -> void:
	if player == null:
		return
	velocity = global_position.direction_to(player.global_position) * CHASE_SPEED

func _do_attack() -> void:
	attack_cd_timer = ATTACK_COOLDOWN
	if player and global_position.distance_to(player.global_position) <= ATTACK_RANGE * 1.2:
		if player.has_method("take_damage"):
			player.take_damage(ATTACK_DAMAGE)
	_flash(Color(2.0, 0.8, 0.2), 0.1)

func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return
	hp = max(0, hp - amount)
	damage_taken.emit(amount, global_position)
	_flash(Color(0.1, 2.0, 0.1), 0.12)
	if state == State.PATROL:
		state = State.CHASE
	if hp <= 0:
		_die()

func _flash(color: Color, duration: float) -> void:
	_flash_color_val = color
	_flash_timer = duration

func _die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	died.emit(self)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
