class_name DoorTrigger
extends Area2D

## Триггер двери. Защита от двойного срабатывания — в RoomManager._is_transitioning.

## Направление этой двери: "north" / "south" / "west" / "east".
@export var direction: String = "north"
## Ссылка на RoomManager — выставляется RoomManager программно.
@export var room_manager: RoomManager


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if room_manager == null:
		push_error("DoorTrigger '%s': room_manager не заполнен" % direction)
		return
	room_manager.on_door_entered(direction)
