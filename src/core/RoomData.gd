class_name RoomData
extends Resource

## Описание комнаты: тип, возможные выходы, сцена-шаблон, враги.

enum RoomType { START, NORMAL, ELITE, BOSS }

## Тип комнаты.
@export_enum("START", "NORMAL", "ELITE", "BOSS") var room_type: int = RoomType.NORMAL

## Сцена-шаблон комнаты (*.tscn).
@export var scene: PackedScene

## Какие выходы есть у этой комнаты (север, юг, запад, восток).
@export var exits: Array[String] = []

## Максимум врагов для спавна в этой комнате.
@export var max_enemies: int = 3

## Сцены врагов для спавна (берутся случайно из списка).
@export var enemy_scenes: Array[PackedScene] = []

## Форма комнаты (задаётся RoomManager на основе exits при генерации).
var room_shape: int = 0  # Room.SHAPE_RECT
