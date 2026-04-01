extends Node

## Глобальный менеджер звука. Добавь как Autoload с именем "AudioManager".
## Все звуки синтезируются программно — внешние файлы не требуются.

# ---------------------------------------------------------------------------
# Константы синтеза
# ---------------------------------------------------------------------------

const SAMPLE_RATE: int = 22050

# ---------------------------------------------------------------------------
# Внутренние плееры
# ---------------------------------------------------------------------------

var _players: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 8
var _pool_idx: int = 0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)


# ---------------------------------------------------------------------------
# Публичный API
# ---------------------------------------------------------------------------

## Короткий щелчок при ударе по врагу.
func play_hit() -> void:
	_play_stream(_make_hit())


## Низкий удар когда игрок получает урон.
func play_player_hurt() -> void:
	_play_stream(_make_player_hurt())


## Нисходящий тон при смерти врага.
func play_enemy_die() -> void:
	_play_stream(_make_enemy_die())


## Восходящий аккорд при повышении уровня.
func play_level_up() -> void:
	_play_stream(_make_level_up())


## Короткий бип при использовании умения.
func play_ability() -> void:
	_play_stream(_make_ability())


# ---------------------------------------------------------------------------
# Воспроизведение через пул
# ---------------------------------------------------------------------------

func _play_stream(stream: AudioStreamWAV) -> void:
	var p: AudioStreamPlayer = _players[_pool_idx]
	_pool_idx = (_pool_idx + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = -6.0
	p.play()


# ---------------------------------------------------------------------------
# Синтез: удар по врагу — короткий «тук» с быстрым затуханием
# ---------------------------------------------------------------------------

func _make_hit() -> AudioStreamWAV:
	var dur: float = 0.08
	var samples := _alloc(dur)
	var n: int = samples.size()
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var env: float = exp(-t * 60.0)
		var wave: float = sin(TAU * 220.0 * t) * env
		wave += _noise() * 0.4 * env
		samples[i] = int(clampf(wave * 28000.0, -32768.0, 32767.0))
	return _build_wav(samples)


# ---------------------------------------------------------------------------
# Синтез: урон игроку — низкий глухой удар
# ---------------------------------------------------------------------------

func _make_player_hurt() -> AudioStreamWAV:
	var dur: float = 0.18
	var samples := _alloc(dur)
	var n: int = samples.size()
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var env: float = exp(-t * 20.0)
		var freq: float = 110.0 - t * 60.0
		var wave: float = sin(TAU * freq * t) * env
		wave += _noise() * 0.6 * exp(-t * 30.0)
		samples[i] = int(clampf(wave * 26000.0, -32768.0, 32767.0))
	return _build_wav(samples)


# ---------------------------------------------------------------------------
# Синтез: смерть врага — нисходящий тон
# ---------------------------------------------------------------------------

func _make_enemy_die() -> AudioStreamWAV:
	var dur: float = 0.35
	var samples := _alloc(dur)
	var n: int = samples.size()
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var env: float = exp(-t * 8.0)
		var freq: float = 300.0 - t * 200.0
		var wave: float = sin(TAU * freq * t) * env
		wave += sin(TAU * freq * 1.5 * t) * env * 0.3
		samples[i] = int(clampf(wave * 24000.0, -32768.0, 32767.0))
	return _build_wav(samples)


# ---------------------------------------------------------------------------
# Синтез: level-up — три восходящих тона
# ---------------------------------------------------------------------------

func _make_level_up() -> AudioStreamWAV:
	var dur: float = 0.55
	var samples := _alloc(dur)
	var n: int = samples.size()
	# Три ноты: C5 (523 Hz) → E5 (659 Hz) → G5 (784 Hz)
	var notes: Array[float] = [523.0, 659.0, 784.0]
	var note_dur: float = dur / 3.0
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var note_idx: int = int(t / note_dur)
		if note_idx >= notes.size():
			note_idx = notes.size() - 1
		var t_local: float = fmod(t, note_dur)
		var env: float = exp(-t_local * 6.0) * (1.0 - t / dur * 0.5)
		var wave: float = sin(TAU * notes[note_idx] * t) * env
		wave += sin(TAU * notes[note_idx] * 2.0 * t) * env * 0.2
		samples[i] = int(clampf(wave * 22000.0, -32768.0, 32767.0))
	return _build_wav(samples)


# ---------------------------------------------------------------------------
# Синтез: умение — короткий высокий свист
# ---------------------------------------------------------------------------

func _make_ability() -> AudioStreamWAV:
	var dur: float = 0.12
	var samples := _alloc(dur)
	var n: int = samples.size()
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var env: float = sin(PI * t / dur)
		var freq: float = 600.0 + t / dur * 400.0
		var wave: float = sin(TAU * freq * t) * env
		samples[i] = int(clampf(wave * 20000.0, -32768.0, 32767.0))
	return _build_wav(samples)


# ---------------------------------------------------------------------------
# Вспомогательные
# ---------------------------------------------------------------------------

func _alloc(duration: float) -> PackedInt32Array:
	var count: int = int(duration * SAMPLE_RATE)
	var arr := PackedInt32Array()
	arr.resize(count)
	return arr


func _noise() -> float:
	return randf_range(-1.0, 1.0)


func _build_wav(samples: PackedInt32Array) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = SAMPLE_RATE
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var s: int = clampi(samples[i], -32768, 32767)
		bytes[i * 2]     = s & 0xFF
		bytes[i * 2 + 1] = (s >> 8) & 0xFF
	wav.data = bytes
	return wav
