# Sprint 2 Review — 2026-03-25

## Sprint Goal — Выполнен ✅

Реализовать боевое ядро: атака, хитбоксы, вражеский AI и систему уровней/XP.

---

## Завершённые задачи

| ID | Задача | Статус | Примечания |
|----|--------|--------|-----------|
| S2-01 | CombatComponent — атака ЛКМ | ✅ | Area2D-like hitbox через группу "enemies", cooldown 0.4с, dodge+crit расчёт |
| S2-02 | EnemyBase + EnemyData | ✅ | Конечный автомат PATROL→CHASE→ATTACK_WINDUP→ATTACK→COOLDOWN→DEAD, NavigationAgent2D |
| S2-03 | LevelXPSystem | ✅ | XP от врагов, level_up сигнал, штраф смерти, overflow level_up |

**Should Have — не выполнялись** (достаточно времени осталось для Sprint 3).

---

## Delivery

| Файл | Описание |
|------|---------|
| `src/gameplay/CombatComponent.gd` | Атака ЛКМ, расчёт урона, cooldown, movement lock |
| `src/core/EnemyData.gd` | Resource: параметры врага (.tres) |
| `src/ai/BaseEnemy.gd` | Конечный автомат, NavigationAgent2D, aggro, смерть |
| `src/gameplay/LevelXPSystem.gd` | XP, level_up, штраф смерти, формулы |
| `src/gameplay/Main.gd` | Соединяет системы, auto-connect врагов |
| `src/core/HealthComponent.gd` | Обновлён: поддержка врагов без StatsComponent |

---

## Что работает (подтверждено вручную)

- ЛКМ наносит урон врагу ✅
- Cooldown атаки 0.4с соблюдается ✅
- Враг патрулирует → aggro → преследует → атакует ✅
- Урон от врага проходит через HealthComponent ✅
- Враг умирает и удаляется из дерева ✅
- XP начисляется при смерти врага (+10 XP Melee) ✅
- Death penalty: XP сбрасывается до floor текущего уровня ✅

---

## Проблемы и решения

| Проблема | Решение |
|---------|---------|
| HealthComponent assert(stats != null) ломал врагов | Добавлен `max_hp_override` + null-check на stats |
| Враг не находил игрока | Игрок не был в группе "player" |
| Враг не преследовал при aggro_angle=90° | Временно 360° для тестирования; по GDD 90° корректно |
| Attack range 60px — враг останавливается раньше из-за коллайдеров | Известный issue, коллайдеры нужно уменьшить |

---

## Carryover в Sprint 3

- Размеры коллайдеров игрока и врага (мешают ближнему бою)
- Should Have S2-04 (парирование) и S2-05 (DamageNumbers) перенесены

---

## Sprint 3 Preview

- **S3-01**: Парирование (ПКМ) — окно 0.35с, контрудар ×2, уязвимость 0.4с
- **S3-02**: DamageNumbers — всплывающие цифры урона
- **S3-03**: HUD — HP bar, мана bar, XP bar
- **S3-04**: Система способностей — AbilityResource, слоты E+Q, Dash (Q)
