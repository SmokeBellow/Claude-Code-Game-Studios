class_name BlacksmithNPC
extends NPCBase

## Кузнец: продаёт оружие и броню.

@export var item_count: int = 6

func _ready() -> void:
	npc_name = "Кузнец"
	npc_color = Color(0.6, 0.4, 0.2)
	super._ready()
	_prompt_label.text = "[E] Снаряжение"


func interact() -> void:
	var dialogue := _get_dialogue()
	if dialogue == null:
		_open_shop()
		return

	var tree: Dictionary = {
		"start": {
			"speaker": "Кузнец",
			"portrait_color": Color(0.6, 0.4, 0.2),
			"text": "Добро пожаловать в кузницу! Лучшая сталь в этих краях — гарантирую.",
			"choices": [
				{"label": "Купить снаряжение", "next": "shop"},
				{"label": "Уйти", "next": ""},
			]
		},
		"shop": {
			"speaker": "Кузнец",
			"portrait_color": Color(0.6, 0.4, 0.2),
			"text": "Смотри, выбирай — всё сделано с душой.",
			"next": "__shop__"
		}
	}
	dialogue.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)
	dialogue.start(tree, "start")


func _on_dialogue_ended() -> void:
	var dialogue := _get_dialogue()
	if dialogue != null and (
		dialogue._current_node == "shop" or
		dialogue._current_node == "__shop__"
	):
		_open_shop()


func _open_shop() -> void:
	var shop := _get_shop()
	if shop == null:
		return
	var stock: Array[Dictionary] = _build_stock()
	shop.show_shop("Кузница", stock)


func _build_stock() -> Array[Dictionary]:
	var stock: Array[Dictionary] = []
	var db := _get_item_db()
	if db == null:
		return stock
	var all_items: Array = db.get_all_items()
	# Только оружие и броня
	var filtered: Array[ItemResource] = []
	for it: ItemResource in all_items:
		if it.slot == ItemResource.Slot.WEAPON or it.slot == ItemResource.Slot.ARMOR or it.slot == ItemResource.Slot.HELMET:
			filtered.append(it)
	filtered.shuffle()
	var count: int = mini(item_count, filtered.size())
	for i in range(count):
		var item: ItemResource = filtered[i]
		stock.append({"item": item, "price": item.sell_value() * 3, "quantity": 1})
	return stock


func _get_item_db() -> Node:
	var nodes := get_tree().get_nodes_in_group("item_db")
	return nodes[0] if not nodes.is_empty() else null


func _get_dialogue() -> DialogueScreen:
	var nodes := get_tree().get_nodes_in_group("dialogue_screen")
	return nodes[0] as DialogueScreen if not nodes.is_empty() else null


func _get_shop() -> ShopScreen:
	var nodes := get_tree().get_nodes_in_group("shop_screen")
	return nodes[0] as ShopScreen if not nodes.is_empty() else null
