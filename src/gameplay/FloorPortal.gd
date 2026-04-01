class_name FloorPortal
extends Area2D

## Портал перехода между этажами данжа.

## На какой этаж ведёт этот портал.
var target_floor: int = 2

var _time: float = 0.0
var _player_nearby: bool = false
var _activated: bool = false
var _prompt: Label


func _ready() -> void:
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 36.0
	col.shape = shape
	add_child(col)

	var lbl := Label.new()
	lbl.text = "Этаж %d →" % target_floor
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-40, -68)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	add_child(lbl)

	_prompt = Label.new()
	_prompt.text = "[E] Перейти"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-36, -50)
	_prompt.add_theme_font_size_override("font_size", 13)
	_prompt.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
	_prompt.visible = false
	add_child(_prompt)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var alpha := 0.35 + 0.35 * sin(_time * 3.0)
	draw_circle(Vector2.ZERO, 28.0, Color(0.5, 0.3, 0.9, alpha * 0.4))
	draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 48, Color(0.7, 0.4, 1.0, alpha), 4.0)
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32, Color(0.9, 0.7, 1.0, alpha * 0.6), 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and not _activated and event.is_action_pressed("interact"):
		_activated = true
		var fm := get_tree().get_first_node_in_group("floor_manager")
		if fm != null and fm.has_method("enter_floor"):
			fm.enter_floor(target_floor)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		_prompt.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		_prompt.visible = false
