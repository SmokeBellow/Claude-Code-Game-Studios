extends Node
## Централизованная система управления квестами.
## Implements: design/gdd/quest-system.md
##
## Единственный авторитетный источник квестовой логики. Данные квестов
## хранятся в полях PlayerData; QuestSystem предоставляет логику и сигналы.
##
## MVP: одна сюжетная цепочка (quest_id = "elder_main"), 4 стадии.
##
## Пример использования:
##   QuestSystem.accept_quest()                  # начать квест (stage 0→1)
##   QuestSystem.notify_enemy_killed()            # вызывать при каждом убийстве
##   if QuestSystem.is_stage_ready(): ...         # проверить готовность сдачи
##   var gold := QuestSystem.complete_stage()     # сдать стадию, получить золото
##   QuestSystem.quest_accepted.connect(_on_quest_accepted)

# ---------------------------------------------------------------------------
# Константы
# ---------------------------------------------------------------------------

const QUEST_ID_MAIN    := "elder_main"
const KILL_TARGET      := 5
const REWARD_STAGE_1   := 50
const REWARD_STAGE_2   := 100
const REWARD_STAGE_3   := 300

# ---------------------------------------------------------------------------
# Сигналы
# ---------------------------------------------------------------------------

## Квест принят (stage 0 → 1).
signal quest_accepted(quest_id: String)
## Стадия сдана. Передаёт номер завершённой стадии и выданную награду.
signal stage_completed(quest_id: String, stage: int, reward: int)
## Вся цепочка квестов завершена (stage достиг 4).
signal quest_completed(quest_id: String)

# ---------------------------------------------------------------------------
# Публичный API — события мира
# ---------------------------------------------------------------------------

## Вызывать при каждом убийстве врага в данже.
func notify_enemy_killed() -> void:
	if PlayerData.quest_stage == 1:
		PlayerData.quest_kills = mini(PlayerData.quest_kills + 1, KILL_TARGET)


## Вызывать при убийстве босса.
func notify_boss_killed() -> void:
	if PlayerData.quest_stage == 3:
		PlayerData.quest_boss_killed = true


## Вызывать когда игрок подбирает Печать Стражника.
func notify_seal_picked() -> void:
	if PlayerData.quest_stage == 2:
		PlayerData.quest_has_seal = true

# ---------------------------------------------------------------------------
# Публичный API — управление квестом
# ---------------------------------------------------------------------------

## Начинает квест: переводит стадию 0 → 1.
## Ничего не делает, если квест уже начат или завершён.
func accept_quest() -> void:
	if PlayerData.quest_stage != 0:
		return
	PlayerData.quest_stage = 1
	quest_accepted.emit(QUEST_ID_MAIN)


## Возвращает true, если текущая стадия выполнена и готова к сдаче.
func is_stage_ready() -> bool:
	match PlayerData.quest_stage:
		1: return PlayerData.quest_kills >= KILL_TARGET
		2: return PlayerData.quest_has_seal
		3: return PlayerData.quest_boss_killed
	return false


## Сдаёт текущую стадию старосте.
## Возвращает выданное золото; 0 если условия ещё не выполнены.
func complete_stage() -> int:
	if not is_stage_ready():
		return 0

	var old_stage: int = PlayerData.quest_stage
	var reward: int = 0
	match old_stage:
		1: reward = REWARD_STAGE_1
		2: reward = REWARD_STAGE_2
		3: reward = REWARD_STAGE_3

	PlayerData.quest_stage += 1
	PlayerData.add_gold(reward)

	stage_completed.emit(QUEST_ID_MAIN, old_stage, reward)
	if PlayerData.quest_stage == 4:
		quest_completed.emit(QUEST_ID_MAIN)

	return reward

# ---------------------------------------------------------------------------
# Утилиты / запросы
# ---------------------------------------------------------------------------

## Возвращает текущую стадию сюжетной цепочки (0–4).
func get_stage() -> int:
	return PlayerData.quest_stage


## Возвращает число убийств в стадии 1.
func get_kill_count() -> int:
	return PlayerData.quest_kills

# ---------------------------------------------------------------------------
# Интеграция с SaveSystem
# ---------------------------------------------------------------------------

## Сериализует данные квестов для SaveSystem ("quests" слот).
## На данный момент миррорит поля PlayerData; в будущем сюда попадут
## все активные квесты в виде массива Dictionary.
func serialize() -> Dictionary:
	return {
		"version": 1,
		"quests": [
			{
				"id":           QUEST_ID_MAIN,
				"stage":        PlayerData.quest_stage,
				"kills":        PlayerData.quest_kills,
				"has_seal":     PlayerData.quest_has_seal,
				"boss_killed":  PlayerData.quest_boss_killed,
			}
		]
	}


## Восстанавливает данные квестов из SaveSystem.
## Совместим со старыми сейвами, где слот "quests" пустой ({}).
func deserialize(data: Dictionary) -> void:
	if data.is_empty():
		return   # Старый сейв — данные уже прочитаны из "player" через PlayerData

	var quests: Array = data.get("quests", [])
	for q: Dictionary in quests:
		if q.get("id", "") == QUEST_ID_MAIN:
			PlayerData.quest_stage       = int(q.get("stage",       PlayerData.quest_stage))
			PlayerData.quest_kills       = int(q.get("kills",       PlayerData.quest_kills))
			PlayerData.quest_has_seal    = bool(q.get("has_seal",   PlayerData.quest_has_seal))
			PlayerData.quest_boss_killed = bool(q.get("boss_killed", PlayerData.quest_boss_killed))
			break


## Вызывается SaveSystem после загрузки. Восстанавливает активное состояние.
## Stub — в будущем: подключить UI-слушатели, обновить маркеры на карте и т.д.
func _restore_active_quests() -> void:
	pass
