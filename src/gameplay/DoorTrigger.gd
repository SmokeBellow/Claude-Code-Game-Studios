class_name DoorTrigger
extends Area2D

## Триггер двери. Размести в сцене комнаты на каждом выходе.
## Заполни [member direction] и [member room_manager] в инспекторе.

## Направление этой двери: "north" / "south" / "west" / "east".
@export var direction: String = "north"
## Ссылка на RoomManager в сцене.
@export var room_manager: RoomManager

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if room_manager == null:
		push_error("DoorTrigger: room_manager не заполнен")
		return
	room_manager.on_door_entered(direction)
