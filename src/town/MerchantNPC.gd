class_name MerchantNPC
extends NPCBase

## Торговец: продаёт зелья и случайные предметы, покупает лут игрока.

## Количество зелий в наличии (обновляется при каждом посещении города).
@export var potions_per_visit: int = 5
## Цена зелья.
@export var potion_price: int = 30
## Количество случайных предметов в ассортименте.
@export var random_item_count: int = 4

var _shop_screen: ShopScreen = null
var _dialogue_screen: DialogueScreen = null
var _stock_ready: bool = false
var _stock: Array[Dictionary] = []

func _ready() -> void:
	npc_name = "Торговец"
	npc_color = Color(0.3, 0.7, 0.4)
	super._ready()
	_prompt_label.text = "[E] Торговля"


func interact() -> void:
	_dialogue_screen = _get_dialogue()
	if _dialogue_screen == null:
		_open_shop_directly()
		return

	var tree: Dictionary = {
		"start": {
			"speaker": "Торговец",
			"portrait_color": Color(0.3, 0.7, 0.4),
			"text": "Приветствую, странник! Что желаешь? У меня найдётся всё, что нужно настоящему герою.",
			"choices": [
				{"label": "Посмотреть товары", "next": "shop"},
				{"label": "Ничего, спасибо", "next": ""},
			]
		},
		"shop": {
			"speaker": "Торговец",
			"portrait_color": Color(0.3, 0.7, 0.4),
			"text": "Отличный выбор! Свежий товар прямо из столицы.",
			"next": "__shop__"
		}
	}
	_dialogue_screen.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)
	_dialogue_screen.start(tree, "start")


func _on_dialogue_ended() -> void:
	# Если последний узел был "shop" или "__shop__" — открываем магазин
	if _dialogue_screen != null and (
		_dialogue_screen._current_node == "shop" or
		_dialogue_screen._current_node == "__shop__"
	):
		_open_shop_directly()


func _open_shop_directly() -> void:
	_shop_screen = _get_shop()
	if _shop_screen == null:
		return
	if not _stock_ready:
		_build_stock()
	_shop_screen.show_shop("Торговец", _stock)


func _build_stock() -> void:
	_stock.clear()
	# Зелья (фиксированное количество)
	_stock.append({"item": null, "price": potion_price, "quantity": potions_per_visit})
	# Случайные предметы из ItemDB
	var db := _get_item_db()
	if db != null:
		var all_items: Array = db.get_all_items()
		all_items.shuffle()
		var count: int = mini(random_item_count, all_items.size())
		for i in range(count):
			var item: ItemResource = all_items[i] as ItemResource
			var price: int = item.sell_value() * 3  # цена покупки = продажная × 3
			_stock.append({"item": item, "price": price, "quantity": 1})
	_stock_ready = true


func _get_item_db() -> Node:
	var nodes := get_tree().get_nodes_in_group("item_db")
	if nodes.is_empty():
		return null
	return nodes[0]


func _get_dialogue() -> DialogueScreen:
	var nodes := get_tree().get_nodes_in_group("dialogue_screen")
	if nodes.is_empty():
		return null
	return nodes[0] as DialogueScreen


func _get_shop() -> ShopScreen:
	var nodes := get_tree().get_nodes_in_group("shop_screen")
	if nodes.is_empty():
		return null
	return nodes[0] as ShopScreen
