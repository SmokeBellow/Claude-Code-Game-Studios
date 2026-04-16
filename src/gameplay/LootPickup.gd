class_name LootPickup
extends Node2D

## Предмет на полу.
## Падает вниз при спавне. При нажатии E вблизи — летит к игроку и исчезает.

const INTERACT_RANGE: float = 60.0
const BOB_SPEED:      float = 2.5
const BOB_AMOUNT:     float = 3.0
const ICON_PATH       := "res://assets/art/items/item_placeholder.png"
# Целевой визуальный размер в Godot-единицах (враги — 14 ед.).
const TARGET_SIZE:    float = 18.0

var item: ItemResource = null

var _visual: Node2D
var _hint: Label
var _bob_time: float = 0.0
var _drop_done: bool = false
var _collecting: bool = false


func _ready() -> void:
	if ResourceLoader.exists(ICON_PATH):
		var spr := Sprite2D.new()
		spr.texture = load(ICON_PATH)
		# Масштабируем под TARGET_SIZE независимо от размера PNG.
		var tex_size: Vector2 = spr.texture.get_size()
		var s: float = TARGET_SIZE / maxf(tex_size.x, tex_size.y)
		spr.scale = Vector2(s, s)
		_visual = spr
	else:
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(0, -9), Vector2(9, 0), Vector2(0, 9), Vector2(-9, 0)
		])
		_visual = poly
	add_child(_visual)

	# Подсказка [E] над предметом
	_hint = Label.new()
	_hint.text = "[E]"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 10)
	_hint.add_theme_color_override("font_color", Color.WHITE)
	_hint.position = Vector2(-10.0, -24.0)
	_hint.visible = false
	add_child(_hint)

	# Анимация падения: появляется сверху и приземляется
	_visual.position.y = -22.0
	var tween := create_tween()
	tween.tween_property(_visual, "position:y", 0.0, 0.22) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): _drop_done = true)


func init(item_res: ItemResource) -> void:
	item = item_res
	if _visual is Polygon2D:
		(_visual as Polygon2D).color = item_res.rarity_color()
	elif _visual is Sprite2D:
		(_visual as Sprite2D).modulate = item_res.rarity_color().lerp(Color.WHITE, 0.4)


func _physics_process(delta: float) -> void:
	if _collecting:
		return

	if _drop_done:
		_bob_time += delta
		_visual.position.y = sin(_bob_time * BOB_SPEED) * BOB_AMOUNT

	var player := _get_player()
	_hint.visible = (player != null and not _collecting
		and global_position.distance_to(player.global_position) <= INTERACT_RANGE)


func _unhandled_input(event: InputEvent) -> void:
	if _collecting:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if (event as InputEventKey).keycode != KEY_E:
		return

	var player := _get_player()
	if player == null:
		return
	if global_position.distance_to(player.global_position) > INTERACT_RANGE:
		return

	get_viewport().set_input_as_handled()
	_collect(player)


func _collect(player: Node2D) -> void:
	_collecting = true
	set_physics_process(false)
	_hint.visible = false

	# Летит к игроку, затем исчезает
	var tween := create_tween()
	tween.tween_property(self, "global_position",
		player.global_position, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_visual, "modulate:a", 0.0, 0.07)
	tween.tween_callback(func():
		var inv := get_tree().get_first_node_in_group("inventory")
		if inv != null and inv.has_method("pickup_item") and item != null:
			var picked: bool = inv.pickup_item(item)
			if not picked:
				# Сумка полна — предмет остаётся лежать, нода не удаляется
				return
		queue_free()
	)


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as Node2D if not players.is_empty() else null
