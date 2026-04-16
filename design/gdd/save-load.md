# Сохранение / Загрузка (Save System)

> **Status**: In Design
> **Author**: User + Claude
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 2 (Живой мир) — мир помнит прогресс игрока

## Overview

SaveSystem — Autoload-оркестратор сохранения и загрузки игрового прогресса. Собирает снимки состояния от всех систем через их `serialize()` методы, объединяет в единый Dictionary и записывает в `user://save.json`. При загрузке читает файл, раздаёт данные каждой системе через `deserialize()`, затем вызывает restore-колбэки (восстановление пассивов, перерасчёт бонусов экипировки). MVP: один слот сохранения, автосейв при выходе из данжа и при возврате в город. Ручное сохранение недоступно.

## Player Fantasy

Игрок не думает о сохранении — оно происходит само. Вышел из данжа, вернулся в город — прогресс сохранён. Закрыл игру — открыл снова и всё на месте: уровень, инвентарь, квесты, репутация. SaveSystem работает правильно когда игрок о нём не думает вообще.

## Detailed Design

### Core Rules

**Сохранение:**
1. Автосейв срабатывает в двух точках: при возврате в город из данжа и при выходе из игры (через главное меню)
2. `SaveSystem.save()` вызывает `serialize()` у каждой системы, собирает в единый Dictionary, добавляет `save_version` и записывает в `user://save.json`
3. Один слот сохранения в MVP; предыдущий файл перезаписывается
4. Сохранение происходит синхронно — игра ждёт завершения записи перед переходом сцены

**Загрузка:**
5. При старте игры: если `user://save.json` существует → кнопка «Продолжить» активна; если нет → только «Новая игра»
6. `SaveSystem.load()` читает файл, проверяет `save_version`, раздаёт данные системам через `deserialize()`
7. После `deserialize()` SaveSystem вызывает restore-колбэки в строгом порядке:
   - `SkillTree._restore_passives()` — восстановление пассивных бонусов
   - `Inventory._reapply_equipment_bonuses()` — перерасчёт бонусов экипировки
   - `QuestSystem._restore_active_quests()` — восстановление счётчиков квестов
8. Новая игра: `SaveSystem.new_game()` вызывает `reset()` у всех систем, удаляет `user://save.json`, запускает стартовую сцену

**Структура файла сохранения:**
```json
{
  "save_version": 1,
  "player": {
    "level": 5,
    "current_xp": 340,
    "gold": 220,
    "player_class": "warrior",
    "quest_items": []
  },
  "skill_tree": {
    "skill_points": 2,
    "spent_points": { "general": 2, "warrior_berserker": 3 },
    "selected_spec": "warrior_berserker"
  },
  "inventory": {
    "backpack": [],
    "equipped": {},
    "hotkey_slots": []
  },
  "world_state": {
    "flags": { "quest_elder_done": true },
    "reputation": { "town": 3 },
    "shop_stock": []
  },
  "quests": {
    "active_quests": [],
    "completed_quests": []
  }
}
```

### States and Transitions

```
NO_SAVE_FILE   →  LOADING    : игрок нажимает «Продолжить»
LOADING        →  READY      : все системы десериализованы, колбэки вызваны
NO_SAVE_FILE   →  READY      : игрок нажимает «Новая игра» → reset() всех систем
READY          →  SAVING     : триггер автосейва (возврат в город / выход из игры)
SAVING         →  READY      : запись завершена успешно
SAVING         →  ERROR      : ошибка записи (нет места на диске и т.д.)
ERROR          →  READY      : игрок подтвердил ошибку; игра продолжается без сохранения
```

### Interactions with Other Systems

| Система | Направление | Интерфейс |
|---------|-------------|-----------|
| **World State** | downstream → | `WorldState.serialize()` / `deserialize()` |
| **Inventory** | downstream → | `Inventory.serialize()` / `deserialize()` → `_reapply_equipment_bonuses()` |
| **Level/XP System** | downstream → | читает/пишет `PlayerData.level`, `PlayerData.current_xp` |
| **Skill Tree** | downstream → | `SkillTree.serialize()` / `deserialize()` → `_restore_passives()` |
| **Quest System** | downstream → | `QuestSystem.serialize()` / `deserialize()` → `_restore_active_quests()` |
| **PlayerData** | downstream → | gold, player_class, quest_items — сериализуются напрямую |
| **SceneManager** | upstream → | вызывает `SaveSystem.save()` при переходе город↔данж |
| **Main Menu** | upstream → | вызывает `SaveSystem.load()` / `new_game()` / проверяет `has_save()` |

## Formulas

SaveSystem не содержит игровых формул. Технические параметры:

- **Размер файла сохранения**: ориентировочно 5–20 КБ (JSON с ~200 флагами, 20 предметами, деревом навыков)
- **Время записи**: < 16 мс на целевой платформе (синхронная запись не должна вызывать фриз)
- **`save_version`**: целое число, инкрементируется вручную при изменении структуры файла

## Edge Cases

1. Файл сохранения отсутствует при нажатии «Продолжить» → `has_save()` возвращает `false`; кнопка неактивна
2. Файл повреждён (невалидный JSON) → `load()` логирует ошибку, показывает диалог «Сохранение повреждено. Начать новую игру?»; не крашит игру
3. `save_version` в файле ниже текущей → недостающие ключи заполняются дефолтами через `deserialize()`
4. Нет места на диске при сохранении → `save()` возвращает `false`; предупреждение в UI; предыдущий файл не перезаписан (запись во временный файл с последующим rename)
5. Игра закрыта принудительно (kill process) → прогресс с последнего автосейва потерян; ожидаемое поведение
6. Restore-колбэки вызываются в строгом порядке: `_restore_passives()` → `_reapply_equipment_bonuses()` → `_restore_active_quests()`; нарушение порядка — ошибка реализации
7. Restore-колбэк бросает ошибку → SaveSystem логирует, продолжает остальные колбэки; игра запускается с предупреждением

## Dependencies

| Система | Тип зависимости | Интерфейс |
|---------|----------------|-----------|
| **World State** | Hard | `serialize()`, `deserialize()` |
| **Inventory** | Hard | `serialize()`, `deserialize()`, `_reapply_equipment_bonuses()` |
| **Level/XP System** | Hard | данные из PlayerData |
| **Skill Tree** | Hard | `serialize()`, `deserialize()`, `_restore_passives()` |
| **Quest System** | Hard | `serialize()`, `deserialize()`, `_restore_active_quests()` |
| **PlayerData** | Hard | центральный объект данных игрока |
| **SceneManager** | Soft — триггер сохранения | вызывает `save()` при переходе сцен |
| **Main Menu** | Soft — точка входа | вызывает `load()`, `new_game()`, `has_save()` |

## Tuning Knobs

| Knob | Текущее | Диапазон | Эффект |
|------|---------|---------|--------|
| Кол-во слотов сохранения | 1 | 1–3 | Больше = удобнее, сложнее UI |
| Автосейв триггеры | возврат в город + выход | расширяемо | Добавить: смерть, level-up, покупка |
| Формат файла | JSON | JSON / binary | JSON = читаем, binary = компактнее |
| `save_version` | 1 | инкремент | Версия для миграции старых сейвов |

## Acceptance Criteria

1. Выход из данжа в город → `user://save.json` создан/обновлён; содержит актуальные level, gold, inventory
2. Закрытие игры через главное меню → файл сохранён до закрытия
3. Повторный запуск → кнопка «Продолжить» активна; после загрузки: level, gold, equipped items, квесты — идентичны сохранённым
4. После загрузки: пассивные бонусы SkillTree применены к StatsComponent (`_restore_passives()` вызван)
5. После загрузки: бонусы экипировки применены (`_reapply_equipment_bonuses()` вызван); HUD показывает корректные статы
6. Повреждённый JSON → диалог ошибки; игра не крашит
7. Новая игра → `user://save.json` удалён; все системы сброшены; кнопка «Продолжить» неактивна при следующем старте
8. Запись при нехватке места на диске → предупреждение; предыдущий сейв не повреждён

## Open Questions

- **Автосейв при смерти?** Сейчас смерть не сохраняет — игрок воскрешает без потери прогресса кроме XP. Нужно ли сохранять состояние смерти?
- **Несколько слотов**: нужны ли в Vertical Slice или остаётся 1 слот до релиза?
- **Облачные сохранения**: Steam Cloud / платформенный sync — вне MVP, но архитектура должна это позволять
