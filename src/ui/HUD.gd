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
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	if health != null:
		_connect_health(health)
	if level_xp != null:
		_connect_level_xp(level_xp)

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



