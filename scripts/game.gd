extends Node3D

var level: FacilityLevel
var player: PlayerRobot
var hud: TacticalHUD
var effects: CombatEffects
var enemies: Array[EnemyRobot] = []
var playing = false
var stage = 0
var elapsed = 0.0
var kills = 0
var benchmark = false
var capture = false
var test_runner: Node
var start_time = 0
var frame_samples: Array[float] = []
var benchmark_frames = 0
var benchmark_phase = 0
var benchmark_clock = 0.0
var benchmark_data: Array = []
var dynamic_clock = 0.0
const OBJECTIVE_TEXT = ["RELAY YARD / Activate the uplink", "COOLANT CONTROL / Override the pumps", "CORE HALL / Disable the containment lock", "EXTRACTION / Destroy Warden and transmit"]

func _ready():
	start_time=Time.get_ticks_msec()
	seed(9117)
	effects=CombatEffects.new();add_child(effects)
	level=FacilityLevel.new();level.game=self;add_child(level)
	player=PlayerRobot.new();player.game=self;add_child(player);player.position=FacilityLevel.SPAWNS[0]
	player.visual.animate(0,Vector3.ZERO,true,-.08)
	var layer=CanvasLayer.new();add_child(layer)
	hud=TacticalHUD.new();hud.game=self;layer.add_child(hud)
	var args=OS.get_cmdline_user_args()
	benchmark="--benchmark" in args
	capture="--capture" in args
	if "--integration" in args:
		test_runner=load("res://tests/integration.gd").new();test_runner.game=self;add_child(test_runner)
	elif benchmark or capture:
		call_deferred("start_game",false)
		if benchmark:player.benchmark_mode=true
	else:hud.show_menu("main")
	var ambience=AudioStreamPlayer3D.new();ambience.stream=Sound.streams.ambient;ambience.volume_db=-12;ambience.unit_size=70
	add_child(ambience);ambience.position=Vector3(0,2,-40)
	ambience.finished.connect(ambience.play);ambience.play()

func _exit_tree():
	Industrial.materials.clear()
	Industrial.meshes.clear()

func shutdown(code: int = 0):
	playing=false
	get_tree().paused=false
	Sound.stop_all()
	for node in find_children("*","AudioStreamPlayer3D",true,false):
		node.stop();node.stream=null
	for i in 5:await get_tree().process_frame
	get_tree().quit(code)

func start_game(continue_game: bool = false):
	get_tree().paused=false
	stage=clampi(int(Settings.checkpoint.get("stage",0)),0,3) if continue_game else 0
	if not continue_game:Settings.clear_checkpoint()
	for enemy in enemies:
		if is_instance_valid(enemy):enemy.queue_free()
	enemies.clear()
	for projectile in get_children():
		if projectile is EnemyProjectile:projectile.queue_free()
	player.global_position=FacilityLevel.SPAWNS[stage]
	player.velocity=Vector3.ZERO
	player.integrity=player.max_integrity
	player.ammo=[36,8,5];player.reserve=[288,64,35]
	player.reload_left=0;player.charge=0;player.invulnerable=2.0
	player.yaw=0;player.pitch=-.08;player.clear_input()
	for i in level.gates.size():level.gates[i].position.y=3.5
	level.restore_gates(stage)
	playing=true;elapsed=0;kills=0
	hud.show_menu("")
	hud.message("WRAITH ONLINE / Find the uplink",4)
	if not OS.has_feature("mobile") and not capture and not benchmark:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	spawn_stage(stage)

func spawn(kind: String, at: Vector3):
	var enemy=EnemyRobot.new();enemy.game=self;enemy.kind=kind;enemy.position=at;enemy.set_meta("stage",stage)
	add_child(enemy);enemies.append(enemy)

func spawn_stage(index: int):
	match index:
		0:
			spawn("drone",Vector3(4,2,-9));spawn("drone",Vector3(-4,2,-17))
			spawn("android",Vector3(6,.1,-23));spawn("android",Vector3(-7,.1,-26))
		1:
			spawn("android",Vector3(-5,.1,-40));spawn("android",Vector3(7,.1,-47));spawn("drone",Vector3(-7,2,-53));spawn("heavy",Vector3(0,.1,-57))
		2:
			spawn("android",Vector3(-7,.1,-73));spawn("android",Vector3(8,.1,-86));spawn("heavy",Vector3(0,.1,-93));spawn("drone",Vector3(5,2,-78));spawn("drone",Vector3(-8,2,-88))
		3:
			spawn("boss",Vector3(0,.1,-110));spawn("drone",Vector3(-6,2,-106));spawn("drone",Vector3(6,2,-112))

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:pause_game()
		elif event.physical_keycode==KEY_E and playing:interact()
		elif event.physical_keycode==KEY_F3:
			Settings.values.diagnostics=not Settings.values.diagnostics;Settings.save()
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index==JOY_BUTTON_START:pause_game()
		elif event.button_index==JOY_BUTTON_B and playing:interact()

func _notification(what):
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED] and playing:pause_game()
	if what==NOTIFICATION_WM_GO_BACK_REQUEST:pause_game()

func pause_game():
	if not playing:return
	playing=false;player.clear_input();hud.release_touches()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	get_tree().paused=true
	hud.show_menu("pause")

func resume_game():
	get_tree().paused=false;playing=true;hud.show_menu("")
	if not OS.has_feature("mobile"):Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func interact():
	var distance=player.global_position.distance_to(FacilityLevel.OBJECTIVES[stage])
	if distance>=4.5:return
	if stage==3 and alive_for_stage(3)>0:
		hud.message("INTERLOCK / Eliminate the Warden and its escorts",3);Sound.ui();return
	Sound.ui()
	if stage==3:
		Settings.clear_checkpoint();game_over(true);return
	level.open_gate(stage)
	stage+=1;Settings.save_checkpoint(stage)
	player.integrity=minf(player.max_integrity,player.integrity+95)
	for i in 3:player.reserve[i]+=CombatRules.WEAPONS[i].mag*2
	hud.message("CHECKPOINT / "+OBJECTIVE_TEXT[stage],4)
	spawn_stage(stage)

func alive_for_stage(index: int) -> int:
	var count=0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.get_meta("stage")==index:count+=1
	return count

func enemy_destroyed(_enemy: EnemyRobot):
	kills+=1
	if stage==3 and alive_for_stage(3)==0:hud.message("WARDEN OFFLINE / Transmit at the extraction terminal",5)

func game_over(won: bool):
	playing=false;player.clear_input();hud.release_touches()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	get_tree().paused=true
	hud.show_menu("complete" if won else "death")

func alert_enemies(at: Vector3, radius: float):
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.global_position.distance_to(at)<radius:
			enemy.memory=maxf(enemy.memory,3);enemy.last_seen=at

func radial_damage(at: Vector3, radius: float, amount: float, exclude):
	if player.global_position.distance_to(at)<radius:player.take_damage(amount*(1-player.global_position.distance_to(at)/radius),at)
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy!=exclude and not enemy.dead:
			var distance=enemy.global_position.distance_to(at)
			if distance<radius:enemy.take_damage(amount*(1-distance/radius),enemy.global_position+Vector3.UP*1.8,1,(enemy.global_position-at).normalized()*8)
	push_props(at,radius,amount*.12)

func push_props(at: Vector3, radius: float, force: float):
	for child in level.get_children():
		if child is RigidBody3D:
			var offset=child.global_position-at
			if offset.length()<radius:child.apply_central_impulse((offset.normalized()+Vector3.UP*.3)*force*(1-offset.length()/radius))

func _process(delta):
	if not playing:return
	elapsed+=delta
	if capture:
		benchmark_frames+=1
		if benchmark_frames==18:
			get_viewport().get_texture().get_image().save_png("res://capture-third-person.png")
			Settings.values.third_person=false
		if benchmark_frames==36:
			get_viewport().get_texture().get_image().save_png("res://capture-first-person.png")
			shutdown()
	if benchmark:run_benchmark(delta)
	if Settings.values.dynamic_resolution and not benchmark:
		dynamic_clock+=delta
		if dynamic_clock>2:
			dynamic_clock=0
			var fps=Engine.get_frames_per_second()
			var scale=get_viewport().scaling_3d_scale
			if fps<Settings.values.fps_limit*.88:scale-=.05
			elif fps>Settings.values.fps_limit*.97:scale+=.025
			get_viewport().scaling_3d_scale=clampf(scale,.5,Settings.values.render_scale)

func run_benchmark(delta: float):
	benchmark_clock+=delta
	player.integrity=player.max_integrity
	player.invulnerable=1
	player.fire_touch=benchmark_phase>=2
	player.move_stick=Vector2(sin(elapsed*.6)*.5,0) if benchmark_phase==0 else Vector2.ZERO
	if benchmark_clock>2:frame_samples.append(delta*1000)
	if benchmark_clock>9:
		frame_samples.sort()
		var average=0.0
		for value in frame_samples:average+=value
		average/=maxi(1,frame_samples.size())
		var metrics={"scenario":["exploration_third","exploration_first","combat_third","combat_first"][benchmark_phase],"frames":frame_samples.size(),"mean_frame_ms":average,"p95_frame_ms":frame_samples[mini(frame_samples.size()-1,int(frame_samples.size()*.95))],"fps":1000/maxf(.01,average),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"visible_primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"cpu_process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"render_scale":get_viewport().scaling_3d_scale,"preset":Settings.values.preset,"resolution":str(get_viewport().size),"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name()}
		benchmark_data.append(metrics)
		print("BENCHMARK "+JSON.stringify(metrics))
		if not DisplayServer.get_name()=="headless":get_viewport().get_texture().get_image().save_png("res://capture-benchmark-"+str(benchmark_phase)+".png")
		benchmark_phase+=1;benchmark_clock=0;frame_samples.clear()
		Settings.values.third_person=benchmark_phase%2==0
		if benchmark_phase==2:
			for i in 8:spawn("android" if i%3 else "heavy",Vector3(-9+i*2.5,.1,-15-i%2*7))
			player.reserve=[999,999,999]
		if benchmark_phase>=4:
			Settings.atomic_write("res://benchmark-results.json",{"environment":"desktop validation; not Android hardware", "samples":benchmark_data})
			shutdown()
