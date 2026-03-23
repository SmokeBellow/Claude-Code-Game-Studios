# Scene Setup — Combat Prototype

Инструкция для сборки сцены в Godot 4.6 редакторе.

## Дерево узлов

```
CombatPrototype (Node2D)          ← CombatPrototype.gd
├── Player (CharacterBody2D)      ← Player.gd, collision_layer=1, collision_mask=2
│   └── CollisionShape2D          (CircleShape2D, radius=14)
│
├── Enemies (Node2D)
│   ├── Enemy1 (CharacterBody2D)  ← Enemy.gd, collision_layer=4, collision_mask=1
│   │   └── CollisionShape2D      (CircleShape2D, radius=12)
│   ├── Enemy2 (CharacterBody2D)  ← Enemy.gd, то же
│   └── Enemy3 (CharacterBody2D)  ← Enemy.gd, то же
│
├── UI (CanvasLayer)
│   ├── PlayerHP (ProgressBar)    — якорь: top-left, size 200x20, pos (10,10)
│   ├── AbilityCD (Label)         — pos (10, 38)
│   └── KillCount (Label)         — pos (10, 60)
│
└── RespawnLabel (Label)          — center screen, visible=false
```

## Коллизионные слои

| Слой | Назначение |
|------|------------|
| 1    | Player     |
| 2    | Walls      |
| 3    | PlayerHitbox (временные Area2D от атак игрока) |
| 4    | Enemies    |

## Быстрый старт без арта

Для прототипа без спрайтов:
- Player: добавь `ColorRect` (синий, 28×28) как дочерний узел
- Enemy: добавь `ColorRect` (красный, 24×24) как дочерний узел
- Фон: добавь `ColorRect` на весь экран (тёмно-серый) ниже всех узлов

## Что проверить при тестировании

- [ ] Движение отзывчивое, без скольжения
- [ ] Атака чувствуется — враг реагирует мгновенно (flash + отход)
- [ ] Уклонение ощущается как эскейп, не как телепорт
- [ ] I-фреймы работают — урон во время dodge не проходит
- [ ] Ability (nova) сметает нескольких врагов — удовлетворяет?
- [ ] Числа урона читаемы и не мешают
- [ ] AI: враги патрулируют → замечают → преследуют → атакуют
- [ ] Смерть и перезапуск работают
