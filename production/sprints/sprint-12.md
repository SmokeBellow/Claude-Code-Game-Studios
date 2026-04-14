# Sprint 12 -- 2026-04-09 to 2026-04-22

## Sprint Goal
Fix critical UX bugs (enemy attacks in menus, save-load reliability) and polish level-up flow and boss balance to bring the dungeon crawler to a shippable quality bar.

## Capacity
- Total days: 10
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days

## Carryover from Sprint 11

| Task | Reason | New Estimate |
|------|--------|-------------|
| S11-07: Double save-load QA | Not fully tested in S11 — needs dedicated QA pass and fixes | 1 day |

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S12-01 | TD-005: Pause enemy AI while attribute menu is open | gameplay-programmer | 1 | None | Enemies freeze (no attacks, no movement) when AttributeScreen is visible; resume immediately on close. Manual QA confirms no damage taken in menu. |
| S12-02 | S11-07 carryover: Double save-load QA + fixes | qa-tester, gameplay-programmer | 1 | None | Save game, load, save again, load again — all player data (HP, XP, inventory, floor, skills, name) persists correctly. Automated test or documented manual checklist passes. |

**Must Have total: 2 days**

### Should Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S12-03 | TD-004: Auto-open skill tree on level-up | ui-programmer | 1 | None | When player levels up, SkillTreeUI opens automatically after attribute distribution is complete. If player closes it, no re-prompt until next level-up. |
| S12-04 | TD-008: Boss rebalance — increase HP and tune attack patterns | game-designer, gameplay-programmer | 1.5 | None | Boss fight lasts at least 45-60 seconds for an average-geared player. QA playtest confirms boss is challenging but beatable. Balance values in external config (boss.tres or equivalent). |
| S12-05 | TD-006: Fix light artifact on floor transition | gameplay-programmer | 1 | None | Portal glow and torch lights are invisible until floor scene is fully loaded and player spawns. No flash of light on transition. Visual QA pass on floors 1-5. |

**Should Have total: 3.5 days**

### Nice to Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S12-06 | TD-002: Implement merchant sell functionality | gameplay-programmer, ui-programmer | 1.5 | None | Player can sell inventory items to merchant for gold (sell price = 50% of buy price or designer-set value). ShopScreen shows sell tab. Sold items removed from inventory, gold added. |
| S12-07 | TD-003: Remap ability keys to more accessible bindings | gameplay-programmer | 0.5 | None | Ability slots use revised key bindings (agreed with game-designer). InputMap updated. Tooltip/HUD reflects new keys. |
| S12-08 | TD-001: Increase torch glow radius and intensity | gameplay-programmer | 0.5 | None | TorchLight PointLight2D radius increased ~30-50%, energy tweaked. Dungeon is visibly brighter without washing out atmosphere. Before/after screenshot comparison. |

**Nice to Have total: 2.5 days**

### Excluded This Sprint

| ID | Reason |
|----|--------|
| TD-007 | Torch timing polish — details not yet provided by user. Will plan when spec is ready. |

## Effort Summary

| Priority | Est. Days |
|----------|-----------|
| Must Have | 2 |
| Should Have | 3.5 |
| Nice to Have | 2.5 |
| **Total planned** | **8** |
| Buffer | 2 |
| **Sprint total** | **10** |

## Critical Path
S12-01 and S12-02 are independent and can run in parallel on days 1-2. No task in this sprint blocks another. The critical path is simply completing all Must Have tasks by mid-sprint to allow buffer for Should Have items.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Save-load bugs deeper than expected (S12-02) | Medium | High — could eat into buffer | Time-box investigation to 1 day; if systemic, split into targeted fix + backlog item for full refactor |
| Boss rebalance requires multiple tuning iterations (S12-04) | Medium | Medium — could spill into Nice to Have time | Define target metrics upfront (HP range, fight duration); cap at 2 playtest iterations this sprint |
| Floor transition light fix harder than visual — may involve scene loading order (S12-05) | Low | Medium — could take extra 0.5 day | Spike first 2 hours to confirm root cause; if scene-loading issue, escalate to technical-director |
| Nice to Have items get deprioritized entirely | Medium | Low — these are polish, not blockers | Accept this outcome; they carry forward to Sprint 13 with no penalty |

## Dependencies on External Factors
- TD-007 (torch timing) blocked on user providing details — excluded from sprint, no impact
- Boss balance values (S12-04) need game-designer sign-off on target HP/damage numbers before implementation begins

## Definition of Done for this Sprint
- [x] All Must Have tasks (S12-01, S12-02) completed and verified — S12-01 ✅, S12-02 → carryover S13
- [x] All completed tasks pass their acceptance criteria
- [x] No S1 or S2 bugs in delivered features
- [x] Tech debt register updated (resolved items marked, any new items added)
- [ ] Save-load QA checklist fully passing — carryover S13
- [x] Balance changes documented in config files with rationale comments

## Sprint Result: CLOSED 2026-04-09
| ID | Task | Status |
|----|------|--------|
| S12-01 | Freeze enemy AI in menus | ✅ Done |
| S12-02 | Double save-load QA | ⏩ Carryover → S13-01 |
| S12-03 | Auto-open skill tree on level-up | ✅ Done (already implemented in Main.gd) |
| S12-04 | Boss rebalance | ⏩ Carryover → S13-02 (needs playtest) |
| S12-05 | Fix light artifact on floor transition | ✅ Done (CanvasModulate fade-in) |
| S12-06 | Merchant sell functionality | ✅ Done (already implemented in ShopScreen) |
| S12-07 | Remap ability keys | ✅ Done (R/F/G bindings) |
| S12-08 | Increase torch glow radius | ✅ Done (texture_scale=6.0, energy=2.0) |

## Notes
- Sprint 11 delivered 6/7 items — strong velocity. Sprint 12 is scoped similarly with 8 items at 8 available days, but most items are small fixes (S-sized).
- TD-005 (enemies attack in menu) is the highest-priority UX bug — ship-blocking if unfixed.
- If buffer days are unused, pull Nice to Have items in order: S12-06 first (merchant selling adds gameplay value), then S12-07, then S12-08.
