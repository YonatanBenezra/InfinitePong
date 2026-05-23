extends Node
## Autoload: durable JSON persistence for all meta-progression.
##
## One file at user://pindown_save.json holds every section (profile,
## settings, challenges). Systems own their section and call set_section()
## then mark_dirty(); writes are debounced so rapid updates coalesce into a
## single disk write. flush() forces an immediate write (used on quit).

const SAVE_PATH := "user://pindown_save.json"
const BACKUP_PATH := "user://pindown_save.bak.json"
const SAVE_VERSION := 1
const WRITE_DEBOUNCE := 0.75

var _data: Dictionary = {}
var _dirty: bool = false
var _write_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_from_disk()


func _process(delta: float) -> void:
	if not _dirty:
		return
	_write_timer -= delta
	if _write_timer <= 0.0:
		flush()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_CRASH:
		flush()


## Returns a deep copy of a named section, or `default` if missing.
func get_section(key: String, default: Dictionary = {}) -> Dictionary:
	if _data.has(key) and _data[key] is Dictionary:
		return (_data[key] as Dictionary).duplicate(true)
	return default.duplicate(true)


## Overwrites a named section. Caller should mark_dirty() afterwards.
func set_section(key: String, value: Dictionary) -> void:
	_data[key] = value.duplicate(true)
	mark_dirty()


func mark_dirty() -> void:
	_dirty = true
	_write_timer = WRITE_DEBOUNCE


## Immediately serialises everything to disk. Keeps a one-step backup so a
## corrupt write never destroys a known-good save.
func flush() -> void:
	if not _dirty:
		return
	_dirty = false
	_data["_version"] = SAVE_VERSION
	if FileAccess.file_exists(SAVE_PATH):
		var prev := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if prev:
			var prev_text := prev.get_as_text()
			prev.close()
			var bak := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if bak:
				bak.store_string(prev_text)
				bak.close()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveSystem: could not open save file for writing")
		return
	file.store_string(JSON.stringify(_data, "\t"))
	file.close()


func _load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_data = {}
		return
	if _try_load(SAVE_PATH):
		return
	push_warning("SaveSystem: primary save unreadable, trying backup")
	if _try_load(BACKUP_PATH):
		return
	push_warning("SaveSystem: no readable save found, starting fresh")
	_data = {}


func _try_load(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_data = parsed
		return true
	return false


## Wipes everything. Used by Settings -> "Reset progress".
func wipe() -> void:
	_data = {}
	_dirty = true
	flush()
