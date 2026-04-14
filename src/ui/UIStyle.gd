class_name UIStyle

## Централизованные стили и цвета UI.
## Все экраны используют этот класс для единообразного оформления.
## Статические методы — не нужен экземпляр.

# ---------------------------------------------------------------------------
# Палитра
# ---------------------------------------------------------------------------

const COLOR_PANEL_BG:      Color = Color(0.09, 0.09, 0.13, 1.0)
const COLOR_PANEL_BORDER:  Color = Color(0.35, 0.28, 0.18, 0.9)
const COLOR_HEADING:       Color = Color(1.0, 0.85, 0.4)
const COLOR_TEXT:          Color = Color(0.85, 0.85, 0.85)
const COLOR_TEXT_DIM:      Color = Color(0.45, 0.45, 0.45)
const COLOR_SUCCESS:       Color = Color(0.5, 1.0, 0.6)
const COLOR_COOLDOWN:      Color = Color(1.0, 0.75, 0.3)
const COLOR_OVERLAY_MODAL: Color = Color(0.0, 0.0, 0.0, 0.78)
const COLOR_CLASS_WARRIOR: Color = Color(0.95, 0.45, 0.3)
const COLOR_CLASS_MAGE:    Color = Color(0.4, 0.6, 1.0)
const COLOR_CLASS_ROGUE:   Color = Color(0.3, 0.85, 0.6)

# ---------------------------------------------------------------------------
# Панели
# ---------------------------------------------------------------------------

## Тёмный фон + золотая рамка 1px + скругление 4px.
static func panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = COLOR_PANEL_BG
	s.border_color = COLOR_PANEL_BORDER
	s.border_width_left   = 1
	s.border_width_right  = 1
	s.border_width_top    = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left     = 4
	s.corner_radius_top_right    = 4
	s.corner_radius_bottom_left  = 4
	s.corner_radius_bottom_right = 4
	return s

# ---------------------------------------------------------------------------
# Кнопки — четыре состояния
# ---------------------------------------------------------------------------

## Нормальное состояние кнопки.
static func btn_normal(border: Color = COLOR_PANEL_BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.13, 0.13, 0.18, 1.0)
	s.border_color = border
	s.border_width_left   = 1
	s.border_width_right  = 1
	s.border_width_top    = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left     = 3
	s.corner_radius_top_right    = 3
	s.corner_radius_bottom_left  = 3
	s.corner_radius_bottom_right = 3
	return s


## Состояние hover.
static func btn_hover(border: Color = COLOR_PANEL_BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.20, 0.20, 0.27, 1.0)
	s.border_color = Color(border.r + 0.15, border.g + 0.12, border.b + 0.05, 1.0)
	s.border_width_left   = 1
	s.border_width_right  = 1
	s.border_width_top    = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left     = 3
	s.corner_radius_top_right    = 3
	s.corner_radius_bottom_left  = 3
	s.corner_radius_bottom_right = 3
	return s


## Состояние pressed/toggled.
static func btn_pressed(border: Color = COLOR_PANEL_BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(border.r * 0.35, border.g * 0.28, border.b * 0.15, 1.0)
	s.border_color = border
	s.border_width_left   = 2
	s.border_width_right  = 2
	s.border_width_top    = 2
	s.border_width_bottom = 2
	s.corner_radius_top_left     = 3
	s.corner_radius_top_right    = 3
	s.corner_radius_bottom_left  = 3
	s.corner_radius_bottom_right = 3
	return s


## Состояние disabled.
static func btn_disabled() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.09, 0.09, 0.12, 1.0)
	s.border_color = Color(0.22, 0.22, 0.22, 0.6)
	s.border_width_left   = 1
	s.border_width_right  = 1
	s.border_width_top    = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left     = 3
	s.corner_radius_top_right    = 3
	s.corner_radius_bottom_left  = 3
	s.corner_radius_bottom_right = 3
	return s


## Применяет все 4 стиля и цвета шрифта к кнопке.
static func apply_btn(btn: Button, border: Color = COLOR_PANEL_BORDER) -> void:
	btn.add_theme_stylebox_override("normal",   btn_normal(border))
	btn.add_theme_stylebox_override("hover",    btn_hover(border))
	btn.add_theme_stylebox_override("pressed",  btn_pressed(border))
	btn.add_theme_stylebox_override("disabled", btn_disabled())
	btn.add_theme_color_override("font_color",          COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color",    COLOR_HEADING)
	btn.add_theme_color_override("font_pressed_color",  COLOR_HEADING)
	btn.add_theme_color_override("font_disabled_color", COLOR_TEXT_DIM)

# ---------------------------------------------------------------------------
# Разделители
# ---------------------------------------------------------------------------

## Золотая горизонтальная линия.
static func separator() -> HSeparator:
	var sep := HSeparator.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.4, 0.32, 0.1, 0.5)
	s.content_margin_top    = 1.0
	s.content_margin_bottom = 1.0
	sep.add_theme_stylebox_override("separator", s)
	return sep
