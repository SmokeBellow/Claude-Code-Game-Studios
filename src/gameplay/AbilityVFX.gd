class_name AbilityVFX

## Фабрика визуальных эффектов классовых умений.
## Все методы статические — вызывай AbilityVFX.spawn_*(tree, position).
## Эффекты самоуничтожаются по окончании анимации.

# ---------------------------------------------------------------------------
# Warrior Bash — кольцо ударной волны
# ---------------------------------------------------------------------------

## Расширяющееся кольцо от позиции игрока до радиуса bash.
static func spawn_warrior_bash(tree: SceneTree, pos: Vector2, radius: float) -> void:
	var fx := _RingFX.new()
	fx.max_radius  = radius
	fx.ring_color  = Color(0.95, 0.45, 0.3)
	fx.duration    = 0.35
	tree.root.add_child(fx)
	fx.global_position = pos


# ---------------------------------------------------------------------------
# Warrior Fortify — пульсирующая золотая аура
# ---------------------------------------------------------------------------

## Золотистая аура вокруг игрока — 3 пульса за 1.2 секунды.
static func spawn_warrior_fortify(tree: SceneTree, pos: Vector2) -> void:
	var fx := _AuraFX.new()
	fx.aura_color  = Color(1.0, 0.85, 0.2)
	fx.aura_radius = 38.0
	fx.duration    = 1.2
	fx.pulse_count = 3
	tree.root.add_child(fx)
	fx.global_position = pos


# ---------------------------------------------------------------------------
# Rogue Smoke Bomb — облако дыма
# ---------------------------------------------------------------------------

## Серо-зелёное облако: несколько кругов разлетаются и гаснут.
static func spawn_rogue_smoke(tree: SceneTree, pos: Vector2, radius: float) -> void:
	var fx := _SmokeFX.new()
	fx.smoke_radius = radius
	fx.smoke_color  = Color(0.55, 0.55, 0.55)
	fx.duration     = 0.7
	tree.root.add_child(fx)
	fx.global_position = pos


# ---------------------------------------------------------------------------
# Mage Ice Hit — вспышка инея на враге
# ---------------------------------------------------------------------------

## Синяя вспышка + кристаллы вокруг точки попадания.
static func spawn_mage_ice_hit(tree: SceneTree, pos: Vector2) -> void:
	var fx := _IceFX.new()
	fx.hit_color = Color(0.5, 0.85, 1.0)
	fx.duration  = 0.5
	tree.root.add_child(fx)
	fx.global_position = pos


# ---------------------------------------------------------------------------
# Warrior Heavy — вспышка перед ударом (слот F)
# ---------------------------------------------------------------------------

## Красно-белая вспышка вокруг игрока — сигнал «следующий удар усилен».
static func spawn_warrior_heavy(tree: SceneTree, pos: Vector2) -> void:
	var fx := _FlashFX.new()
	fx.flash_color = Color(1.0, 0.3, 0.1)
	fx.flash_radius = 30.0
	fx.duration = 0.4
	tree.root.add_child(fx)
	fx.global_position = pos


# ---------------------------------------------------------------------------
# Mage Fireball Explosion — расширяющееся взрывное кольцо
# ---------------------------------------------------------------------------

## Оранжево-красное взрывное кольцо на месте попадания файербола.
static func spawn_mage_fireball_explosion(tree: SceneTree, pos: Vector2, radius: float) -> void:
	var fx := _FireballExplosionFX.new()
	fx.explosion_radius = radius
	fx.duration         = 0.5
	tree.root.add_child(fx)
	fx.global_position  = pos


# ---------------------------------------------------------------------------
# Mage Arcane Shield — дуги схлопывающегося щита
# ---------------------------------------------------------------------------

## Четыре синих дуги схлопываются к центру, затем вспышка — Магический щит активирован.
static func spawn_mage_arcane_shield(tree: SceneTree, pos: Vector2) -> void:
	var fx := _ArcaneShieldFX.new()
	fx.duration = 0.5
	tree.root.add_child(fx)
	fx.global_position = pos


# ---------------------------------------------------------------------------
# Rogue Fan Activation — веер вспышек перед игроком
# ---------------------------------------------------------------------------

## Пять коротких линий-вспышек в дуге 120° — активация Веера клинков.
static func spawn_rogue_fan_activation(tree: SceneTree, pos: Vector2, facing_dir: Vector2) -> void:
	var fx := _FanActivationFX.new()
	fx.facing   = facing_dir.normalized()
	fx.duration = 0.25
	tree.root.add_child(fx)
	fx.global_position = pos


# ===========================================================================
# Внутренние классы эффектов
# ===========================================================================

# ---------------------------------------------------------------------------
# _RingFX — расширяющееся кольцо
# ---------------------------------------------------------------------------

class _RingFX extends Node2D:
	var max_radius:  float = 100.0
	var ring_color:  Color = Color.WHITE
	var duration:    float = 0.35

	var _t: float = 0.0
	var _cur_radius: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		var progress: float = clampf(_t / duration, 0.0, 1.0)
		_cur_radius = max_radius * progress
		queue_redraw()
		if _t >= duration:
			queue_free()

	func _draw() -> void:
		var progress: float = clampf(_t / duration, 0.0, 1.0)
		var alpha: float = 1.0 - progress
		# Внешнее свечение
		draw_arc(Vector2.ZERO, _cur_radius + 4.0, 0.0, TAU,
				 48, Color(ring_color.r, ring_color.g, ring_color.b, alpha * 0.3), 8.0)
		# Основное кольцо
		draw_arc(Vector2.ZERO, _cur_radius, 0.0, TAU,
				 48, Color(ring_color.r, ring_color.g, ring_color.b, alpha), 3.0)


# ---------------------------------------------------------------------------
# _AuraFX — пульсирующая аура
# ---------------------------------------------------------------------------

class _AuraFX extends Node2D:
	var aura_color:  Color = Color.WHITE
	var aura_radius: float = 36.0
	var duration:    float = 1.2
	var pulse_count: int   = 3

	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t >= duration:
			queue_free()

	func _draw() -> void:
		var progress: float = clampf(_t / duration, 0.0, 1.0)
		# Пульс: sin даёт 0→1→0 несколько раз
		var pulse: float = abs(sin(progress * PI * pulse_count))
		var alpha: float = pulse * (1.0 - progress * 0.6)
		var r: float = aura_radius * (0.85 + pulse * 0.2)
		# Свечение
		draw_circle(Vector2.ZERO, r + 6.0,
				Color(aura_color.r, aura_color.g, aura_color.b, alpha * 0.2))
		# Кольцо
		draw_arc(Vector2.ZERO, r, 0.0, TAU,
				 48, Color(aura_color.r, aura_color.g, aura_color.b, alpha), 2.5)


# ---------------------------------------------------------------------------
# _SmokeFX — облако дыма из нескольких кругов
# ---------------------------------------------------------------------------

class _SmokeFX extends Node2D:
	var smoke_radius: float = 130.0
	var smoke_color:  Color = Color(0.4, 0.55, 0.4)
	var duration:     float = 0.7

	var _t: float = 0.0

	# Каждая частица: [offset: Vector2, radius: float, speed: Vector2, size: float]
	var _particles: Array = []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in 14:
			var angle: float = rng.randf() * TAU
			var dist: float  = rng.randf_range(0.0, smoke_radius * 0.5)
			var speed_angle: float = angle + rng.randf_range(-0.4, 0.4)
			var speed_mag: float   = rng.randf_range(smoke_radius * 0.5, smoke_radius * 1.1)
			var size: float        = rng.randf_range(14.0, 36.0)
			_particles.append([
				Vector2(cos(angle), sin(angle)) * dist,
				0.0,   # unused, kept for index alignment
				Vector2(cos(speed_angle), sin(speed_angle)) * speed_mag,
				size
			])

	func _process(delta: float) -> void:
		_t += delta
		for p in _particles:
			p[0] += (p[2] as Vector2) * delta
		queue_redraw()
		if _t >= duration:
			queue_free()

	func _draw() -> void:
		var progress: float = clampf(_t / duration, 0.0, 1.0)
		# Быстро появляется, медленно гаснет
		var alpha: float
		if progress < 0.15:
			alpha = progress / 0.15
		else:
			alpha = 1.0 - (progress - 0.15) / 0.85
		alpha *= 0.72

		# Изумрудный центральный ореол
		draw_circle(Vector2.ZERO, 20.0, Color(0.3, 0.85, 0.6, alpha * 0.6))

		for p in _particles:
			var offset: Vector2 = p[0] as Vector2
			var size: float     = p[3] as float
			draw_circle(offset, size,
					Color(smoke_color.r, smoke_color.g, smoke_color.b, alpha * 0.5))
			draw_arc(offset, size * 0.7, 0.0, TAU, 16,
					Color(smoke_color.r, smoke_color.g, smoke_color.b, alpha), 1.5)


# ---------------------------------------------------------------------------
# _IceFX — вспышка инея + кристаллы
# ---------------------------------------------------------------------------

class _IceFX extends Node2D:
	var hit_color: Color = Color(0.5, 0.85, 1.0)
	var duration:  float = 0.5

	var _t: float = 0.0
	# Кристаллы: [angle, length, width]
	var _crystals: Array = []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in 6:
			_crystals.append([
				rng.randf() * TAU,
				rng.randf_range(10.0, 22.0),
				rng.randf_range(2.5, 5.0)
			])

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t >= duration:
			queue_free()

	func _draw() -> void:
		var progress: float = clampf(_t / duration, 0.0, 1.0)
		var alpha: float = 1.0 - progress

		# Центральная вспышка
		var flash_r: float = 18.0 * (1.0 - progress * 0.5)
		draw_circle(Vector2.ZERO, flash_r,
				Color(hit_color.r, hit_color.g, hit_color.b, alpha * 0.35))
		draw_circle(Vector2.ZERO, flash_r * 0.5,
				Color(1.0, 1.0, 1.0, alpha * 0.6))

		# Кристаллы (линии от центра)
		for c in _crystals:
			var angle: float  = c[0] as float
			var length: float = (c[1] as float) * (0.3 + progress * 0.7)
			var width: float  = c[2] as float
			var tip: Vector2  = Vector2(cos(angle), sin(angle)) * length
			draw_line(Vector2.ZERO, tip,
					Color(hit_color.r, hit_color.g, hit_color.b, alpha), width)
			# Маленькая точка на кончике
			draw_circle(tip, width * 0.7,
					Color(1.0, 1.0, 1.0, alpha * 0.8))


# ---------------------------------------------------------------------------
# _FlashFX — круговая вспышка
# ---------------------------------------------------------------------------

class _FlashFX extends Node2D:
	var flash_color:  Color = Color.WHITE
	var flash_radius: float = 30.0
	var duration:     float = 0.4

	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t >= duration:
			queue_free()

	func _draw() -> void:
		var progress: float = clampf(_t / duration, 0.0, 1.0)
		# Быстрая вспышка: нарастает за 20%, гаснет за 80%
		var alpha: float
		if progress < 0.2:
			alpha = progress / 0.2
		else:
			alpha = 1.0 - (progress - 0.2) / 0.8

		var r: float = flash_radius * (0.6 + progress * 0.8)
		draw_circle(Vector2.ZERO, r,
				Color(flash_color.r, flash_color.g, flash_color.b, alpha * 0.25))
		draw_arc(Vector2.ZERO, r * 0.75, 0.0, TAU,
				 32, Color(flash_color.r, flash_color.g, flash_color.b, alpha), 2.0)


# ---------------------------------------------------------------------------
# _FireballExplosionFX — взрывное кольцо файербола
# ---------------------------------------------------------------------------

class _FireballExplosionFX extends Node2D:
	var explosion_radius: float = 120.0
	var duration:         float = 0.5

	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t >= duration:
			queue_free()

	func _draw() -> void:
		var progress: float = clampf(_t / duration, 0.0, 1.0)
		var alpha: float    = 1.0 - progress
		var cur_radius: float = explosion_radius * progress

		# Внутренний заполненный круг — гаснет за первые 30%
		var fill_alpha: float
		if progress < 0.3:
			fill_alpha = 1.0 - (progress / 0.3)
		else:
			fill_alpha = 0.0
		if fill_alpha > 0.0:
			draw_circle(Vector2.ZERO, cur_radius,
					Color(1.0, 0.7, 0.2, fill_alpha * 0.65))

		# Внешнее свечение
		draw_arc(Vector2.ZERO, cur_radius + 8.0, 0.0, TAU,
				 64, Color(1.0, 0.6, 0.0, alpha * 0.3), 12.0)
		# Основное кольцо
		draw_arc(Vector2.ZERO, cur_radius, 0.0, TAU,
				 64, Color(1.0, 0.45, 0.0, alpha), 3.0)


# ---------------------------------------------------------------------------
# _ArcaneShieldFX — четыре дуги щита, схлопываются + вспышка
# ---------------------------------------------------------------------------

class _ArcaneShieldFX extends Node2D:
	var duration: float = 0.5

	# Фаза 1: схлопывание дуг (0–0.3с)
	const _COLLAPSE_END:  float = 0.3
	# Фаза 2: вспышка центра (0.3–0.5с)
	const _RADIUS_START:  float = 50.0
	const _RADIUS_END:    float = 30.0
	const _ARC_COLOR:     Color = Color(0.45, 0.65, 1.0)

	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t >= duration:
			queue_free()

	func _draw() -> void:
		var progress: float = clampf(_t / duration, 0.0, 1.0)

		if _t < _COLLAPSE_END:
			# Фаза схлопывания: 4 дуги по ~80° (1.4 rad), равномерно по окружности
			var collapse_p: float = _t / _COLLAPSE_END
			var radius: float = lerpf(_RADIUS_START, _RADIUS_END, collapse_p)
			var alpha: float  = 1.0 - collapse_p * 0.3
			var arc_span: float = deg_to_rad(80.0)
			for i in 4:
				var arc_center: float = (TAU / 4.0) * float(i)
				var from_angle: float = arc_center - arc_span * 0.5
				draw_arc(Vector2.ZERO, radius, from_angle, from_angle + arc_span,
						 24, Color(_ARC_COLOR.r, _ARC_COLOR.g, _ARC_COLOR.b, alpha), 2.5)
		else:
			# Фаза вспышки центрального круга
			var flash_p: float = (_t - _COLLAPSE_END) / (duration - _COLLAPSE_END)
			var alpha: float   = 1.0 - flash_p
			draw_circle(Vector2.ZERO, _RADIUS_END,
					Color(0.7, 0.85, 1.0, alpha * 0.5))
			draw_arc(Vector2.ZERO, _RADIUS_END, 0.0, TAU,
					 32, Color(_ARC_COLOR.r, _ARC_COLOR.g, _ARC_COLOR.b, alpha), 2.0)


# ---------------------------------------------------------------------------
# _FanActivationFX — веер коротких вспышек-линий плута
# ---------------------------------------------------------------------------

class _FanActivationFX extends Node2D:
	var facing:   Vector2 = Vector2.RIGHT
	var duration: float   = 0.25

	const _LINE_COUNT:  int   = 5
	const _ARC_DEG:     float = 120.0
	const _LINE_COLOR:  Color = Color(0.8, 0.8, 0.2)

	var _t: float = 0.0
	# Каждая линия: [angle: float, length: float]
	var _lines: Array = []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var spread: float    = deg_to_rad(_ARC_DEG)
		var step: float      = spread / float(_LINE_COUNT - 1)
		var start: float     = facing.angle() - spread * 0.5
		for i in _LINE_COUNT:
			var angle: float  = start + step * float(i)
			var length: float = rng.randf_range(20.0, 30.0)
			_lines.append([angle, length])

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t >= duration:
			queue_free()

	func _draw() -> void:
		var progress: float = clampf(_t / duration, 0.0, 1.0)
		var alpha: float    = 1.0 - progress
		for l in _lines:
			var angle: float  = l[0] as float
			var length: float = l[1] as float
			var tip: Vector2  = Vector2(cos(angle), sin(angle)) * length
			draw_line(Vector2.ZERO, tip,
					Color(_LINE_COLOR.r, _LINE_COLOR.g, _LINE_COLOR.b, alpha), 2.0)
