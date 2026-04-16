# Состояние мира (World State)

> **Status**: In Design
> **Author**: User + Claude
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 2 (Живой мир)

## Overview

World State — централизованное хранилище состояния игрового мира: флаги событий, репутация игрока в локациях, ассортимент магазина и любые другие данные, которые должны сохраняться между комнатами, данжами и сессиями. Реализован как Autoload-синглтон (`WorldState.gd`) в Godot. Предоставляет унифицированный API: `set_flag()` / `get_flag()` для булевых событий и typed-словари для структурированных данных (reputation, shop_stock). Эмитирует сигналы при изменении данных — подписчики (Shop, Dialogue, NPC) реагируют мгновенно. Персистируется через SaveSystem.

## Player Fantasy

World State — невидимая система. Игрок никогда не взаимодействует с ней напрямую. Она работает правильно когда: NPC помнит что ты сделал в прошлый визит, цены в магазине снизились после выполненных квестов, дверь которую открыл три данжа назад — всё ещё открыта. Игрок чувствует это как «живой мир» — не как технический компонент.

## Detailed Design

### Core Rules

**Архитектура:**
1. `WorldState` — Godot Autoload (`project.godot`: `WorldState="*res://src/core/WorldState.gd"`)
2. Хранит три категории данных:
   - **Flags** `Dictionary[String, bool]` — булевые события (`"quest_elder_done"`, `"door_room_3_open"`)
   - **Reputation** `Dictionary[String, int]` — репутация по локациям (`"town" → 0..9+`)
   - **Shop Stock** `Array[String]` — item_id'ы текущего ассортимента магазина
3. Любое изменение данных эмитирует соответствующий сигнал — подписчики сами решают как реагировать
4. WorldState не валидирует бизнес-логику — он только хранит и уведомляет; логика живёт в вызывающих системах
5. При старте новой игры — `reset()` очищает все данные до начальных значений

**API (публичные методы):**
```
set_flag(key: String, value: bool) → void
get_flag(key: String, default: bool = false) → bool
set_reputation(location_id: String, value: int) → void
get_reputation(location_id: String) → int
add_reputation(location_id: String, delta: int) → void
set_shop_stock(items: Array[String]) → void
get_shop_stock() → Array[String]
reset() → void
serialize() → Dictionary
deserialize(data: Dictionary) → void
```

**Сигналы:**
```
signal flag_changed(key: String, value: bool)
signal reputation_changed(location_id: String, new_value: int)
signal shop_stock_changed()
```

### States and Transitions

World State — stateless хранилище, не имеет состояний конечного автомата. Жизненный цикл:

```
UNINITIALIZED  →  ACTIVE   : _ready() в Autoload; вызывается при старте игры
ACTIVE         →  RESET    : reset() при New Game
ACTIVE         →  SAVED    : SaveSystem вызывает serialize()
SAVED          →  ACTIVE   : SaveSystem вызывает deserialize() при загрузке
RESET          →  ACTIVE   : после reset() система снова готова к работе
```

**Начальные значения при reset():**
- `flags = {}` (пустой словарь)
- `reputation = {}` (все локации начинают с 0, возвращается через default)
- `shop_stock = []` (Shop генерирует новый при входе в город)

### Interactions with Other Systems

| Система | Направление | Интерфейс | Что передаётся |
|---------|-------------|-----------|---------------|
| **Quest System** | downstream → | `set_flag()`, `get_flag()`, `add_reputation()` | Флаги завершения квестов; прирост репутации |
| **Shop** | downstream → | `get_reputation()`, `get_shop_stock()`, `set_shop_stock()` | Скидка по репутации; ассортимент сессии |
| **Dialogue System** | downstream → | `get_flag()` | Проверка флагов для выбора ветки диалога |
| **NPC System** | downstream → | `get_flag()`, `get_reputation()` | Реакция NPC на события; смена диалога |
| **Room Structure** | downstream → | `get_flag()`, `set_flag()` | Флаги открытых дверей, активированных триггеров |
| **SaveSystem** | ↔ bidirectional | `serialize()`, `deserialize()` | Полный снимок состояния |
| **Achievements** | downstream → | `get_flag()`, `get_reputation()` | Проверка условий достижений |

## Formulas

World State не содержит вычислительной логики — только хранение. Все формулы живут в вызывающих системах:

- **Репутационный уровень**: вычисляется в Quest System: `KNOWN ≥ 2, RESPECTED ≥ 5, HONORED ≥ 9`
- **Скидка магазина**: вычисляется в Shop: `discount = reputation_level × 0.05`
- **Размер flags словаря**: не ограничен; ориентировочно ~50–200 флагов за полную игру

## Edge Cases

1. `get_flag()` для несуществующего ключа → возвращает `default` (false); не бросает ошибку
2. `get_reputation()` для несуществующей локации → возвращает `0`
3. `add_reputation()` с отрицательным delta → репутация зажата в `0` через `max(0, current + delta)`
4. Два вызова `set_flag()` с одним ключом в одном кадре → второй перезаписывает первый; сигнал эмитируется дважды — подписчики должны быть идемпотентны
5. `deserialize()` с неполными данными (старый сейв) → недостающие ключи заполняются дефолтами; нет ошибки
6. `reset()` во время активного квеста → флаги сбрасываются; Quest System обрабатывает это как новую игру
7. `shop_stock` содержит несуществующий `item_id` → Shop логирует предупреждение, пропускает предмет

## Dependencies

| Система | Тип зависимости | Направление |
|---------|----------------|-------------|
| **SaveSystem** | Hard — без него данные не переживают сессию | downstream |
| **Quest System** | Hard (потребитель) — пишет флаги и репутацию | upstream |
| **Shop** | Hard (потребитель) — читает репутацию и stock | upstream |
| **Dialogue System** | Soft (потребитель) — читает флаги для веток | upstream |
| **NPC System** | Soft (потребитель) — читает флаги и репутацию | upstream |
| **Room Structure** | Soft (потребитель) — читает/пишет флаги комнат | upstream |

*World State сам ни от чего не зависит — Foundation layer.*

## Tuning Knobs

World State — инфраструктурная система без балансовых параметров. Единственные настраиваемые аспекты:

| Knob | Текущее | Диапазон | Эффект |
|------|---------|---------|--------|
| `reputation` min | 0 | 0 или без ограничения | Может ли репутация уходить в минус |
| Namespace флагов | свободный (`"quest_X_done"`) | — | Конвенция именования; задаётся командой, не движком |
| Формат сериализации | GDScript Dictionary → JSON | — | Влияет на читаемость сейв-файла |

## Acceptance Criteria

1. `WorldState.set_flag("test", true)` → `WorldState.get_flag("test")` возвращает `true`; сигнал `flag_changed("test", true)` эмитирован
2. `WorldState.get_flag("nonexistent")` → возвращает `false` без ошибки
3. `WorldState.add_reputation("town", 3)` → `get_reputation("town")` возвращает `3`; сигнал `reputation_changed("town", 3)` эмитирован
4. `WorldState.add_reputation("town", -100)` → `get_reputation("town")` возвращает `0` (зажато в min)
5. `WorldState.reset()` → все флаги, репутация, shop_stock очищены до начальных значений
6. `serialize()` → возвращает Dictionary; `deserialize(dict)` → состояние восстановлено идентично
7. `deserialize()` со старым сейвом (нет ключа `shop_stock`) → не бросает ошибку; инициализируется пустым массивом
8. Shop подписан на `reputation_changed` → при `add_reputation()` цены в открытом UI пересчитываются без перезагрузки сцены

## Open Questions

- **Флаги комнат**: хранить в WorldState (глобально) или в отдельном `DungeonState` (per-run)? Если данж сбрасывается при новом запуске — флаги комнат не нужны в глобальном хранилище
- **Версионирование сейвов**: при добавлении нового флага в будущей версии — как обрабатывать старые сейвы без него?
- **Namespace конвенция**: нужен ли формальный список допустимых ключей (enum или константы), или свободные строки достаточны для MVP?
