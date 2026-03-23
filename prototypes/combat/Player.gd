# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does real-time top-down combat feel satisfying in Godot 4.6?
# Date: 2026-03-23

extends CharacterBody2D

# --- Hardcoded values (tune freely in prototype) ---
const MOVE_SPEED        := 180.0
const ATTACK_DAMAGE     := 25
const ATTACK_RANGE      := 60.0   # pixels
const ATTACK_DURATION   := 0.2    # seconds hitbox is active
const ATTACK_COOLDOWN   := 0.4    # seconds between attacks
const DODGE_SPEED       := 420.0
const DODGE_DURATION    := 0.22   # seconds
const DODGE_COOLDOWN    := 0.8    # seconds
const ABILITY_DAMAGE    := 50
const ABILITY_RADIUS    := 90.0   # nova burst radius
const ABILITY_COOLDOWN  := 3.0    # seconds
const MAX_HP            := 100

# --- State ---
var hp               := MAX_HP
var is_attacking     := false
var is_dodging       := false
var is_invincible    := false  # i-frames during dodge
var attack_timer     := 0.0
var attack_cd_timer  := 0.0
var dodge_timer      := 0.0
var dodge_cd_timer   := 0.0
var ability_cd_timer := 0.0
var dodge_direction  := Vector2.ZERO
var facing           := Vector2.RIGHT

signal died
signal hp_changed(new_hp: int, max_hp: int)
signal damage_taken(amount: int, position: Vector2)

func _ready() -> void:
	hp_changed.emit(hp, MAX_HP)

func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if is_dodging:
		velocity = dodge_direction * DODGE_SPEED
	else:
		_handle_movement()
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and attack_cd_timer <= 0.0 and not is_dodging:
		_start_attack()
	if event.is_action_pressed("dodge") and dodge_cd_timer <= 0.0 and not is_attacking:
		_start_dodge()
	if event.is_action_pressed("ability") and ability_cd_timer <= 0.0:
		_use_ability()

func _handle_movement() -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * MOVE_SPEED
	if dir != Vector2.ZERO:
		facing = dir.normalized()

func _start_attack() -> void:
	is_attacking = true
	attack_timer = ATTACK_DURATION
	attack_cd_timer = ATTACK_COOLDOWN
	# Spawn hitbox in facing direction
	_spawn_hitbox(position + facing * (ATTACK_RANGE * 0.5), ATTACK_RANGE * 0.5, ATTACK_DAMAGE)

func _start_dodge() -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	dodge_direction = dir if dir != Vector2.ZERO else facing
	is_dodging = true
	is_invincible = true
	dodge_timer = DODGE_DURATION
	dodge_cd_timer = DODGE_COOLDOWN

func _use_ability() -> void:
	ability_cd_timer = ABILITY_COOLDOWN
	# Nova burst: damages all enemies in radius
	_spawn_hitbox(position, ABILITY_RADIUS, ABILITY_DAMAGE, true)
	# Visual flash (placeholder — replace with particles in production)
	modulate = Color(2.0, 1.5, 0.2)
	await get_tree().create_timer(0.12).timeout
	modulate = Color.WHITE

func _tick_timers(delta: float) -> void:
	if attack_timer > 0.0:
		attack_timer -= delta
		if attack_timer <= 0.0:
			is_attacking = false

	if attack_cd_timer > 0.0:
		attack_cd_timer -= delta

	if dodge_timer > 0.0:
		dodge_timer -= delta
		if dodge_timer <= 0.0:
			is_dodging = false
			# I-frames linger slightly after dodge ends
			await get_tree().create_timer(0.05).timeout
			is_invincible = false

	if dodge_cd_timer > 0.0:
		dodge_cd_timer -= delta

	if ability_cd_timer > 0.0:
		ability_cd_timer -= delta

func take_damage(amount: int) -> void:
	if is_invincible:
		return
	hp = max(0, hp - amount)
	hp_changed.emit(hp, MAX_HP)
	damage_taken.emit(amount, global_position)
	# Flash red
	modulate = Color(2.0, 0.3, 0.3)
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
	if hp <= 0:
		died.emit()

# Spawns an Area2D hitbox that damages enemies once then frees itself.
func _spawn_hitbox(at: Vector2, radius: float, damage: int, is_nova: bool = false) -> void:
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	area.position = at
	area.collision_layer = 0
	area.collision_mask = 4  # Enemy layer (layer 3)
	get_tree().current_scene.add_child(area)

	# Give physics one frame to detect overlaps
	await get_tree().physics_frame

	for body in area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(damage)

	area.queue_free()
