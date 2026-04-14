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
	add_to_group("player")
	set_process_input(true)
	var cam := Camera2D.new()
	add_child(cam)

func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if is_dodging:
		velocity = dodge_direction * DODGE_SPEED
	else:
		_handle_movement()
	move_and_slide()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and attack_cd_timer <= 0.0 and not is_dodging:
			_start_attack()
		if event.button_index == MOUSE_BUTTON_RIGHT and ability_cd_timer <= 0.0:
			_use_ability()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE and dodge_cd_timer <= 0.0 and not is_attacking:
			_start_dodge()

func _handle_movement() -> void:
	var dir := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	).normalized()
	velocity = dir * MOVE_SPEED
	# Always face the mouse cursor
	var mouse_dir := (get_global_mouse_position() - global_position)
	if mouse_dir.length() > 1.0:
		facing = mouse_dir.normalized()

func _start_attack() -> void:
	is_attacking = true
	attack_timer = ATTACK_DURATION
	attack_cd_timer = ATTACK_COOLDOWN
	var hit_pos := global_position + facing * (ATTACK_RANGE * 0.5)
	_spawn_hitbox(hit_pos, ATTACK_RANGE * 0.5, ATTACK_DAMAGE)
	_show_attack_visual(hit_pos, ATTACK_RANGE * 0.5)
	modulate = Color(2.0, 2.0, 0.2)
	await get_tree().create_timer(0.15).timeout
	modulate = Color.WHITE

func _show_attack_visual(_at: Vector2, radius: float) -> void:
	var poly := Polygon2D.new()
	var r := radius
	poly.polygon = PackedVector2Array([
		Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)
	])
	poly.color = Color(1.0, 1.0, 0.0, 0.5)
	poly.position = facing * ATTACK_RANGE * 0.5
	add_child(poly)
	await get_tree().create_timer(0.15).timeout
	poly.queue_free()

func _show_nova_visual(radius: float) -> void:
	var poly := Polygon2D.new()
	var points := PackedVector2Array()
	var steps := 24
	for i in range(steps):
		var angle := (TAU / steps) * i
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	poly.polygon = points
	poly.color = Color(0.4, 0.8, 1.0, 0.4)
	add_child(poly)
	# Expand and fade
	var tween := create_tween()
	tween.tween_property(poly, "scale", Vector2(1.4, 1.4), 0.3)
	tween.parallel().tween_property(poly, "modulate:a", 0.0, 0.3)
	await get_tree().create_timer(0.3).timeout
	poly.queue_free()

func _start_dodge() -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	dodge_direction = dir if dir != Vector2.ZERO else facing
	is_dodging = true
	is_invincible = true
	dodge_timer = DODGE_DURATION
	dodge_cd_timer = DODGE_COOLDOWN

func _use_ability() -> void:
	ability_cd_timer = ABILITY_COOLDOWN
	_spawn_hitbox(global_position, ABILITY_RADIUS, ABILITY_DAMAGE, true)
	_show_nova_visual(ABILITY_RADIUS)
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

# Damages enemies within radius using direct distance check.
func _spawn_hitbox(at: Vector2, radius: float, damage: int, is_nova: bool = false) -> void:
	await get_tree().physics_frame
	for body in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(body) and body.has_method("take_damage"):
			if at.distance_to(body.global_position) <= radius:
				body.take_damage(damage)
