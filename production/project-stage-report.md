# Project Stage Analysis

**Date**: 2026-04-14
**Stage**: Production (Sprint 16 завершён, Sprint 17 не начат)
**Game**: Хроники одного героя — top-down action RPG
**Engine**: Godot 4.6 / GDScript

---

## Completeness Overview

| Область | % | Детали |
|---------|---|--------|
| Engine & Tech Setup | 100% | Godot 4.6, GDScript, worktree → merge в main запланирован |
| Core Game Loop | 95% | Город, данж, бой, лут, прокачка, сохранение — реализованы |
| Design Docs (GDD) | 60% | Документы были в earlier commits; нужно восстановить/обновить |
| Architecture (ADR) | 0% | Ни одного ADR; требуется по Coding Standards |
| Production Tracking | 90% | Backlog, 16 спринтов, ретроспективы — ведётся |
| Tests | 10% | Ручной QA-чеклист есть; автотестов нет |
| Tech Debt | 100% | 0 открытых долгов (8 закрыто) |

---

## Что реализовано

### Город
- Town.gd, 3 NPC (Merchant / Blacksmith / Elder), DungeonGate, ShopScreen
- Текстура травы: TileMapLayer, tile_size=205, TEXTURE_FILTER_NEAREST
- Основной TileMap: только стены периметра

### Данж — 3-этажная система
- **Sprint 16**: Статичный лабиринт (hand-crafted, DFS удалён)
- Этаж 1: спавн 40%, 1 враг/ячейку; зона входа без врагов
- Этаж 2: 5×4, элиты; Этаж 3: стражи → ворота → босс
- FloorManager: _floor_seeds[3], _all_killed_ids
- PuzzleDoor + PuzzleTrigger (рычаги → дверь, этаж 2)

### Бой и прокачка
- Способности, умения (SkillTree), баланс босса (HP = 150 + 150×level^1.5, DR=10%)
- Лут, инвентарь, AttributeScreen

### Освещение
- CanvasModulate BLACK + PointLight2D
- _build_occluders() — замкнутый полигон контура
- WallTorch: raycast culling, shadow_enabled=false
- Текстурные стены: wall_stone.png

### UI / Экраны
- HUD, SidePanel, PauseMenu, MainMenu, DialogueScreen, NameInputScreen
- WinScreen, GameOverScreen, DungeonMap (туман войны), AttributeScreen

### Сохранение
- SaveSystem v2: PlayerData + инвентарь + мировое состояние

### Настройки & Аудио
- SettingsManager (Autoload): F11 fullscreen, user://settings.cfg
- AudioManager: 5 синтезированных SFX

---

## Gaps

| # | Gap | Приоритет | Действие |
|---|-----|-----------|----------|
| G-01 | Код игры в worktree, не в `main` | **Critical** | Перенести в main; деплой в main каждую сессию |
| G-02 | ADR отсутствуют (0 записей) | High | Создать ADR для ключевых архитектурных решений |
| G-03 | GDD документы не в main-ветке | Medium | Восстановить/обновить design/gdd/ |
| G-04 | Автотесты отсутствуют | Medium | Минимум: balance formulas, save/load |
| G-05 | TD-001: тени inner walls данжа | Low | 6 подходов не сработали; попробовать SubViewport/custom shader |
| G-06 | Milestone Review не проводился | Medium | Провести после merge в main |

---

## Recommended Next Steps

### Немедленно (до Sprint 17)
1. **Merge worktree → main** — перенести код игры из `adoring-curie` в основную ветку
2. **Деплой-протокол** — закрепить правило: каждая сессия заканчивается merge в main

### Sprint 17 (запланировать)
3. **Milestone Review** — оценить готовность к beta/релизу после 16 спринтов
4. **ADR backfill** — задокументировать ключевые решения (SaveSystem, FloorGenerator, освещение)
5. **Content pass** — если core loop стабилен: новые уровни, враги, лут
6. **TD-001** (тени) — если есть пропускная способность

### Позднее
7. **GDD восстановление** — `/reverse-document design` для ключевых систем
8. **Автотесты** — balance formulas, save/load roundtrip

---

## Sprint History

| Спринт | Статус | Фокус |
|--------|--------|-------|
| Sprint 10–13 | ✅ | SaveSystem, XP, SkillTree, UI-экраны |
| Sprint 14 | ✅ | Освещение: occluders, smooth_corners, WallTorch |
| Sprint 15 | ✅ | Текстура стен, GameOver/Win экраны, QA save-load, ребаланс босса |
| Sprint 16 | ✅ | Статичный лабиринт (DFS→hand-crafted), fullscreen, цвет стен |
| Sprint 17 | ⬜ | Не начат |
