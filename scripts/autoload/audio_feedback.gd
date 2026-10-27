extends Node

const TV_SOUND_PRELOAD: AudioStream = preload("res://GAME ASSETS/SFX/tv sounds.mp3")
## Global audio feedback for UI, dialogue clicks, and inventory interactions.
## The photograph sound can be triggered from the ending with play_photograph().

const AMBIENT_PATHS := [
	"res://GAME ASSETS/Music/ambient sounds.mp3",
	"res://GAME ASSETS/music/ambient sounds.mp3",
	"res://music/ambient sounds.mp3",
	"res://Music/ambient sounds.mp3",
	"res://assets/music/ambient sounds.mp3",
	"res://Assets/music/ambient sounds.mp3"
]
const TV_SOUND_PATHS := [
	"res://GAME ASSETS/SFX/tv sounds.mp3",
	"res://GAME ASSETS/sfx/tv sounds.mp3",
	"res://SFX/tv sounds.mp3",
	"res://sfx/tv sounds.mp3",
	"res://Assets/SFX/tv sounds.mp3",
	"res://assets/SFX/tv sounds.mp3",
	"res://Music/tv sounds.mp3",
	"res://music/tv sounds.mp3"
]
const PHOTOGRAPH_PATHS := [
	"res://GAME ASSETS/SFX/photograph.mp3",
	"res://GAME ASSETS/sfx/photograph.mp3",
	"res://SFX/photograph.mp3",
	"res://sfx/photograph.mp3",
	"res://Assets/SFX/photograph.mp3",
	"res://assets/SFX/photograph.mp3"
]

var ambient_player: AudioStreamPlayer
var effect_player: AudioStreamPlayer
var drag_player: AudioStreamPlayer
var typing_player: AudioStreamPlayer
var writing_player: AudioStreamPlayer
var page_flip_player: AudioStreamPlayer
var tv_player: AudioStreamPlayer
var press_position := Vector2.ZERO
var left_was_pressed := false
var ambient_stream: AudioStream
var photograph_stream: AudioStream
var tv_stream: AudioStream
var tv_is_playing := false
var _tv_load_requested := false
var _tv_requested_path := ""
var _last_scene_name := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "AmbientPlayer"
	ambient_player.bus = "Master"
	add_child(ambient_player)

	effect_player = AudioStreamPlayer.new()
	effect_player.name = "InteractionSFXPlayer"
	effect_player.bus = "Master"
	add_child(effect_player)

	drag_player = AudioStreamPlayer.new()
	drag_player.name = "DragSFXPlayer"
	drag_player.bus = "Master"
	add_child(drag_player)

	typing_player = AudioStreamPlayer.new()
	typing_player.name = "TypingSFXPlayer"
	typing_player.bus = "Master"
	typing_player.volume_db = -12.0
	add_child(typing_player)

	writing_player = AudioStreamPlayer.new()
	writing_player.name = "JournalWritingSFXPlayer"
	writing_player.bus = "Master"
	writing_player.volume_db = -5.0
	add_child(writing_player)

	page_flip_player = AudioStreamPlayer.new()
	page_flip_player.name = "PageFlipSFXPlayer"
	page_flip_player.bus = "Master"
	page_flip_player.volume_db = -7.0
	add_child(page_flip_player)

	tv_player = AudioStreamPlayer.new()
	tv_player.name = "TVSoundPlayer"
	tv_player.bus = "Master"
	tv_player.volume_db = -4.0
	add_child(tv_player)

	ambient_stream = _load_first_audio(AMBIENT_PATHS)
	photograph_stream = _load_first_audio(PHOTOGRAPH_PATHS)
	# Preload the TV loop before the player interacts with the television.
	# This moves its resource loading cost out of the interaction click path.
	tv_stream = TV_SOUND_PRELOAD
	_set_stream_loop(tv_stream, true)
	tv_player.stream = tv_stream
	if ambient_stream:
		_set_stream_loop(ambient_stream, true)
		ambient_player.stream = ambient_stream
		ambient_player.volume_db = -9.0
		start_ambient()
	else:
		push_warning("Ambient music not found yet. Add 'ambient sounds.mp3' to the game's music folder.")

## Starts the looping background ambience if it is not already playing.
func start_ambient() -> void:
	if ambient_player == null:
		return
	if ambient_stream == null:
		ambient_stream = _load_first_audio(AMBIENT_PATHS)
		if ambient_stream:
			_set_stream_loop(ambient_stream, true)
			ambient_player.stream = ambient_stream
			ambient_player.volume_db = -9.0
	if ambient_stream and not ambient_player.playing:
		ambient_player.play()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press_position = event.position
			left_was_pressed = true
		elif left_was_pressed:
			left_was_pressed = false
			if press_position.distance_to(event.position) > 18.0:
				play_drag()
			else:
				play_click()

func play_click() -> void:
	_play_generated_tone(effect_player, 920.0, 0.045, 0.22)

func play_drag() -> void:
	_play_generated_tone(drag_player, 520.0, 0.075, 0.18)

## Short, soft typewriter tick. Called as each dialogue character appears.
func play_typing() -> void:
	if typing_player == null or typing_player.playing:
		return
	_play_generated_tone(typing_player, randf_range(1250.0, 1750.0), 0.018, 0.10)


## Soft pen-on-paper scratch used after Migs records a memory in his journal.
func play_journal_writing() -> void:
	if writing_player == null:
		return
	var sample_rate := 22050
	var duration := 0.72
	var sample_count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(sample_count):
		var t := float(i) / sample_rate
		# Irregular short strokes create a light paper-scratching texture.
		var stroke := 0.0
		if sin(t * 2.0 * PI * 7.5) > -0.28:
			stroke = rng.randf_range(-1.0, 1.0) * 0.20
		var envelope := minf(1.0, t * 28.0) * (1.0 - t / duration)
		var sample := stroke * envelope
		bytes.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var paper_sound := AudioStreamWAV.new()
	paper_sound.format = AudioStreamWAV.FORMAT_16_BITS
	paper_sound.mix_rate = sample_rate
	paper_sound.stereo = false
	paper_sound.data = bytes
	writing_player.stream = paper_sound
	writing_player.play()

## Soft paper flutter when moving between journal spreads.
func play_page_flip() -> void:
	if page_flip_player == null:
		return
	var sample_rate := 22050
	var duration := 0.34
	var sample_count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var previous_noise := 0.0
	for i in range(sample_count):
		var t := float(i) / sample_rate
		var envelope := pow(maxf(0.0, 1.0 - t / duration), 1.7)
		var noise := rng.randf_range(-1.0, 1.0)
		previous_noise = lerpf(previous_noise, noise, 0.32)
		var flutter := 0.65 + 0.35 * sin(TAU * 9.0 * t)
		var sample := previous_noise * envelope * flutter * 0.42
		bytes.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var paper_flip := AudioStreamWAV.new()
	paper_flip.format = AudioStreamWAV.FORMAT_16_BITS
	paper_flip.mix_rate = sample_rate
	paper_flip.stereo = false
	paper_flip.data = bytes
	page_flip_player.stream = paper_flip
	page_flip_player.play()

## Start playback from the stream that was preloaded during initialization.
func play_tv() -> void:
	if tv_is_playing:
		return
	if tv_stream == null or tv_player == null:
		push_warning("TV audio preload is unavailable. Check the tv sounds.mp3 asset path.")
		return
	tv_is_playing = true
	tv_player.stream = tv_stream
	tv_player.play()

## Call when the player turns the television off.
func stop_tv() -> void:
	tv_is_playing = false
	if tv_player and tv_player.playing:
		tv_player.stop()

## Convenience method for a TV interaction that toggles on/off state.
func toggle_tv() -> void:
	if tv_is_playing:
		stop_tv()
	else:
		play_tv()

func play_photograph() -> void:
	if photograph_stream == null:
		photograph_stream = _load_first_audio(PHOTOGRAPH_PATHS)
	if photograph_stream:
		effect_player.stream = photograph_stream
		effect_player.volume_db = 0.0
		effect_player.play()
	else:
		push_warning("photograph.mp3 not found. Add it to the game's SFX folder.")

func _load_first_audio(paths: Array) -> AudioStream:
	for path in paths:
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream:
				return stream
	return null

func _set_stream_loop(stream: AudioStream, enabled: bool) -> void:
	if stream is AudioStreamMP3:
		stream.loop = enabled
	elif stream is AudioStreamOggVorbis:
		stream.loop = enabled

func _play_generated_tone(player: AudioStreamPlayer, frequency: float, duration: float, amplitude: float) -> void:
	var sample_rate := 22050
	var sample_count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / sample_rate
		var fade := minf(1.0, float(i) / 100.0) * (1.0 - float(i) / sample_count)
		var sample := sin(TAU * frequency * t) * amplitude * fade
		var pcm := int(clampf(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, pcm)
	var tone := AudioStreamWAV.new()
	tone.format = AudioStreamWAV.FORMAT_16_BITS
	tone.mix_rate = sample_rate
	tone.stereo = false
	tone.data = bytes
	player.stream = tone
	player.volume_db = 0.0
	player.play()
