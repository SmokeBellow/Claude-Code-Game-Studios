# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does real-time top-down combat feel satisfying in Godot 4.6?
# Date: 2026-03-23

extends Label

# Floating damage number — spawned at hit position, floats up and fades.
# Usage: instantiate, set text to damage amount, add to scene at hit position.

const FLOAT_SPEED  := 55.0   # pixels per second upward
const LIFETIME     := 0.7    # seconds

var _elapsed := 0.0

func _ready() -> void:
	# Style (hardcoded for prototype)
	add_theme_font_size_override("font_size", 16)
	add_theme_color_override("font_color", Color.YELLOW)
	add_theme_color_override("font_shadow_color", Color.BLACK)
	add_theme_constant_override("shadow_offset_x", 1)
	add_theme_constant_override("shadow_offset_y", 1)

func _process(delta: float) -> void:
	_elapsed += delta
	position.y -= FLOAT_SPEED * delta
	modulate.a = 1.0 - (_elapsed / LIFETIME)
	if _elapsed >= LIFETIME:
		queue_free()

# Factory method — call this to spawn a damage number in the scene.
static func spawn(scene_root: Node, amount: int, world_pos: Vector2) -> void:
	var label := Label.new()
	label.set_script(load("res://prototypes/combat/DamageNumber.gd"))
	label.text = str(amount)
	label.position = world_pos + Vector2(randf_range(-10, 10), -20)
	scene_root.add_child(label)
