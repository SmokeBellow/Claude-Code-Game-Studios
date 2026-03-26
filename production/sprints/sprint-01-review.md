# Sprint 1 Review — 2026-03-25

## Sprint Goal — Выполнен ✅

Установить производственную кодовую базу в Godot 4.6 и реализовать две фундаментальные системы.

---

## Завершённые задачи

| ID | Задача | Статус | Примечания |
|----|--------|--------|-----------|
| S1-01 | Настройка проекта Godot 4.6 | ✅ | `project.godot`, структура `src/assets/scenes/tests/`, `.gitignore` |
| S1-02 | Движение игрока | ✅ | 8 направлений, нормализация, sprint ×1.5, facing к курсору, инерция |
| S1-03 | HealthComponent + StatsComponent | ✅ | HP=100 при ур.1, реген с задержкой 3с, сигнал `died` |
| S1-04 | Камера | ✅ | Camera2D + lerp follow_speed=5.0 |
| S1-05 | Тестовая комната | ✅ | TileMapLayer с placeholder текстурой |

**Should Have — все выполнены** (вместилось в спринт).

---

## Delivery

| Файл | Описание |
|------|---------|
| `src/gameplay/Player.gd` | CharacterBody2D, движение, sprint, facing |
| `src/core/StatsComponent.gd` | 6 атрибутов, кап-функция, все производные статы |
| `src/core/HealthComponent.gd` | HP/мана, take_damage, heal, реген, died |
| `src/gameplay/GameCamera.gd` | Lerp-следование за целью |
| `project.godot` | Godot 4.6, GL Compatibility, все input actions |

---

## Что работает (подтверждено вручную)

- WASD — 8-направленное движение ✅
- Диагональ без ускорения ✅
- Sprint (Shift) ×1.5 ✅
- HP уменьшается при `take_damage()`, `died` испускается при HP=0 ✅
- Движение блокируется при `on_died()` ✅
- Камера следует за игроком плавно ✅

---

## Проблемы и решения

| Проблема | Решение |
|---------|---------|
| Sprint keycode в project.godot: поставлен Ctrl (4194326) вместо Shift (4194325) | Исправлено через Project Settings → Input Map |
| Персонаж рисуется под тайлами | Z Index Player = 1 |

---

## Carryover в Sprint 2

*Нет — все задачи закрыты.*

---

## Sprint 2 Preview

- **S2-01**: Боевая система (#9) — перенос из `prototypes/combat/` в `src/`, интеграция с HealthComponent
- **S2-02**: Система способностей (#10) — AbilityResource, слоты E+Q, способности Воина
- **S2-03**: AI врагов (#11) — NavigationAgent2D, 3 архетипа, EnemyData.tres
