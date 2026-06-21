class_name UIStyle

## Централизованные стили и цвета UI.
## Все экраны используют этот класс для единообразного оформления.
## Статические методы — не нужен экземпляр.

# ---------------------------------------------------------------------------
# Палитра
# ---------------------------------------------------------------------------

const COLOR_PANEL_BG:      Color = Color(0.14, 0.11, 0.07, 0.97)  # тёмный пергамент
const COLOR_PANEL_BORDER:  Color = Color(0.52, 0.38, 0.18, 0.90)  # тёплое золото
const COLOR_HEADING:       Color = Color(0.95, 0.78, 0.38)          # янтарь
const COLOR_TEXT:          Color = Color(0.85, 0.78, 0.65)          # кремовый
const COLOR_TEXT_DIM:      Color = Color(0.52, 0.46, 0.36)          # тёплый серый
const COLOR_SUCCESS:       Color = Color(0.55, 0.92, 0.55)          # зелёный
const COLOR_COOLDOWN:      Color = Color(1.0, 0.75, 0.3)
const COLOR_OVERLAY_MODAL: Color = Color(0.0, 0.0, 0.0, 0.70)
const COLOR_CLASS_WARRIOR: Color = Color(0.95, 0.45, 0.3)
const COLOR_CLASS_MAGE:    Color = Color(0.4, 0.6, 1.0)
const COLOR_CLASS_ROGUE:   Color = Color(0.3, 0.85, 0.6)
const COLOR_ERROR:         Color = Color(1.0, 0.40, 0.30)   # ошибки, предупреждения
const COLOR_DANGER:        Color = Color(0.90, 0.20, 0.20)  # поражение, опасность
const COLOR_SCENE_BG:      Color = Color(0.06, 0.04, 0.02)  # фон сцены (главное меню)

# ---------------------------------------------------------------------------
# Панели
# ---------------------------------------------------------------------------

## Тёмный пергамент + золотая рамка 1px + скругление 8px.
static func panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = COLOR_PANEL_BG
	s.border_color = COLOR_PANEL_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	return s

# ---------------------------------------------------------------------------
# Кнопки — четыре состояния
# ---------------------------------------------------------------------------

## Нормальное состояние кнопки.
static func btn_normal(border: Color = COLOR_PANEL_BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.20, 0.15, 0.09, 1.0)
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	return s


## Состояние hover.
static func btn_hover(border: Color = COLOR_PANEL_BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.30, 0.22, 0.12, 1.0)
	s.border_color = Color(border.r + 0.12, border.g + 0.10, border.b + 0.04, 1.0)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	return s


## Состояние pressed/toggled.
static func btn_pressed(border: Color = COLOR_PANEL_BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(border.r * 0.40, border.g * 0.30, border.b * 0.12, 1.0)
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	return s


## Состояние disabled.
static func btn_disabled() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.10, 0.06, 1.0)
	s.border_color = Color(0.28, 0.22, 0.14, 0.6)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
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
	var f := font_body()
	if f != null:
		btn.add_theme_font_override("font", f)

# ---------------------------------------------------------------------------
# Разделители
# ---------------------------------------------------------------------------

## Тёплая горизонтальная линия.
static func separator() -> HSeparator:
	var sep := HSeparator.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.45, 0.32, 0.10, 0.45)
	s.content_margin_top    = 1.0
	s.content_margin_bottom = 1.0
	sep.add_theme_stylebox_override("separator", s)
	return sep


## Стиль активной вкладки — подчёркивание снизу золотом.
static func tab_active_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.26, 0.20, 0.10, 1.0)
	s.border_color = COLOR_PANEL_BORDER
	s.set_border_width_all(0)
	s.border_width_bottom = 2
	s.set_corner_radius_all(0)
	return s


## Стиль неактивной вкладки — прозрачный фон.
static func tab_normal_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	s.set_border_width_all(0)
	s.set_corner_radius_all(0)
	return s

# ---------------------------------------------------------------------------
# Шрифты (ленивая загрузка, fallback на дефолтный шрифт Godot)
# ---------------------------------------------------------------------------

static var _font_heading: Font = null
static var _font_body: Font = null
static var _fonts_loaded: bool = false

static func _ensure_fonts() -> void:
	if _fonts_loaded:
		return
	_fonts_loaded = true
	const H := "res://assets/fonts/CormorantGaramond-Regular.ttf"
	const B := "res://assets/fonts/Lora-Regular.ttf"
	if ResourceLoader.exists(H):
		_font_heading = load(H)
	if ResourceLoader.exists(B):
		_font_body = load(B)


## Шрифт заголовков (CormorantGaramond). Возвращает null если файл не добавлен — UI работает с дефолтом.
static func font_heading() -> Font:
	_ensure_fonts()
	return _font_heading


## Шрифт основного текста (Lora). Возвращает null если файл не добавлен.
static func font_body() -> Font:
	_ensure_fonts()
	return _font_body


## Применяет стиль заголовка к Label: цвет + размер + шрифт.
static func apply_heading(lbl: Label, size: int = 18) -> void:
	lbl.add_theme_color_override("font_color", COLOR_HEADING)
	lbl.add_theme_font_size_override("font_size", size)
	var f := font_heading()
	if f != null:
		lbl.add_theme_font_override("font", f)


## Применяет стиль обычного текста к Label: цвет + размер + шрифт.
static func apply_text(lbl: Label, size: int = 14) -> void:
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	lbl.add_theme_font_size_override("font_size", size)
	var f := font_body()
	if f != null:
		lbl.add_theme_font_override("font", f)


## Применяет пергаментный стиль к полю ввода LineEdit.
static func apply_line_edit(le: LineEdit) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.08, 0.05, 1.0)
	normal.border_color = COLOR_PANEL_BORDER
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left   = 10.0
	normal.content_margin_right  = 10.0
	normal.content_margin_top    =  6.0
	normal.content_margin_bottom =  6.0
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = COLOR_HEADING
	focus.set_border_width_all(2)
	le.add_theme_stylebox_override("normal", normal)
	le.add_theme_stylebox_override("focus",  focus)
	le.add_theme_color_override("font_color",             COLOR_TEXT)
	le.add_theme_color_override("font_placeholder_color", COLOR_TEXT_DIM)
	le.add_theme_color_override("caret_color",            COLOR_HEADING)
	le.add_theme_color_override("selection_color",        Color(0.52, 0.38, 0.18, 0.45))
	var f := font_body()
	if f != null:
		le.add_theme_font_override("font", f)
