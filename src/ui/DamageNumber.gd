class_name DamageNumber
extends Label

## Всплывающее число урона. Создаётся через [method spawn] и самоудаляется.

const FLOAT_DISTANCE: float = 40.0
const DURATION: float = 0.8

## Создаёт белое число урона (для врагов).
static func spawn(parent: Node, world_pos: Vector2, amount: float) -> void:
	var dn := DamageNumber.new()
	dn.text = str(int(amount))
	dn.z_index = 10
	dn.modulate = Color.WHITE
	parent.add_child(dn)
	dn.global_position = world_pos + Vector2(randf_range(-12.0, 12.0), -16.0)
	dn._animate()

## Создаёт красное число урона (для игрока).
static func spawn_player(parent: Node, world_pos: Vector2, amount: float) -> void:
	var dn := DamageNumber.new()
	dn.text = str(int(amount))
	dn.z_index = 10
	dn.modulate = Color(1.0, 0.3, 0.3)
	parent.add_child(dn)
	dn.global_position = world_pos + Vector2(randf_range(-12.0, 12.0), -16.0)
	dn._animate()


func _animate() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - FLOAT_DISTANCE, DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "modulate:a", 0.0, DURATION)\
		.set_ease(Tween.EASE_IN).set_delay(DURATION * 0.4)
	tween.chain().tween_callback(queue_free)
