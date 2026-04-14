# Sprint 7 — 2026-03-31 — 2026-04-13

## Sprint Goal

Сделать игру ощутимо живой и законченной: работающая экипировка влияет на статы, базовые звуки присутствуют, технический долг закрыт. К концу спринта игра проходится от меню до победы с ощущением прогресса.

## Capacity

- Формат: разработка с Claude (3–5 сессий, ~6–8 часов суммарно)
- Старт: **2026-03-31**
- Конец: **2026-04-13**

> **Velocity Sprint 6**: 3 Must Have (Win/GameOver/MainMenu) + UIStyle + система классов + VFX всех умений + HUD кулдауны.
> Sprint 7 фокусируется на глубине (предметы с эффектом, звук) а не на ширине.

---

## Carryover из Sprint 6

| Задача | Причина переноса | Новая оценка |
|--------|-----------------|-------------|
| S6-04: Убрать debug `print()` | Не критично, откладывалось | 0.5 ч |
| S6-05: NavigationRegion2D per-room | Сложно, не блокирует геймплей | Перенос в S7 Should Have |
| S6-06: Элитная комната | Не начата | Перенос в S7 Nice to Have |
| S6-07: Archer (дальний враг) | Не начата | Перенос в S7 Nice to Have |

---

## Tasks

### Must Have (Critical Path)

| ID | Задача | Агент/Владелец | Оценка (ч) | Зависимости | Acceptance Criteria |
|----|--------|----------------|-----------|-------------|-------------------|
| S7-01 | **Экипировка → статы**: `ItemResource` с полем `stat_bonuses: Dictionary` (phys_dmg, max_hp, move_speed…). `StatsComponent` читает экипированные предметы из `PlayerData.equipment`. SidePanel/Экипировка показывает реальные слоты (Weapon/Armour/Ring) | godot-gdscript-specialist | 2.0 | ItemResource, StatsComponent, PlayerData | Надеть меч → физический урон вырос; снять → вернулся. SidePanel отображает надетый предмет |
| S7-02 | **Лут с реальными статами**: 3–5 предметов в `assets/data/items/` (меч, броня, кольцо) с заполненным `stat_bonuses`. LootTable лута босса содержит хотя бы один предмет | gameplay-programmer | 1.0 | S7-01, LootTable | Босс дропает предмет → подбираем → видим в инвентаре → надеваем → стат меняется |
| S7-03 | **Очистка print()**: убрать `print("ATTACK:")` в `BaseEnemy._tick_attack` и `print("PARRY START:")` в `CombatComponent._start_parry` | godot-gdscript-specialist | 0.2 | — | Output чист при нормальной игре |

**Итого Must Have: ~3.2 ч**

---

### Should Have

| ID | Задача | Агент/Владелец | Оценка (ч) | Зависимости | Acceptance Criteria |
|----|--------|----------------|-----------|-------------|-------------------|
| S7-04 | **Базовые SFX**: AudioManager autoload (4 звуковых шины). Placeholder звуки на: удар игрока, получение урона игроком, смерть врага, level-up. Звуки — `AudioStreamPlayer` с programmatic `AudioStreamGenerator` (тональный бип) если нет реальных файлов | audio-director | 1.5 | — | Каждое из 4 событий воспроизводит звук; нет ошибок в Output |
| S7-05 | **Баланс-проход**: пройти данж с каждым классом, зафиксировать tuning knobs в `design/balance/balance-sheet.md`. Скорректировать: cooldowns умений, урон Bash/Heavy/Fireball, HP врагов | game-designer | 1.0 | Классы реализованы | `balance-sheet.md` создан; цифры обоснованы плейтестом |
| S7-06 | **NavigationRegion2D per-room**: при загрузке комнаты — `NavigationServer2D.bake_from_source_geometry_data()` с полигоном текущей комнаты | godot-specialist | 1.0 | RoomManager._load_room | Враги не ходят сквозь стены соседних комнат |

**Итого Should Have: ~3.5 ч**

---

### Nice to Have

| ID | Задача | Агент/Владелец | Оценка (ч) | Зависимости | Acceptance Criteria |
|----|--------|----------------|-----------|-------------|-------------------|
| S7-07 | **Элитная комната** (`elite_room.tres`): враги с HP×2, урон×1.5, фиолетовый цвет комнаты | godot-gdscript-specialist | 1.0 | DungeonGenerator | 1–2 элитных комнаты в данже; враги сложнее; цвет отличается |
| S7-08 | **Archer (дальний враг)**: стрелок, `BaseEnemy` наследник, атака снарядом с 200px дистанции, отступает если игрок ≤ 80px | ai-programmer | 1.5 | BaseEnemy, PlayerProjectile | Archer стреляет снарядами; убегает от вплотную игрока |
| S7-09 | **Квест «Убей босса»**: `PlayerData.quest_kill_boss: bool`. Elder NPC даёт квест (DialogueScreen) → убийство Boss → `quest_kill_boss = true` → возврат к Elder → диалог завершения + gold reward | godot-gdscript-specialist | 1.5 | DialogueScreen, BossEnemy.enemy_died | Квест появляется у Elder; после победы — флаг снят; награда выдана |

---

## Risks

| Риск | Вероятность | Влияние | Митигация |
|------|------------|---------|-----------|
| StatsComponent не обновляется в реальном времени при экипировке | Средняя | Среднее | Использовать `stats_changed` сигнал; HealthComponent его уже слушает |
| AudioStreamGenerator — не самый простой API в Godot 4.6 | Средняя | Низкое | Если сложно — использовать `AudioStreamWAV` с 1-кадровым буфером; или сначала сделать AudioManager без звуков (инфраструктура) |
| Баланс-проход выявит крупный bug (например класс не работает на высоких уровнях) | Низкая | Высокое | Баланс в Should Have — можно отрезать если блокирует |
| R3 (контент занимает много времени) из Risk Register | Высокая | Среднее | MVP = только 5 предметов; не создавать больше |

---

## Dependencies on External Factors

- Звуковые файлы (.wav/.ogg) — если нет реальных ассетов, используем programmatic AudioStreamGenerator
- Project Settings → Audio → Default Bus Layout должен иметь Master bus (по умолчанию есть)

---

## Definition of Done для Sprint 7

- [ ] S7-01: Надетый предмет изменяет стат в реальном времени
- [ ] S7-02: Босс дропает предмет с реальным эффектом
- [ ] S7-03: Output чист (нет debug print при обычной игре)
- [ ] S7-04: 4 звуковых события работают (хотя бы placeholder)
- [ ] S7-05: `design/balance/balance-sheet.md` создан с числами из плейтеста
- [ ] Полный цикл без крашей: меню → данж → босс (дроп предмет) → победа
- [ ] Нет S1/S2 багов
- [ ] Sprint Review записан в `production/sprints/sprint-07-review.md`
