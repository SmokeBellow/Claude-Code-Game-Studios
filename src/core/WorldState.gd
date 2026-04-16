extends Node
## Централизованное хранилище состояния игрового мира.
## Implements: design/gdd/world-state.md
##
## Хранит три категории данных:
##   - flags      : Dictionary[String, bool]  — булевые события (квесты, двери, триггеры)
##   - reputation : Dictionary[String, int]   — репутация по локациям (min = 0)
##   - shop_stock : Array[String]             — item_id текущего ассортимента магазина
##
## Эмитирует сигналы при каждом изменении. Подписчики реагируют сами.
## Персистируется через SaveSystem (serialize / deserialize).
## Не валидирует бизнес-логику — только хранит и уведомляет.

# ---------------------------------------------------------------------------
# Сигналы
# ---------------------------------------------------------------------------

signal flag_changed(key: String, value: bool)
signal reputation_changed(location_id: String, new_value: int)
signal shop_stock_changed()

# ---------------------------------------------------------------------------
# Хранилище
# ---------------------------------------------------------------------------

var _flags:      Dictionary = {}   # String → bool
var _reputation: Dictionary = {}   # String → int  (всегда >= 0)
var _shop_stock: Array      = []   # Array[String]

# ---------------------------------------------------------------------------
# Flags API
# ---------------------------------------------------------------------------

## Устанавливает булевый флаг и эмитирует flag_changed.
func set_flag(key: String, value: bool) -> void:
	_flags[key] = value
	flag_changed.emit(key, value)


## Возвращает значение флага. Если ключ не существует — возвращает [param default].
func get_flag(key: String, default: bool = false) -> bool:
	return _flags.get(key, default)

# ---------------------------------------------------------------------------
# Reputation API
# ---------------------------------------------------------------------------

## Устанавливает репутацию в локации (зажато в min 0).
func set_reputation(location_id: String, value: int) -> void:
	var clamped := maxi(0, value)
	_reputation[location_id] = clamped
	reputation_changed.emit(location_id, clamped)


## Возвращает репутацию в локации. Если локация не существует — возвращает 0.
func get_reputation(location_id: String) -> int:
	return _reputation.get(location_id, 0)


## Добавляет delta к репутации локации (результат зажат в min 0).
func add_reputation(location_id: String, delta: int) -> void:
	var current := get_reputation(location_id)
	set_reputation(location_id, current + delta)

# ---------------------------------------------------------------------------
# Shop Stock API
# ---------------------------------------------------------------------------

## Заменяет текущий ассортимент магазина списком item_id.
func set_shop_stock(items: Array) -> void:
	_shop_stock = items.duplicate()
	shop_stock_changed.emit()


## Возвращает копию текущего ассортимента.
func get_shop_stock() -> Array:
	return _shop_stock.duplicate()

# ---------------------------------------------------------------------------
# Reset
# ---------------------------------------------------------------------------

## Очищает всё состояние до начальных значений (New Game).
func reset() -> void:
	_flags.clear()
	_reputation.clear()
	_shop_stock.clear()

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

## Сериализует состояние в Dictionary для SaveSystem.
func serialize() -> Dictionary:
	return {
		"flags":      _flags.duplicate(),
		"reputation": _reputation.duplicate(),
		"shop_stock": _shop_stock.duplicate(),
	}


## Восстанавливает состояние из Dictionary (SaveSystem).
## Отсутствующие ключи заполняются дефолтами — нет ошибки на старых сейвах.
func deserialize(data: Dictionary) -> void:
	_flags      = data.get("flags",      {})
	_reputation = data.get("reputation", {})
	_shop_stock = data.get("shop_stock", [])
	# Гарантируем правильный тип (на случай загрузки из JSON)
	if not (_flags      is Dictionary): _flags      = {}
	if not (_reputation is Dictionary): _reputation = {}
	if not (_shop_stock is Array):      _shop_stock = []
	# Зажимаем репутацию в min 0 после загрузки
	for loc_id: String in _reputation.keys():
		_reputation[loc_id] = maxi(0, int(_reputation[loc_id]))
