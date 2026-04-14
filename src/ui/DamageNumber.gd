## Всплывающее число урона. Создаётся через Main._spawn_dmg() и самоудаляется.
extends Node2D

const FLOAT_DISTANCE: float = 40.0
const DURATION: float = 0.8
const FONT_SIZE: int = 16

var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


## Инициализирует текст и цвет. Вызвать сразу после add_child().
func init(amount: float, is_player: bool) -> void:
	_label.text = str(int(amount))
	_label.modulate = Color(1.0, 0.3, 0.3) if is_player else Color.WHITE
	_animate()


func _animate() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - FLOAT_DISTANCE, DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_label, "modulate:a", 0.0, DURATION).set_ease(Tween.EASE_IN).set_delay(DURATION * 0.4)
	tween.chain().tween_callback(queue_free)
