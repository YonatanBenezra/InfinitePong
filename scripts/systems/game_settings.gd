extends Node
## Autoload: player-facing options, persisted and applied live.
##
## Audio values are 0..1 linear and routed to the audio buses. Visual
## toggles are read by game_controller / camera / ball at runtime. Any
## change persists immediately and emits GameEvents.settings_changed so
## open screens can refresh.

const SECTION := "settings"

var master_volume: float = 0.9
var music_volume: float = 0.7
var sfx_volume: float = 0.85
var screen_shake: float = 1.0      ## 0..1 multiplier on all camera shake.
var particles_enabled: bool = true
var screen_flash: bool = true
var show_fps: bool = false
var reduced_motion: bool = false   ## Tones down parallax + flashes for comfort.
var music_muted: bool = false      ## Quick mute toggle (separate from volume).

var _loaded: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_load()
	_apply_audio()


## Creates the Music and Sfx buses (routed to Master) if the project does
## not already define them, so audio code can target them unconditionally.
func _ensure_buses() -> void:
	for bus_name in ["Music", "Sfx"]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func _load() -> void:
	var d := SaveSystem.get_section(SECTION)
	master_volume = float(d.get("master_volume", master_volume))
	music_volume = float(d.get("music_volume", music_volume))
	sfx_volume = float(d.get("sfx_volume", sfx_volume))
	screen_shake = float(d.get("screen_shake", screen_shake))
	particles_enabled = bool(d.get("particles_enabled", particles_enabled))
	screen_flash = bool(d.get("screen_flash", screen_flash))
	show_fps = bool(d.get("show_fps", show_fps))
	reduced_motion = bool(d.get("reduced_motion", reduced_motion))
	music_muted = bool(d.get("music_muted", music_muted))
	_loaded = true


## Re-reads settings from disk and re-applies them (used after a wipe).
func reload() -> void:
	_load()
	_apply_audio()
	GameEvents.settings_changed.emit()


func save() -> void:
	SaveSystem.set_section(SECTION, {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"screen_shake": screen_shake,
		"particles_enabled": particles_enabled,
		"screen_flash": screen_flash,
		"show_fps": show_fps,
		"reduced_motion": reduced_motion,
		"music_muted": music_muted,
	})


## Call after mutating any field. Persists, re-applies audio, notifies UI.
func commit() -> void:
	if not _loaded:
		return
	save()
	_apply_audio()
	GameEvents.settings_changed.emit()


## Flips the music mute toggle and persists it.
func toggle_music_mute() -> void:
	music_muted = not music_muted
	commit()


func _apply_audio() -> void:
	_set_bus("Master", master_volume)
	_set_bus("Music", 0.0 if music_muted else music_volume)
	_set_bus("Sfx", sfx_volume)


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	if linear <= 0.001:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))


## Effective camera-shake amount after the player's preference multiplier.
func shake_amount(raw: float) -> float:
	if reduced_motion:
		return raw * 0.25 * screen_shake
	return raw * screen_shake
