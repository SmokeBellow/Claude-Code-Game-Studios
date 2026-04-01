class_name DungeonExit
extends Area2D

## Портал выхода из данжа. Размещается в стартовой комнате.
## При касании игрока — переход обратно в город.

var _time: float = 0.0
var _player_nearby: bool = false
var _prompt: Label


func _ready() -> void:
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 44.0
	col.shape = shape
	add_child(col)

	var lbl := Label.new()
	lbl.text = "В город"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-36, -70)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55))
	add_child(lbl)

	_prompt = Label.new()
	_prompt.text = "[E] Войти"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-30, -50)
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
	draw_circle(Vector2.ZERO, 36.0, Color(0.15, 0.65, 0.25, alpha * 0.35))
	draw_arc(Vector2.ZERO, 40.0, 0.0, TAU, 48, Color(0.25, 1.0, 0.45, alpha), 4.0)
	draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 32, Color(0.5, 1.0, 0.65, alpha * 0.5), 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and event.is_action_pressed("interact"):
		var player := get_tree().get_first_node_in_group("player")
		if player != null:
			var light := player.get_node_or_null("TorchLight") as PointLight2D
			if light != null:
				light.enabled = false
		PlayerData.returned_from_dungeon = true
		get_tree().change_scene_to_file("res://scenes/town.tscn")


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		_prompt.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		_prompt.visible = false
