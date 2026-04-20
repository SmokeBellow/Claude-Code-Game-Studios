extends Node
## Оркестратор сохранения и загрузки игрового прогресса.
## Implements: design/gdd/save-load.md
##
## Собирает снимки от всех систем через их serialize() методы,
## объединяет в единый Dictionary и записывает в user://save.json.
## При загрузке — раздаёт данные системам через deserialize(),
## затем вызывает restore-колбэки в строгом порядке.
##
## Автосейв срабатывает:
##   - при возврате из данжа в город (вызов save() из SceneManager)
##   - при выходе из игры (_notification WM_CLOSE_REQUEST)
##
## MVP: один слот сохранения. Файл: user://save.json

# ---------------------------------------------------------------------------
# Константы
# ---------------------------------------------------------------------------

const SAVE_PATH    := "user://save.json"
const SAVE_VERSION := 1

# ---------------------------------------------------------------------------
# Буфер инвентаря (для загрузки из главного меню)
#
# Проблема: load_game() вызывается до появления Player-сцены (нет Inventory-ноды).
# Решение:  данные хранятся здесь до _ready() Inventory; нода сама забирает их.
# ---------------------------------------------------------------------------

var _pending_inventory: Dictionary = {}
var _has_pending_inventory: bool   = false

## Возвращает true если есть необработанные данные инвентаря для Inventory-ноды.
func has_pending_inventory() -> bool:
	return _has_pending_inventory

## Забирает pending-данные (вызывается из Inventory._ready()). Сбрасывает буфер.
func take_pending_inventory() -> Dictionary:
	_has_pending_inventory = false
	var d := _pending_inventory
	_pending_inventory = {}
	return d

# ---------------------------------------------------------------------------
# Сигналы
# ---------------------------------------------------------------------------

signal save_completed()
signal load_completed()
signal save_failed(reason: String)

# ---------------------------------------------------------------------------
# Жизненный цикл
# ---------------------------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
		get_tree().quit()

# ---------------------------------------------------------------------------
# Публичный API
# ---------------------------------------------------------------------------

## Возвращает true если файл сохранения существует.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Сохраняет состояние всех систем в user://save.json.
## Возвращает true при успехе, false при ошибке.
func save() -> bool:
	var data := _collect()
	var json_str := JSON.stringify(data, "\t")

	# Пишем во временный файл, затем переименовываем — защита от потери данных
	var tmp_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		var reason := "Не удалось открыть для записи: %s" % tmp_path
		push_error("SaveSystem: " + reason)
		save_failed.emit(reason)
		return false

	file.store_string(json_str)
	file.close()

	# Атомарное переименование
	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("SaveSystem: DirAccess.open('user://') вернул null")
		save_failed.emit("Ошибка доступа к user://")
		return false

	# Удаляем старый файл если есть, затем переименовываем tmp
	if FileAccess.file_exists(SAVE_PATH):
		dir.remove(SAVE_PATH)
	dir.rename(tmp_path, SAVE_PATH)

	save_completed.emit()
	return true


## Загружает состояние из user://save.json.
## Возвращает true при успехе. При ошибке — показывает push_error, возвращает false.
func load_game() -> bool:
	if not has_save():
		push_warning("SaveSystem: файл сохранения не найден — %s" % SAVE_PATH)
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveSystem: не удалось открыть %s для чтения" % SAVE_PATH)
		return false

	var content := file.get_as_text()
	file.close()

	if content.is_empty():
		push_error("SaveSystem: файл сохранения пуст — %s" % SAVE_PATH)
		save_failed.emit("Файл сохранения пуст")
		return false

	var json := JSON.new()
	var parse_err := json.parse(content)
	if parse_err != OK:
		push_error("SaveSystem: ошибка парсинга JSON (строка %d): %s" % [json.get_error_line(), json.get_error_message()])
		save_failed.emit("Файл сохранения повреждён")
		return false

	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		push_error("SaveSystem: неожиданный тип данных в сейве: %s" % typeof(parsed))
		save_failed.emit("Файл сохранения повреждён")
		return false

	var data: Dictionary = parsed as Dictionary
	_distribute(data)
	_restore_callbacks()

	load_completed.emit()
	return true


## Сбрасывает все системы и удаляет файл сохранения (Новая игра).
func new_game() -> void:
	_pending_inventory     = {}
	_has_pending_inventory = false
	_reset_all()
	if has_save():
		var dir := DirAccess.open("user://")
		if dir != null:
			dir.remove(SAVE_PATH)

# ---------------------------------------------------------------------------
# Сериализация (сбор данных)
# ---------------------------------------------------------------------------

func _collect() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"player":       _serialize_player(),
		"world_state":  WorldState.serialize(),
		"skill_tree":   _serialize_skill_tree(),
		"inventory":    _serialize_inventory(),
		"quests":       QuestSystem.serialize(),
	}


func _serialize_player() -> Dictionary:
	return {
		"class":           PlayerData.player_class,
		"gold":            PlayerData.gold,
		"level":           PlayerData.saved_level,
		"xp":              PlayerData.saved_xp,
		"str":             PlayerData.saved_str,
		"dex":             PlayerData.saved_dex,
		"end":             PlayerData.saved_end,
		"int":             PlayerData.saved_int,
		"arc":             PlayerData.saved_arc,
		"lck":             PlayerData.saved_lck,
		"attr_points":     PlayerData.saved_attr_points,
		"potion_slots":    PlayerData.potion_slots,
		"hero_name":       PlayerData.hero_name,
		"quest_stage":     PlayerData.quest_stage,
		"quest_kills":     PlayerData.quest_kills,
		"quest_has_seal":  PlayerData.quest_has_seal,
		"quest_boss_killed": PlayerData.quest_boss_killed,
	}


func _serialize_skill_tree() -> Dictionary:
	return {
		"version":      1,
		"skill_points": PlayerData.skill_points,
		"spent_points": PlayerData.spent_points,
	}


func _serialize_inventory() -> Dictionary:
	# Ищем Inventory-ноду через группу (существует только когда загружена Player-сцена)
	var nodes := get_tree().get_nodes_in_group("inventory")
	if nodes.is_empty():
		push_warning("SaveSystem: Inventory-нода не найдена — инвентарь не сохранён")
		return {}
	return (nodes[0] as Inventory).serialize()

# ---------------------------------------------------------------------------
# Десериализация (раздача данных)
# ---------------------------------------------------------------------------

func _distribute(data: Dictionary) -> void:
	# Версия — для будущей миграции
	var version: int = data.get("save_version", 0)
	if version < SAVE_VERSION:
		push_warning("SaveSystem: старый формат сейва (v%d), применяются дефолты для недостающих ключей" % version)

	_deserialize_player(data.get("player", {}))
	WorldState.deserialize(data.get("world_state", {}))
	_deserialize_skill_tree(data.get("skill_tree", {}))
	QuestSystem.deserialize(data.get("quests", {}))
	_deserialize_inventory(data.get("inventory", {}))


func _deserialize_player(p: Dictionary) -> void:
	PlayerData.player_class        = int(p.get("class",           PlayerData.CLASS_NONE))
	PlayerData.gold                = int(p.get("gold",            0))
	PlayerData.saved_level         = int(p.get("level",           1))
	PlayerData.saved_xp            = int(p.get("xp",              0))
	PlayerData.saved_str           = float(p.get("str",           5.0))
	PlayerData.saved_dex           = float(p.get("dex",           5.0))
	PlayerData.saved_end           = float(p.get("end",           5.0))
	PlayerData.saved_int           = float(p.get("int",           5.0))
	PlayerData.saved_arc           = float(p.get("arc",           5.0))
	PlayerData.saved_lck           = float(p.get("lck",           5.0))
	PlayerData.saved_attr_points   = int(p.get("attr_points",     0))
	PlayerData.hero_name           = str(p.get("hero_name",       ""))
	PlayerData.quest_stage         = int(p.get("quest_stage",     0))
	PlayerData.quest_kills         = int(p.get("quest_kills",     0))
	PlayerData.quest_has_seal      = bool(p.get("quest_has_seal", false))
	PlayerData.quest_boss_killed   = bool(p.get("quest_boss_killed", false))

	var ps: Array = p.get("potion_slots", [0, 0, 0, 0])
	PlayerData.potion_slots = [
		int(ps[0]) if ps.size() > 0 else 0,
		int(ps[1]) if ps.size() > 1 else 0,
		int(ps[2]) if ps.size() > 2 else 0,
		int(ps[3]) if ps.size() > 3 else 0,
	]


func _deserialize_skill_tree(st: Dictionary) -> void:
	PlayerData.skill_points = int(st.get("skill_points", 0))
	var sp: Variant = st.get("spent_points", {})
	PlayerData.spent_points = sp if sp is Dictionary else {}


func _deserialize_inventory(inv: Dictionary) -> void:
	if inv.is_empty():
		return
	# Если Inventory-нода уже в сцене — применяем сразу
	var nodes := get_tree().get_nodes_in_group("inventory")
	if not nodes.is_empty():
		(nodes[0] as Inventory).deserialize(inv)
		return
	# Иначе — кладём в pending-буфер; Inventory._ready() заберёт сам
	_pending_inventory       = inv
	_has_pending_inventory   = true

# ---------------------------------------------------------------------------
# Restore-колбэки (строгий порядок!)
# ---------------------------------------------------------------------------

func _restore_callbacks() -> void:
	# 1. Пассивы дерева навыков (должен быть первым — влияет на статы)
	_try_restore_passives()
	# 2. Бонусы экипировки (после статов)
	_try_reapply_equipment()
	# 3. Счётчики квестов
	_try_restore_quests()


func _try_restore_passives() -> void:
	# SkillTree добавляется как дочерний к игроку — ищем через группу.
	# Если нода ещё не существует (загрузка из меню), _restore_passives()
	# будет вызван автоматически в SkillTree.setup() при инициализации сцены.
	var nodes := get_tree().get_nodes_in_group("skill_tree")
	if not nodes.is_empty():
		(nodes[0] as SkillTree)._restore_passives()


func _try_reapply_equipment() -> void:
	# Если Inventory-нода уже в сцене — применяем бонусы сразу.
	# Если нет (загрузка из меню) — pending-буфер; _reapply вызовет Inventory._ready().
	var nodes := get_tree().get_nodes_in_group("inventory")
	if not nodes.is_empty():
		(nodes[0] as Inventory)._reapply_equipment_bonuses()


func _try_restore_quests() -> void:
	QuestSystem._restore_active_quests()

# ---------------------------------------------------------------------------
# Reset
# ---------------------------------------------------------------------------

func _reset_all() -> void:
	WorldState.reset()
	PlayerData.player_class        = PlayerData.CLASS_NONE
	PlayerData.gold                = 0
	PlayerData.saved_level         = 1
	PlayerData.saved_xp            = 0
	PlayerData.saved_str           = 5.0
	PlayerData.saved_dex           = 5.0
	PlayerData.saved_end           = 5.0
	PlayerData.saved_int           = 5.0
	PlayerData.saved_arc           = 5.0
	PlayerData.saved_lck           = 5.0
	PlayerData.saved_attr_points   = 0
	PlayerData.potion_slots        = [0, 0, 0, 0]
	PlayerData.quest_stage         = 0
	PlayerData.quest_kills         = 0
	PlayerData.quest_has_seal      = false
	PlayerData.quest_boss_killed   = false
	PlayerData.was_resurrected       = false
	PlayerData.returned_from_dungeon = false
	PlayerData.skill_points          = 0
	PlayerData.spent_points          = {}
	PlayerData.hero_name             = ""
