class_name FloorManager
extends Node

## Управляет жизненным циклом этажей данжа.
## Заменяет RoomManager. Добавляется в main.tscn.

@export var player: CharacterBody2D
@export var melee_scene:  PackedScene
@export var ranged_scene: PackedScene
@export var elite_scene:  PackedScene
@export var boss_scene:   PackedScene

var _current_scene: FloorScene = null
var _current_floor: int = 0


func _ready() -> void:
	add_to_group("floor_manager")
	# Ждём один кадр чтобы Main._ready() успел инициализироваться
	await get_tree().process_frame
	enter_floor(1)


## Переходит на указанный этаж. Вызывается FloorPortal.
func enter_floor(floor_num: int) -> void:
	_current_floor = floor_num

	# Уничтожаем текущий этаж
	if _current_scene != null and is_instance_valid(_current_scene):
		_current_scene.queue_free()
		_current_scene = null

	# Загружаем статичную планировку
	var layout: FloorGenerator.FloorLayout
	match floor_num:
		1: layout = StaticFloorData.floor_1()
		2: layout = StaticFloorData.floor_2()
		3: layout = StaticFloorData.floor_3()
		_:
			push_error("FloorManager: неизвестный этаж %d" % floor_num)
			return

	# Создаём и настраиваем сцену этажа
	_current_scene = FloorScene.new()
	_current_scene.melee_scene  = melee_scene
	_current_scene.ranged_scene = ranged_scene
	_current_scene.elite_scene  = elite_scene
	_current_scene.boss_scene   = boss_scene
	add_child(_current_scene)
	_current_scene.setup(layout, floor_num)

	# Размещаем игрока
	if player != null:
		player.global_position = _current_scene.entry_world_pos()

	# Спавним врагов и объекты на следующем кадре
	_current_scene.spawn_entities.call_deferred()
