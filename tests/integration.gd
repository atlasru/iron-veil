extends Node

var game: Node3D
var checks=0
var failures=0

func check(condition: bool, label: String):
	checks+=1
	if not condition:failures+=1;push_error("FAIL: "+label)

func _ready():
	call_deferred("run")

func ticks(count: int):
	for i in count:await get_tree().physics_frame

func idle_frames(count: int):
	for i in count:await get_tree().process_frame

func run():
	game.hud.show_menu("main")
	await idle_frames(4)
	var deploy=game.hud.menu.get_child(0).get_child(0)
	var deploy_at=get_viewport().get_screen_transform()*deploy.get_global_rect().get_center()
	for pressed in [true,false]:
		var touch=InputEventScreenTouch.new();touch.index=0;touch.position=deploy_at;touch.pressed=pressed
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
		await idle_frames(2)
	check(game.playing and game.hud.menu_kind=="","native touch activates the main menu and starts gameplay")
	if not game.playing:game.start_game(false)
	game.hud.mobile=true
	var before_touch_ammo=game.player.ammo.duplicate()
	var move_touch=InputEventScreenTouch.new();move_touch.index=0
	move_touch.position=get_viewport().get_screen_transform()*(Vector2(170,720)*game.hud.scale_ui+game.hud.origin)
	move_touch.pressed=true;Input.parse_input_event(move_touch);Input.flush_buffered_events();await ticks(3)
	check(game.player.ammo==before_touch_ammo and not game.player.fire_touch,"touch movement does not become a desktop fire click")
	var move_release=move_touch.duplicate();move_release.pressed=false
	Input.parse_input_event(move_release);Input.flush_buffered_events();await ticks(3)
	var fire_at=get_viewport().get_screen_transform()*(Vector2(1450,640)*game.hud.scale_ui+game.hud.origin)
	var tap_ammo=game.player.ammo[0]
	for pressed in [true,false]:
		var fire_event=InputEventScreenTouch.new();fire_event.index=0;fire_event.position=fire_at;fire_event.pressed=pressed
		Input.parse_input_event(fire_event)
	Input.flush_buffered_events()
	await ticks(3)
	check(game.player.ammo[0]==tap_ammo-1,"native fire tap between physics steps produces one shot")
	await ticks(20)
	var p=game.player
	check(game.enemies.size()==4,"initial combat encounter")
	check(p.is_on_floor(),"player spawned on facility collision")
	p.invulnerable=1000
	p.benchmark_mode=true;p.move_stick=Vector2(0,-1)
	var walk_start=p.global_position
	await ticks(50)
	check(walk_start.z-p.global_position.z>3,"accelerated locomotion moves through yard")
	p.move_stick=Vector2.ZERO;p.jump_requested=true;await ticks(12)
	check(p.global_position.y>0.7,"jump leaves floor")
	await ticks(65)
	check(p.is_on_floor(),"heavy landing returns to floor")
	p.global_position=Vector3(-21,.1,9);p.velocity=Vector3.ZERO;p.move_stick=Vector2(0,-1)
	await ticks(125)
	check(p.global_position.y>2.5,"climb real stair geometry onto catwalk")
	p.move_stick=Vector2.ZERO;p.global_position=FacilityLevel.SPAWNS[0];p.velocity=Vector3.ZERO
	await ticks(20)
	var hp=p.integrity;var ammo=p.ammo.duplicate();var pos=p.global_position
	p.switch_perspective();await ticks(3)
	check(p.integrity==hp and p.ammo==ammo and p.global_position.distance_to(pos)<.1,"perspective preserves simulation")
	p.switch_shoulder();check(Settings.values.shoulder==-1 or Settings.values.shoulder==1,"shoulder switches")
	# Three simultaneous touch owners: move, look, fire.
	game.hud.mobile=true
	for item in [[0,Vector2(170,720)],[1,Vector2(950,430)],[2,Vector2(1450,640)]]:
		var event=InputEventScreenTouch.new();event.index=item[0];event.position=item[1]*game.hud.scale_ui+game.hud.origin;event.pressed=true;game.hud._input(event)
	check(game.hud.touches.size()==3 and p.fire_touch,"independent multitouch fire")
	var drag=InputEventScreenDrag.new();drag.index=1;drag.relative=Vector2(20,10)*game.hud.scale_ui;game.hud._input(drag)
	check(p.look_delta.length()>0 and p.fire_touch,"look continues while firing")
	game.hud.release_touches();check(not p.fire_touch and p.move_stick==Vector2.ZERO,"lifecycle releases touches")
	# Heavy weak points and subsystem effects modify actual AI values.
	game.spawn("heavy",Vector3(8,.1,5));var e=game.enemies.back();await ticks(1)
	var arm_at=e.visual.limbs.hardpoint_R.to_global(Vector3(0,0,0))
	var arm_query=PhysicsRayQueryParameters3D.create(arm_at-e.global_basis.z*2,arm_at+e.global_basis.z*2,8)
	arm_query.collide_with_areas=true
	var arm_hit=p.get_world_3d().direct_space_state.intersect_ray(arm_query)
	check(arm_hit and arm_hit.collider is DamageZone and arm_hit.collider.zone=="arm","mounted weapon hardpoints have reachable localized ray hitboxes")
	e.take_damage(100,e.visual.limbs.hardpoint_R.global_position,0,Vector3.ZERO)
	check(e.zone_damage.arm>0 and e.health<e.max_health,"localized arm damage")
	e.take_damage(180,e.visual.to_global(Vector3(.1,.5,0)),2,Vector3.ZERO)
	check(e.zone_damage.leg>e.max_health*.24,"leg subsystem damaged")
	e.take_damage(2000,e.visual.to_global(Vector3(0,1.8,0)),2,Vector3.ZERO)
	check(e.dead and e.collision_layer==0,"destruction removes combat collision")
	# Close-world muzzle ray: geometry must win over a visible target.
	var wall=game.level.solid(Vector3(0,1.7,5),Vector3(3,3,.4),"concrete",false)
	await ticks(1)
	var query=PhysicsRayQueryParameters3D.create(Vector3(0,1.7,7),Vector3(0,1.7,3),1)
	var result=p.get_world_3d().direct_space_state.intersect_ray(query)
	check(result and result.collider==wall,"muzzle validation stops at nearby wall")
	wall.queue_free()
	# Check camera sphere collision in a corner.
	Settings.values.third_person=true
	p.global_position=Vector3(22.8,.1,10);p.yaw=-PI*.5;await ticks(35)
	check(p.camera.global_position.x<23.8,"third-person camera stays inside walls")
	# Objective progression persists and unseals the next zone.
	p.global_position=FacilityLevel.OBJECTIVES[0]+Vector3.UP*.1;game.interact()
	check(game.stage==1 and Settings.checkpoint.stage==1,"checkpoint stage saved")
	await ticks(135)
	check(game.level.gates[0].position.y>10,"interlock opens physically")
	p.global_position=FacilityLevel.OBJECTIVES[1]+Vector3.UP*.1;game.interact()
	p.global_position=FacilityLevel.OBJECTIVES[2]+Vector3.UP*.1;game.interact()
	check(game.stage==3 and game.alive_for_stage(3)==3,"final encounter spawned")
	p.global_position=FacilityLevel.OBJECTIVES[3]+Vector3.UP*.1;game.interact()
	check(game.playing,"extraction blocked by live Warden")
	for enemy in game.enemies:
		if is_instance_valid(enemy) and enemy.get_meta("stage")==3:enemy.destroy()
	game.interact()
	check(game.hud.menu_kind=="complete" and Settings.checkpoint.is_empty(),"mission completion and checkpoint cleared")
	get_tree().paused=false
	print("INTEGRATION: %d checks, %d failures" % [checks,failures])
	game.shutdown(1 if failures else 0)
