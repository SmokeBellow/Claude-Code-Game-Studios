# Prototype Report: Combat System

**Date:** 2026-03-24
**Engine:** Godot 4.6
**Status:** ✅ Playtest complete

---

## Hypothesis

Real-time top-down action combat with attacks (LMB), dodge (Space), and a nova
ability (RMB) directed toward the mouse cursor will feel satisfying and tactically
interesting as the foundation for a fantasy action-RPG.

---

## Approach

Minimal scene: blue square player vs 3 red square enemies. No art, no audio,
no story. Tested core feel: movement, attack, dodge, one ability.
Added HP bars, kill counter, visual feedback (flash on hit, visual hitbox).

Shortcuts taken: colored rectangles, hardcoded stats, no save/progression, single ability.

---

## Result

The core loop **functions and is testable**. Key observations:

- **Attack:** Works but noticeable delay. Hitbox fires correctly toward cursor.
  Cooldown not clearly communicated to the player.
- **Movement:** Speed feels correct (180px/s).
- **Enemies:** Too passive. Melee-only makes combat trivial. No variety.
- **Dodge:** Mechanically sound (i-frames work). Players use it offensively
  (dash toward enemies) rather than defensively — unexpected positive finding.
- **Nova ability:** Satisfying burst. Good onboarding mechanic. But players
  want meaningful ability *choices* quickly — single fixed ability feels limiting.
- **Overall:** Core loop functional. Monotony from lack of content/enemy variety,
  not from broken mechanics.

---

## Metrics

| Parameter | Current | Target |
|-----------|---------|--------|
| Attack cooldown | 0.4s | 0.25s |
| Dodge cooldown | 0.8s | OK |
| Ability cooldown | 3.0s | OK (needs visual bar) |
| Enemy HP | 60 | 120 |
| Enemy damage | 12 | 20 |
| Player HP | 100 | OK |

---

## Recommendation: ✅ PROCEED

The fundamental mechanics work. Delay and enemy passivity are **tuning problems,
not design problems**. The core fantasy — "grow powerful, defeat enemies with
skill" — is testable and the foundation holds.

---

## If Proceeding — Changes for Production

**Tuning (immediate):**
- Attack cooldown 0.4s → 0.25s
- Enemy HP 60 → 120, damage 12 → 20
- Ability cooldown bar (visual progress, not just text)

**Design implications:**
- **Enemies:** Separate aggro radius (detect) and de-aggro radius (lose sight).
  Add ranged attack variant. Even 2-3 archetypes (melee/ranged/tank) transforms depth.
- **Ability system:** Player needs ability choices within first 5 minutes.
  Nova is a starter — design upgrade/swap system early.
- **Dodge → Dash:** Reframe as offensive tool (gap-closer for melee, escape for
  ranged). Players naturally used it aggressively — lean into this.

**Architecture for production (rewrite from scratch):**
- Hitbox: Area2D with proper collision layers
- Enemy AI: state machine with configurable aggro/de-aggro params in data
- Ability system: data-driven from external config, not hardcoded
- Visual feedback: particles, screen shake, audio — critical for feel

---

## Lessons Learned

1. **Aggro/de-aggro radius** is a baseline player expectation — must be in
   the first enemy GDD.
2. **Ability variety** needs to come earlier than expected — single ability
   feels limiting within minutes.
3. **Dodge as dash** — design it as an offensive tool, not purely defensive.
4. **Cooldown visibility** is critical — players need to know *when* they can
   act, not just that a cooldown exists.
