class_name NPCBase
extends Node2D

## Базовый NPC: отображение спрайта-плейсхолдера, зона взаимодействия (E),
## подсказка над головой. Субклассы переопределяют interact().

@export var npc_name: String = "NPC"
@export var npc_color: Color = Color(0.4, 0.6, 0.9)

var _player_nearby: bool = false
var _prompt_label: Label

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_visual()
	_build_area()


func _build_visual() -> void:
	# Тело NPC (цветной прямоугольник-плейсхолдер)
	var body := ColorRect.new()
	body.color = npc_color
	body.size = Vector2(28, 36)
	body.position = Vector2(-14, -36)
	add_child(body)

	# Имя над головой
	var name_lbl := Label.new()
	name_lbl.text = npc_name
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.position = Vector2(-40, -58)
	name_lbl.size = Vector2(100, 20)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_lbl)

	# Подсказка [E]
	_prompt_label = Label.new()
	_prompt_label.text = "[E] Говорить"
	_prompt_label.add_theme_font_size_override("font_size", 11)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
	_prompt_label.position = Vector2(-45, -78)
	_prompt_label.size = Vector2(110, 20)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.hide()
	add_child(_prompt_label)


func _build_area() -> void:
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 55.0
	shape.shape = circle
	area.add_child(shape)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)


func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and event.is_action_pressed("interact"):
		interact()


# ---------------------------------------------------------------------------
# Public — переопределить в субклассе
# ---------------------------------------------------------------------------

func interact() -> void:
	pass


# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		_prompt_label.show()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		_prompt_label.hide()
