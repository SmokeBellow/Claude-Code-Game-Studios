class_name HUD
extends CanvasLayer

## HUD игрока: HP бар, XP бар, номер уровня, кулдауны классовых умений.
## [br]
## Подключи [member health] и [member level_xp] в инспекторе,
## либо вызови [method connect_components] из Main.gd.

# ---------------------------------------------------------------------------
# Ссылки на компоненты (заполнить в инспекторе или через connect_components)
# ---------------------------------------------------------------------------

## HealthComponent игрока.
@export var health: HealthComponent
## Система уровней и XP.
@export var level_xp: LevelXPSystem

# ---------------------------------------------------------------------------
# Внутренние ссылки на узлы HUD (заполняются автоматически через @onready)
# ---------------------------------------------------------------------------

@onready var _hp_bar: ProgressBar       = $Container/VBox/HPBar
@onready var _xp_bar: ProgressBar       = $Container/VBox/XPBar
@onready var _level_label: Label        = $Container/VBox/LevelLabel
@onready var _hp_label: Label           = $Container/VBox/HPBar/HPLabel

# ---------------------------------------------------------------------------
# Блок кулдаунов умений (R / F / G) — строится программно
# ---------------------------------------------------------------------------

const _SLOT_SIZE:  float = 52.0
const _SLOT_GAP:   float = 6.0
const _KEY_NAMES:  Array[String] = ["R", "F", "G"]

## Цвета слотов по индексу (одинаковые для всех классов — различаются по ключу).
const _SLOT_COLORS: Array[Color] = [
	Color(0.95, 0.45, 0.3),   # R — воин (UIStyle.COLOR_CLASS_WARRIOR)
	Color(0.35, 0.65, 1.0),   # F — холодный синий
	Color(0.3,  0.85, 0.6),   # G — изумрудный (Плут), не конфликтует с «успехом»
]

var _ab_bg:      Array[ColorRect] = []
var _ab_overlay: Array[ColorRect] = []
var _ab_cd_lbl:  Array[Label]     = []
var _ab_key_lbl: Array[Label]     = []

## Кешированная ссылка на ClassAbilitySystem игрока (ищется лениво).
var _cas: ClassAbilitySystem = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	if health != null:
		_connect_health(health)
	if level_xp != null:
		_connect_level_xp(level_xp)
	_build_ability_bar()


func _process(_delta: float) -> void:
	_update_ability_bar()

# ---------------------------------------------------------------------------
# Публичный API
# ---------------------------------------------------------------------------

## Подключает компоненты программно (вызывается из Main.gd).
func connect_components(h: HealthComponent, lxp: LevelXPSystem) -> void:
	health = h
	level_xp = lxp
	_connect_health(h)
	_connect_level_xp(lxp)

# ---------------------------------------------------------------------------
# HP / XP
# ---------------------------------------------------------------------------

func _connect_health(h: HealthComponent) -> void:
	if not h.health_changed.is_connected(_on_health_changed):
		h.health_changed.connect(_on_health_changed)
	_on_health_changed(h.current_hp, h._get_max_hp())


func _connect_level_xp(lxp: LevelXPSystem) -> void:
	if not lxp.xp_updated.is_connected(_on_xp_updated):
		lxp.xp_updated.connect(_on_xp_updated)
	if not lxp.level_up.is_connected(_on_level_up):
		lxp.level_up.connect(_on_level_up)
	_on_xp_updated(lxp.current_xp, lxp.xp_to_next_level(lxp.current_level))
	_on_level_up(lxp.current_level, 0)


func _on_health_changed(current: float, maximum: float) -> void:
	if _hp_bar == null:
		return
	_hp_bar.max_value = maximum
	_hp_bar.value = current
	_hp_label.text = "%d / %d" % [int(current), int(maximum)]


func _on_xp_updated(current: int, xp_to_next: int) -> void:
	if _xp_bar == null:
		return
	_xp_bar.max_value = xp_to_next
	_xp_bar.value = current


func _on_level_up(current: int, _points: int) -> void:
	if _level_label == null:
		return
	_level_label.text = "Уровень %d" % current

# ---------------------------------------------------------------------------
# Панель умений — построение
# ---------------------------------------------------------------------------

func _build_ability_bar() -> void:
	var total_w: float = _SLOT_SIZE * 3.0 + _SLOT_GAP * 2.0

	var anchor := Control.new()
	anchor.set_anchor(SIDE_LEFT,   0.5)
	anchor.set_anchor(SIDE_RIGHT,  0.5)
	anchor.set_anchor(SIDE_TOP,    1.0)
	anchor.set_anchor(SIDE_BOTTOM, 1.0)
	anchor.set_offset(SIDE_LEFT,   -total_w * 0.5)
	anchor.set_offset(SIDE_RIGHT,   total_w * 0.5)
	anchor.set_offset(SIDE_TOP,    -80.0)
	anchor.set_offset(SIDE_BOTTOM, -8.0)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", int(_SLOT_GAP))
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(hbox)

	for i: int in range(3):
		var slot := _make_slot(i)
		hbox.add_child(slot)

		# Сохраняем ссылки: bg=child(0), overlay=child(1), key_lbl=child(2), cd_lbl=child(3)
		_ab_bg.append(slot.get_child(0) as ColorRect)
		_ab_overlay.append(slot.get_child(1) as ColorRect)
		_ab_key_lbl.append(slot.get_child(2) as Label)
		_ab_cd_lbl.append(slot.get_child(3) as Label)


func _make_slot(idx: int) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(_SLOT_SIZE, _SLOT_SIZE)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Фон
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.12, 0.12, 0.16, 0.92)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(bg)   # child(0)

	# Оверлей кулдауна (заполняет слот сверху вниз, убывает с кулдауном)
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.65)
	overlay.set_anchor(SIDE_LEFT,   0.0)
	overlay.set_anchor(SIDE_RIGHT,  1.0)
	overlay.set_anchor(SIDE_TOP,    0.0)
	overlay.set_anchor(SIDE_BOTTOM, 0.0)
	overlay.set_offset(SIDE_TOP,    0.0)
	overlay.set_offset(SIDE_BOTTOM, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(overlay)   # child(1)

	# Клавиша [R/F/G] — левый нижний угол
	var key_lbl := Label.new()
	key_lbl.text = "[%s]" % _KEY_NAMES[idx]
	key_lbl.add_theme_font_size_override("font_size", 12)
	key_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	key_lbl.set_anchor(SIDE_LEFT,   0.0)
	key_lbl.set_anchor(SIDE_RIGHT,  1.0)
	key_lbl.set_anchor(SIDE_TOP,    1.0)
	key_lbl.set_anchor(SIDE_BOTTOM, 1.0)
	key_lbl.set_offset(SIDE_TOP,    -16.0)
	key_lbl.set_offset(SIDE_BOTTOM, 0.0)
	key_lbl.set_offset(SIDE_LEFT,   2.0)
	key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(key_lbl)   # child(2)

	# Кулдаун / статус — по центру
	var cd_lbl := Label.new()
	cd_lbl.text = "?"
	cd_lbl.add_theme_font_size_override("font_size", 14)
	cd_lbl.add_theme_color_override("font_color", Color.WHITE)
	cd_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(cd_lbl)   # child(3)

	return slot

# ---------------------------------------------------------------------------
# Панель умений — обновление каждый кадр
# ---------------------------------------------------------------------------

func _update_ability_bar() -> void:
	# Ленивый поиск CAS
	if _cas == null or not is_instance_valid(_cas):
		for p: Node in get_tree().get_nodes_in_group("player"):
			_cas = p.get_node_or_null("ClassAbilitySystem") as ClassAbilitySystem
			if _cas != null:
				break

	var pc: int = PlayerData.player_class

	for i: int in range(3):
		var bg:      ColorRect = _ab_bg[i]
		var overlay: ColorRect = _ab_overlay[i]
		var cd_lbl:  Label     = _ab_cd_lbl[i]
		var base_color: Color  = _SLOT_COLORS[i]

		# Класс не выбран
		if pc == PlayerData.CLASS_NONE:
			bg.color = Color(0.12, 0.12, 0.16, 0.92)
			overlay.set_offset(SIDE_BOTTOM, _SLOT_SIZE)
			cd_lbl.text = "?"
			cd_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
			continue

		# Умение ещё не разблокировано
		if not PlayerData.ability_unlocked[i]:
			var unlock_lvl: int = (i + 1) * 3
			bg.color = Color(base_color.r * 0.2, base_color.g * 0.2, base_color.b * 0.2, 0.9)
			overlay.set_offset(SIDE_BOTTOM, _SLOT_SIZE)
			cd_lbl.text = "Lv%d" % unlock_lvl
			cd_lbl.add_theme_font_size_override("font_size", 11)
			cd_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			continue

		# Умение разблокировано
		bg.color = Color(base_color.r * 0.35, base_color.g * 0.35, base_color.b * 0.35, 0.95)

		if _cas == null:
			overlay.set_offset(SIDE_BOTTOM, 0.0)
			cd_lbl.text = "✓"
			cd_lbl.add_theme_color_override("font_color", base_color)
			continue

		var remaining: float = _cas.get_cooldown(i)
		var max_cd: float    = _cas.get_max_cooldown(i)

		if remaining > 0.0:
			# Кулдаун: оверлей убывает снизу вверх
			var ratio: float = remaining / max_cd
			overlay.set_offset(SIDE_BOTTOM, _SLOT_SIZE * ratio)
			cd_lbl.text = "%.0f" % ceilf(remaining)
			cd_lbl.add_theme_font_size_override("font_size", 16)
			cd_lbl.add_theme_color_override("font_color", UIStyle.COLOR_COOLDOWN)
		else:
			# Готово
			overlay.set_offset(SIDE_BOTTOM, 0.0)
			cd_lbl.text = "✓"
			cd_lbl.add_theme_font_size_override("font_size", 14)
			cd_lbl.add_theme_color_override("font_color", base_color)
