class_name ElderNPC
extends NPCBase

## Деревенский Старейшина: выдаёт квест на убийство Стража Данжа и принимает отчёт.

func _ready() -> void:
	npc_name = "Старейшина"
	npc_color = Color(0.7, 0.5, 0.8)
	super._ready()
	_prompt_label.text = "[E] Говорить"


func interact() -> void:
	var dialogue := _get_dialogue()
	if dialogue == null:
		return
	var tree := _build_tree()
	dialogue.start(tree, "start")


func _build_tree() -> Dictionary:
	var c := Color(0.7, 0.5, 0.8)
	var stage: int = PlayerData.quest_stage

	# Цепочка завершена
	if stage == 4:
		return {"start": {"speaker": "Старейшина", "portrait_color": c,
			"text": "Ты исполнил всё, о чём я просил. Данж усмирён. Наша деревня в безопасности — благодаря тебе!",
			"choices": [{"label": "Прощайте", "next": ""}]}}

	# Стадия 3 — сдать: босс убит
	if stage == 3 and PlayerData.quest_boss_killed:
		return {
			"start": {"speaker": "Старейшина", "portrait_color": c,
				"text": "Страж повержен! Ты сделал невозможное. Прими последнюю награду — %d золотых!" % PlayerData.QUEST_REWARD_3,
				"choices": [{"label": "Принять награду", "next": "reward3"}, {"label": "Позже", "next": ""}]},
			"reward3": {"speaker": "Старейшина", "portrait_color": c,
				"text": "Да хранят тебя боги. Легенды сохранят твоё имя!",
				"next": "__complete_stage__"}}

	# Стадия 3 — в процессе
	if stage == 3:
		return {"start": {"speaker": "Старейшина", "portrait_color": c,
			"text": "Страж Данжа ждёт тебя в самой глубокой комнате. Это самое опасное существо в данже. Будь осторожен!",
			"choices": [{"label": "Понял, иду", "next": ""}]}}

	# Стадия 2 — сдать: печать подобрана
	if stage == 2 and PlayerData.quest_has_seal:
		return {
			"start": {"speaker": "Старейшина", "portrait_color": c,
				"text": "Ты принёс Печать! Это значит, что элитный страж мёртв. Отлично. Держи %d золотых — и иди за главным: убей Стража Данжа!" % PlayerData.QUEST_REWARD_2,
				"choices": [{"label": "Принять награду", "next": "reward2"}, {"label": "Позже", "next": ""}]},
			"reward2": {"speaker": "Старейшина", "portrait_color": c,
				"text": "Страж Данжа — в самой дальней комнате. Победи его, и деревня будет спасена!",
				"next": "__complete_stage__"}}

	# Стадия 2 — в процессе
	if stage == 2:
		return {"start": {"speaker": "Старейшина", "portrait_color": c,
			"text": "Теперь найди элитного стража в данже — он отличается фиолетовым цветом и крупнее обычных. Убей его и принеси мне Печать, которую он носит.",
			"choices": [{"label": "Понял", "next": ""}]}}

	# Стадия 1 — сдать: 5 врагов убито
	if stage == 1 and PlayerData.quest_kills >= PlayerData.QUEST_KILL_TARGET:
		return {
			"start": {"speaker": "Старейшина", "portrait_color": c,
				"text": "Пятеро повержены! Ты доказал свою силу. Прими %d золотых — и продолжай. Теперь мне нужен Знак элитного стража." % PlayerData.QUEST_REWARD_1,
				"choices": [{"label": "Принять награду", "next": "reward1"}, {"label": "Позже", "next": ""}]},
			"reward1": {"speaker": "Старейшина", "portrait_color": c,
				"text": "Найди в данже элитного стража — он фиолетового цвета. Убей его и принеси мне его Печать.",
				"next": "__complete_stage__"}}

	# Стадия 1 — в процессе
	if stage == 1:
		return {"start": {"speaker": "Старейшина", "portrait_color": c,
			"text": "Как продвигаются дела? Убито %d из %d монстров. Возвращайся, когда выполнишь." % [PlayerData.quest_kills, PlayerData.QUEST_KILL_TARGET],
			"choices": [{"label": "Иду дальше", "next": ""}]}}

	# Стадия 0 — не начат
	return {
		"start": {"speaker": "Старейшина", "portrait_color": c,
			"text": "Путник, наша деревня в опасности. Нечисть хлынула из проклятого данжа. Не поможешь ли ты нам?",
			"choices": [{"label": "Расскажи подробнее", "next": "details"}, {"label": "Не сейчас", "next": ""}]},
		"details": {"speaker": "Старейшина", "portrait_color": c,
			"text": "Для начала — убей пятерых тварей в данже. Это докажет, что ты способен нам помочь. Согласен?",
			"choices": [{"label": "Принять задание", "next": "accept"}, {"label": "Нет, спасибо", "next": ""}]},
		"accept": {"speaker": "Старейшина", "portrait_color": c,
			"text": "Отлично! Данж — к востоку от деревни. Убей пятерых монстров и возвращайся. За это получишь %d золотых." % PlayerData.QUEST_REWARD_1,
			"next": "__accept_quest__"}}


func _get_dialogue() -> DialogueScreen:
	# Перехватываем сигнал для спец-действий (__accept_quest__, __complete_quest__)
	var nodes := get_tree().get_nodes_in_group("dialogue_screen")
	if nodes.is_empty():
		return null
	var dlg := nodes[0] as DialogueScreen
	# Подключаемся на один раз — отключаем и переподключаем
	if dlg.dialogue_ended.is_connected(_on_dialogue_ended):
		dlg.dialogue_ended.disconnect(_on_dialogue_ended)
	dlg.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)
	return dlg


func _on_dialogue_ended() -> void:
	var nodes := get_tree().get_nodes_in_group("dialogue_screen")
	if nodes.is_empty():
		return
	var dlg := nodes[0] as DialogueScreen
	match dlg._current_node:
		"__accept_quest__":
			PlayerData.quest_stage = 1
		"__complete_stage__":
			PlayerData.complete_stage()
