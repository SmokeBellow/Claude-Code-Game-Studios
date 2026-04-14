## Technical Debt Register
Last updated: 2026-04-22
Total items: 0 open (8 resolved)

### Open

*Нет открытых долгов.*

### Resolved

| ID | Category | Description | Resolved In | How |
|----|----------|-------------|------------|-----|
| TD-007 | Polish | Неверный момент включения свечения факела | Sprint 15 | `WallTorch._ready()`: `_light.enabled = false` + raycast culling; артефакт TD-006 закрыт одновременно |
| TD-008 | Balance | Босс слишком лёгкий | Sprint 15 (S15-02) | HP-scaling `150 + 150×level^1.5`, DR=10%, плейтест подтвердил ≥45 сек боя |
| TD-001 | Polish | Слабое свечение вокруг игрока | Sprint 12 (S12-08) | `texture_scale=6.0`, `energy=2.0` на TorchLight |
| TD-002 | Feature | Торговец не принимал продажу предметов | Sprint 12 (S12-06) | Уже было реализовано в ShopScreen |
| TD-003 | Polish / UX | Неудобные кнопки умений | Sprint 12 (S12-07) | Переназначены на R/F/G |
| TD-004 | UX / Gameplay | Меню навыков не открывалось при левел-апе | Sprint 12 (S12-03) | Уже было реализовано в Main.gd |
| TD-005 | Bug | Враги атаковали игрока в меню атрибутов | Sprint 12 (S12-01) | `PROCESS_MODE_PAUSABLE` + `get_tree().paused` |
| TD-006 | Bug / Polish | Артефакт подсветки при переходе на этаж | Sprint 12 (S12-05) | `CanvasModulate` стартует с `Color.BLACK`, fade-in 0.3s |
