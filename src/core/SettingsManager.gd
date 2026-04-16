extends Node

## Управление пользовательскими настройками (окно, звук и т.д.).
## Сохраняется в user://settings.cfg через ConfigFile.
## Зарегистрирован как Autoload — работает во всех сценах.
## F11 — переключить полноэкранный режим.

const _SAVE_PATH := "user://settings.cfg"
const _SECTION   := "display"

var _fullscreen: bool = false


func _ready() -> void:
	_load()
	_apply_window_mode()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			_fullscreen = not _fullscreen
			_apply_window_mode()
			_save()
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------

func _apply_window_mode() -> void:
	if _fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_SAVE_PATH) != OK:
		return
	_fullscreen = bool(cfg.get_value(_SECTION, "fullscreen", false))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(_SECTION, "fullscreen", _fullscreen)
	cfg.save(_SAVE_PATH)
