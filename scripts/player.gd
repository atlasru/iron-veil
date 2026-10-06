class_name PlayerRobot
extends CharacterBody3D

var game: Node3D
var visual: RobotVisual
var camera: Camera3D
var yaw = 0.0
var pitch = -0.08
var integrity = 240.0
var max_integrity = 240.0
var weapon = 0
var ammo: Array = [36,8,5]
var reserve: Array = [288,64,35]
var cooldown = 0.0
var reload_left = 0.0
var charge = 0.0
var ads = false
var sprinting = false
var move_stick = Vector2.ZERO
var look_delta = Vector2.ZERO
var fire_touch = false
var ads_touch = false
var sprint_touch = false
var jump_requested = false
var camera_distance = 4.2
var camera_fraction = 1.0
var camera_bob = 0.0
var kick = Vector2.ZERO
var shake = 0.0
var invulnerable = 0.0
var sphere = SphereShape3D.new()
var was_grounded = false
var last_fall_speed = 0.0
var benchmark_mode = false
var stats = {"shots":0,"hits":0,"damage_received":0.0}

func _ready():
	collision_layer = 2
	collision_mask = 1|4|16
	floor_max_angle = deg_to_rad(48)
	floor_snap_length = .42
	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = .43
	capsule.height = 2.55
	collision.shape = capsule
	collision.position.y = 1.275
	add_child(collision)
	visual = RobotVisual.new()
	visual.is_player = true
	add_child(visual)
	camera = Camera3D.new()
	camera.near = .075
	camera.far = 180
	camera.current = true
	game.add_child(camera)
	sphere.radius = .22
	camera_distance = Settings.values.camera_distance if Settings.values.third_person else 0
	yaw = 0

func _unhandled_input(event):
	if not game.playing: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_delta += event.relative * .0025
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_V: switch_perspective()
			KEY_Q: switch_shoulder()
			KEY_R: reload_weapon()
			KEY_SPACE: jump_requested = true
			KEY_1: switch_weapon(0)
			KEY_2: switch_weapon(1)
			KEY_3: switch_weapon(2)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:switch_weapon((weapon+1)%3)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:switch_weapon((weapon+2)%3)
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A:jump_requested=true
			JOY_BUTTON_X:reload_weapon()
			JOY_BUTTON_Y:switch_weapon((weapon+1)%3)
			JOY_BUTTON_RIGHT_SHOULDER:switch_perspective()
			JOY_BUTTON_LEFT_SHOULDER:switch_shoulder()

func _physics_process(delta):
	if not game.playing: return
	cooldown = maxf(0,cooldown-delta)
	invulnerable = maxf(0,invulnerable-delta)
	var keyboard = Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	var stick=Vector2(Input.get_joy_axis(0,JOY_AXIS_LEFT_X),Input.get_joy_axis(0,JOY_AXIS_LEFT_Y))
	if stick.length()<.18:stick=Vector2.ZERO
	var movement=(keyboard+move_stick+stick).limit_length()
	if benchmark_mode: movement=move_stick
	var right_stick=Vector2(Input.get_joy_axis(0,JOY_AXIS_RIGHT_X),Input.get_joy_axis(0,JOY_AXIS_RIGHT_Y))
	if right_stick.length()>.18:look_delta+=right_stick*delta*2.4
	ads=ads_touch or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.get_joy_axis(0,JOY_AXIS_TRIGGER_LEFT)>.3
	sprinting=(sprint_touch or Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_joy_button_pressed(0,JOY_BUTTON_LEFT_STICK)) and movement.length()>.35 and not ads and reload_left<=0
	if Settings.values.gyro and (not Settings.values.gyro_ads_only or ads):
		var gyro=Input.get_gyroscope()
		look_delta += Vector2(-gyro.y,-gyro.x)*delta*Settings.values.gyro_sensitivity
	yaw-=look_delta.x*Settings.values.sensitivity
	pitch=clampf(pitch-look_delta.y*Settings.values.sensitivity*(-1 if Settings.values.invert_y else 1),-1.05,.85)
	look_delta=Vector2.ZERO
	var direction=Basis(Vector3.UP,yaw)*Vector3(movement.x,0,movement.y)
	var max_speed=8.5 if sprinting else (3.9 if ads else 5.5)
	var accel=17.0 if is_on_floor() else 6.0
	velocity.x=move_toward(velocity.x,direction.x*max_speed,accel*delta)
	velocity.z=move_toward(velocity.z,direction.z*max_speed,accel*delta)
	if not is_on_floor(): velocity.y -= 18*delta
	elif jump_requested:
		velocity.y=7.5
		Sound.play("servo",global_position,-6,.7)
	jump_requested=false
	last_fall_speed=velocity.y
	# Raise the body only when a low ledge actually blocks horizontal movement.
	if is_on_floor() and direction.length()>.1:
		var travel=Vector3(velocity.x,0,velocity.z)*delta
		if test_move(global_transform,travel):
			var raised=global_transform;raised.origin.y+=.31
			if not test_move(global_transform,Vector3.UP*.31) and not test_move(raised,travel):
				var probe=raised.origin+travel+direction.normalized()*.52
				var down=PhysicsRayQueryParameters3D.create(probe+Vector3.UP*.06,probe-Vector3.UP*.36,1)
				var step=get_world_3d().direct_space_state.intersect_ray(down)
				if step and step.normal.y>.7:global_position.y=maxf(global_position.y,step.position.y+.015)
	move_and_slide()
	if is_on_floor() and not was_grounded and last_fall_speed<-4:
		shake=minf(1,-last_fall_speed*.04)
		Sound.play("step",global_position,0,.6)
		game.effects.burst(global_position+Vector3.UP*.1,Vector3.UP,12,Color(.5,.53,.5),.45,2.3)
		game.push_props(global_position,3.4,minf(8,-last_fall_speed*.4))
	was_grounded=is_on_floor()
	for i in get_slide_collision_count():
		var hit_body=get_slide_collision(i)
		if hit_body.get_collider() is RigidBody3D:
			hit_body.get_collider().apply_central_impulse(-hit_body.get_normal()*movement.length()*(6 if sprinting else 2))
		elif sprinting and hit_body.get_collider() is EnemyRobot:
			hit_body.get_collider().stagger=maxf(hit_body.get_collider().stagger,.4)
			hit_body.get_collider().velocity+=direction*3
	visual.rotation.y=lerp_angle(visual.rotation.y,yaw,1-exp(-delta*14))
	var progress=0.0
	if reload_left>0:
		reload_left=maxf(0,reload_left-delta)
		progress=1-reload_left/CombatRules.WEAPONS[weapon].reload
		if reload_left==0:
			var moved=CombatRules.reload_transfer(ammo[weapon],reserve[weapon],CombatRules.WEAPONS[weapon].mag)
			ammo[weapon]=moved.x;reserve[weapon]=moved.y
	visual.animate(delta,velocity,is_on_floor(),pitch,progress,sprinting)
	var firing=fire_touch or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.get_joy_axis(0,JOY_AXIS_TRIGGER_RIGHT)>.3
	if firing and cooldown<=0 and reload_left<=0 and not sprinting:
		if ammo[weapon]<=0:reload_weapon()
		elif weapon==2:
			if charge==0:Sound.play("charge",visual.muzzle.global_position,-9)
			charge+=delta
			if charge>=CombatRules.WEAPONS[weapon].charge:shoot();charge=0
		else:shoot()
	else:charge=0

func _process(delta):
	if not is_instance_valid(camera):return
	var third=Settings.values.third_person
	var target_distance=(Settings.values.camera_distance*(.64 if ads else 1)) if third else 0.0
	camera_distance=lerpf(camera_distance,target_distance,1-exp(-delta*10))
	var rotation_basis=Basis.from_euler(Vector3(pitch,yaw,0))
	var eye=global_position+Vector3(0,2.34,0)
	var shoulder_offset=Settings.values.shoulder*(.68 if third else 0)
	var desired_offset=rotation_basis*Vector3(shoulder_offset,.13 if third else -.03,camera_distance)
	var space=get_world_3d().direct_space_state
	var query=PhysicsShapeQueryParameters3D.new()
	query.shape=sphere
	query.transform=Transform3D(Basis.IDENTITY,eye)
	query.motion=desired_offset
	query.collision_mask=1|16
	query.exclude=[get_rid()]
	var fractions=space.cast_motion(query)
	var safe_fraction=fractions[0] if fractions.size()>0 else 1.0
	# Fast inward correction, slower outward return keeps the camera outside walls.
	camera_fraction=safe_fraction if safe_fraction<camera_fraction else lerpf(camera_fraction,safe_fraction,1-exp(-delta*8))
	var position_target=eye+desired_offset*maxf(0,camera_fraction-.015)
	camera.global_position=position_target
	kick=kick.move_toward(Vector2.ZERO,delta*.18)
	shake=move_toward(shake,0,delta*2)
	var noise=Vector3(sin(Time.get_ticks_msec()*.08),cos(Time.get_ticks_msec()*.07),0)*shake*.008*Settings.values.shake
	camera.rotation=Vector3(pitch+kick.x+noise.x,yaw+kick.y+noise.y,0)
	camera.fov=lerpf(camera.fov,Settings.values.fov*(.72 if ads else (1.07 if sprinting else 1)),1-exp(-delta*12))
	visual.set_first_person(camera_distance<.75)

func shoot():
	var spec=CombatRules.WEAPONS[weapon]
	ammo[weapon]-=1
	cooldown=spec.interval
	stats.shots+=1
	visual.recoil=.8 if weapon else .35
	kick+=Vector2(spec.kick,randf_range(-spec.kick*.3,spec.kick*.3))
	shake=spec.kick*4
	var from=visual.muzzle.global_position
	var space=get_world_3d().direct_space_state
	var aim_query=PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*120,1|8|16)
	aim_query.collide_with_areas=true
	aim_query.exclude=[get_rid()]
	var aim_hit=space.intersect_ray(aim_query)
	var target=aim_hit.position if aim_hit else aim_query.to
	var base_direction=(target-from).normalized()
	for i in spec.pellets:
		var spread=spec.spread*(.38 if ads else 1)
		var direction=(base_direction+camera.global_basis.x*randf_range(-spread,spread)+camera.global_basis.y*randf_range(-spread,spread)).normalized()
		var query=PhysicsRayQueryParameters3D.create(from,from+direction*120,1|8|16)
		query.collide_with_areas=true
		query.exclude=[get_rid()]
		var result=space.intersect_ray(query)
		var endpoint=result.position if result else query.to
		game.effects.tracer(from,endpoint,spec.color,weapon==2)
		if result:
			var body=result.collider
			game.effects.impact(result.position,result.normal,str(body.get_meta("surface","concrete")),weapon==2,body is StaticBody3D)
			if body is DamageZone:
				body.enemy.take_damage(spec.damage,result.position,weapon,direction*(14 if weapon else 3),body.zone)
				stats.hits+=1
				game.hud.hitmarker=.18
			elif body is BreakableProp:body.take_damage(spec.damage,result.position,direction*spec.damage*.35)
	game.effects.muzzle(from,spec.color)
	Sound.play(["autocannon","breacher","coil"][weapon],from,-3,randf_range(.95,1.05))
	game.alert_enemies(global_position,45)

func reload_weapon():
	if reload_left>0 or ammo[weapon]>=CombatRules.WEAPONS[weapon].mag or reserve[weapon]<=0:return
	reload_left=CombatRules.WEAPONS[weapon].reload
	charge=0
	Sound.play("reload",global_position,-7)

func switch_weapon(index: int):
	if index==weapon:return
	weapon=index
	reload_left=0;charge=0;cooldown=.3
	visual.set_weapon(index)
	Sound.play("servo",global_position,-10)

func switch_perspective():
	Settings.values.third_person=not Settings.values.third_person
	print("IRON_VEIL_VIEW / "+("3P" if Settings.values.third_person else "1P"))
	Settings.save()
	Sound.ui()

func switch_shoulder():
	Settings.values.shoulder*=-1
	Settings.save()

func take_damage(amount: float, attacker: Vector3):
	if integrity<=0 or invulnerable>0 or not game.playing:return
	integrity=maxf(0,integrity-amount)
	stats.damage_received+=amount
	visual.hit=.4
	shake=.22
	game.hud.damage_flash=.6
	game.hud.damage_direction=(attacker-global_position).normalized()
	if integrity<=0:game.game_over(false)

func clear_input():
	move_stick=Vector2.ZERO;look_delta=Vector2.ZERO
	fire_touch=false;ads_touch=false;sprint_touch=false;jump_requested=false;charge=0
