extends Node

const PATH = "user://settings.json"
const CHECKPOINT = "user://checkpoint.json"
const DEFAULTS = {
"preset": 2, "render_scale": 0.85, "shadows": 2, "effects": 2,
"aa": 1, "fps_limit": 60, "fov": 78.0, "camera_distance": 4.2,
"sensitivity": 1.0, "gyro": false, "gyro_sensitivity": 0.8,
"gyro_ads_only": false, "invert_y": false, "volume": 0.8,
"shake": 0.6, "third_person": true, "shoulder": 1.0,
"touch_scale": 1.0, "diagnostics": false, "dynamic_resolution": false
}
var values: Dictionary = DEFAULTS.duplicate()
var checkpoint: Dictionary = {}

func _ready():
	load_settings()
	checkpoint = read_json(CHECKPOINT)
	apply()

static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return {}
	return parser.data if parser.data is Dictionary else {}

static func sanitized(data: Dictionary) -> Dictionary:
	var result = DEFAULTS.duplicate()
	for key in DEFAULTS:
		if data.has(key) and typeof(data[key]) == typeof(DEFAULTS[key]): result[key] = data[key]
		elif data.has(key) and data[key] is float and DEFAULTS[key] is int: result[key] = int(data[key])
	result.preset = clampi(result.preset, 0, 3)
	result.render_scale = clampf(result.render_scale, 0.5, 1.0)
	result.shadows = clampi(result.shadows, 0, 3)
	result.effects = clampi(result.effects, 0, 3)
	result.aa = clampi(result.aa, 0, 2)
	result.fov = clampf(result.fov, 60, 100)
	result.camera_distance = clampf(result.camera_distance, 2.4, 6.0)
	result.sensitivity = clampf(result.sensitivity, 0.2, 3.0)
	result.gyro_sensitivity = clampf(result.gyro_sensitivity, 0.1, 3.0)
	result.volume = clampf(result.volume, 0, 1)
	result.shake = clampf(result.shake, 0, 1)
	result.touch_scale = clampf(result.touch_scale, 0.75, 1.4)
	result.fps_limit = int(result.fps_limit) if int(result.fps_limit) in [30, 60, 90, 120] else 60
	return result

func load_settings():
	values = sanitized(read_json(PATH))

func save():
	atomic_write(PATH, values)

static func atomic_write(path: String, data: Dictionary) -> bool:
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func set_preset(index: int):
	values.preset = index
	values.render_scale = [0.55, 0.7, 0.85, 1.0][index]
	values.shadows = index
	values.effects = index
	values.aa = [0, 1, 1, 2][index]
	apply()
	save()

func apply():
	Engine.max_fps = values.fps_limit
	var viewport = get_viewport()
	viewport.scaling_3d_scale = values.render_scale
	viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][values.aa]
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(values.volume, 0.0001)))

func save_checkpoint(stage: int):
	checkpoint = {"stage": clampi(stage, 0, 3), "version": 1}
	atomic_write(CHECKPOINT, checkpoint)

func clear_checkpoint():
	checkpoint = {}
	if FileAccess.file_exists(CHECKPOINT): DirAccess.remove_absolute(CHECKPOINT)
