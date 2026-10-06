extends Node

var streams: Dictionary = {}
var pool: Array[AudioStreamPlayer3D] = []
var cursor = 0
var ui_player: AudioStreamPlayer

func _ready():
	for name in ["autocannon","breacher","coil","step","reload","impact","explosion","servo","ambient","ui","charge"]:
		streams[name] = load("res://assets/" + name + ".wav")
	for i in 20:
		var player = AudioStreamPlayer3D.new()
		player.max_distance = 65
		player.unit_size = 7
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player)
		pool.append(player)
	ui_player = AudioStreamPlayer.new()
	add_child(ui_player)

func play(name: String, at: Vector3, volume: float = 0, pitch: float = 1):
	if not streams.has(name): return
	var p = pool[cursor]
	cursor = (cursor + 1) % pool.size()
	p.stop()
	p.stream = streams[name]
	p.global_position = at
	p.volume_db = volume
	p.pitch_scale = pitch
	p.play()

func ui():
	ui_player.stream = streams.ui
	ui_player.play()

func stop_all():
	for player in pool:
		player.stop()
		player.stream=null
	ui_player.stop()
	ui_player.stream=null
