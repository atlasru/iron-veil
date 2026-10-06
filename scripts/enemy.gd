class_name EnemyRobot
extends CharacterBody3D

var game: Node3D
var kind = "android"
var visual: RobotVisual
var drone: Node3D
var health = 140.0
var max_health = 140.0
var zone_damage = {"sensor":0.0,"core":0.0,"arm":0.0,"leg":0.0}
var state = "patrol"
var memory = 0.0
var last_seen = Vector3.ZERO
var stagger = 0.0
var cooldown = 1.2
var ai_clock = 0.0
var age = 0.0
var aim_pitch = 0.0
var dead = false
var origin = Vector3.ZERO
var target_velocity = Vector3.ZERO
var path: PackedVector3Array = []
var path_clock = 0.0
var strafe_sign = 1.0
var charge = 0.0
var core_light: OmniLight3D

func _ready():
	collision_layer=4;collision_mask=1|2|4|16
	set_meta("surface","metal")
	origin=global_position
	strafe_sign=-1 if int(origin.x+origin.z)%2==0 else 1
	max_health={"drone":65.0,"android":150.0,"heavy":430.0,"boss":920.0}[kind]
	health=max_health
	visual=RobotVisual.new()
	visual.kind={"drone":"scout","android":"sentinel","heavy":"heavy","boss":"warden"}[kind]
	add_child(visual);visual.set_weapon(1 if kind in ["heavy","boss"] else 0)
	var cfg=visual.profile
	var collision=CollisionShape3D.new();var capsule=CapsuleShape3D.new()
	capsule.radius={"drone":.48,"android":.66,"heavy":1.18,"boss":1.58}[kind]
	capsule.height=cfg.height;collision.shape=capsule;collision.position.y=cfg.height*.5;add_child(collision)
	if kind=="drone":drone=visual
	DamageZone.attach(visual.limbs.torso,self,"core",Vector3.ZERO,Vector3(cfg.width*.72,.78 if kind=="heavy" else 1.06,cfg.depth*.98))
	DamageZone.attach(visual.limbs.sensor,self,"sensor",Vector3.ZERO,Vector3(.70,.24,.34))
	for side in ["L","R"]:
		if visual.limbs.has("hardpoint_"+side):DamageZone.attach(visual.limbs["hardpoint_"+side],self,"arm",Vector3.ZERO,Vector3(.55,.48,.73))
	DamageZone.attach(visual.weapon_holder,self,"arm",Vector3(0,0,.05),Vector3(.56,.55,.88))
	for leg in visual.legs:
		for segment in ["thigh","shin"]:
			DamageZone.attach(visual.limbs[segment+"_"+leg.name],self,"leg",Vector3(0,-.53*cfg.leg_scale,0),Vector3(.46*cfg.leg_scale,1.1*cfg.leg_scale,.43*cfg.leg_scale))
	core_light=Industrial.light(self,Vector3(0,cfg.torso_y,-cfg.depth*.6),Color(1,.18,.05),.12,3)

func _physics_process(delta):
	if not game.playing or dead or game.capture:return
	age+=delta
	stagger=maxf(0,stagger-delta)
	cooldown=maxf(0,cooldown-delta)
	memory=maxf(0,memory-delta)
	ai_clock-=delta
	path_clock-=delta
	var player_distance=global_position.distance_to(game.player.global_position)
	if player_distance>80:
		if visual:visual.visible=false
		return
	if visual:visual.visible=true
	if ai_clock<=0:
		ai_clock=.17 if player_distance<35 else .5
		think(player_distance)
	if kind=="drone":
		velocity=velocity.move_toward(target_velocity,delta*13)
		velocity.y=clampf((2.1-global_position.y)*3,-3,3)+sin(age*2.1)*.25
		drone.rotation.z=lerpf(drone.rotation.z,-velocity.x*.035,delta*4)
	else:
		velocity.x=move_toward(velocity.x,target_velocity.x,delta*9)
		velocity.z=move_toward(velocity.z,target_velocity.z,delta*9)
		if not is_on_floor():velocity.y-=18*delta
	if stagger>0:velocity.x*=.91;velocity.z*=.91
	move_and_slide()
	if state in ["engage","pursue","search"]:
		var direction=(last_seen-global_position)
		var heading=atan2(-direction.x,-direction.z)
		rotation.y=lerp_angle(rotation.y,heading,1-exp(-delta*5))
		aim_pitch=atan2(game.player.global_position.y+2.5-visual.weapon_holder.global_position.y,maxf(1,Vector2(direction.x,direction.z).length()))
	elif target_velocity.length()>.1:rotation.y=lerp_angle(rotation.y,atan2(-target_velocity.x,-target_velocity.z),delta*3)
	if visual:
		visual.animate(delta,velocity,is_on_floor(),aim_pitch,0,false,zone_damage.leg/max_health)
		core_light.light_energy=.1+charge*1.5
	if state=="engage" and cooldown<=0 and stagger<=0:
		if kind in ["heavy","boss"]:
			charge+=delta
			if charge>=1.15:fire();charge=0
		elif kind=="drone":
			if player_distance<2.7:
				game.player.take_damage(13,global_position);cooldown=1.1
			else:target_velocity=(last_seen-global_position).normalized()*9
		else:fire()
	else:charge=0

func think(distance: float):
	var eye=visual.limbs.sensor.global_position
	var target=game.player.global_position+Vector3.UP*2.4
	var detection=38 if zone_damage.sensor<max_health*.2 else 20
	var visible=false
	if distance<detection:
		var query=PhysicsRayQueryParameters3D.create(eye,target,1|2|16)
		query.exclude=[get_rid()]
		var result=get_world_3d().direct_space_state.intersect_ray(query)
		visible=result and result.collider==game.player
		if visible:memory=5.5;last_seen=game.player.global_position
	state=CombatRules.ai_state(visible,distance,memory,stagger,dead)
	var speed=5.6 if kind=="drone" else (2.0 if kind in ["heavy","boss"] else 3.6)
	if zone_damage.leg>max_health*.24:speed*=.46
	var desired=Vector3.ZERO
	if state=="engage":
		var to_player=(last_seen-global_position);to_player.y=0
		var direction=to_player.normalized()
		var preferred=3 if kind=="drone" else (19 if kind in ["heavy","boss"] else 13)
		if distance>preferred+3:desired=direction
		elif distance<preferred-4:desired=-direction
		if kind=="android":desired+=Vector3(direction.z,0,-direction.x)*strafe_sign*.7
		if kind=="boss":desired+=Vector3(direction.z,0,-direction.x)*sin(age*.3)*.4
	elif state in ["pursue","search"]:
		if path_clock<=0:
			path_clock=.8;path=game.level.path_to(global_position,last_seen)
		while path.size()>0 and global_position.distance_to(path[0])<1.3:path.remove_at(0)
		if path.size()>0:desired=path[0]-global_position
	elif state=="patrol":desired=origin+Vector3(sin(age*.25)*3,0,cos(age*.25)*3)-global_position
	desired.y=0
	if desired.length()>.1:
		desired=desired.normalized()
		var obstacle_query=PhysicsRayQueryParameters3D.create(eye,eye+desired*2.3,1|16)
		var obstacle=get_world_3d().direct_space_state.intersect_ray(obstacle_query)
		if obstacle:
			strafe_sign*=-1
			desired=desired.slide(obstacle.normal)
			if desired.length()<.1:desired=Vector3(-obstacle.normal.z,0,obstacle.normal.x)*strafe_sign
	target_velocity=desired*speed if stagger<=0 else Vector3.ZERO

func fire():
	var from=visual.muzzle.global_position
	var target=game.player.global_position+Vector3.UP*2.25
	var accuracy=.026 if kind in ["heavy","boss"] else .08
	if zone_damage.sensor>max_health*.15:accuracy*=3
	var direction=(target-from).normalized()+Vector3(randf_range(-accuracy,accuracy),randf_range(-accuracy,accuracy),randf_range(-accuracy,accuracy))
	var projectile=EnemyProjectile.new()
	projectile.game=game;projectile.source=global_position
	projectile.velocity=direction.normalized()*(29 if kind in ["heavy","boss"] else 62)
	projectile.damage=32 if kind in ["heavy","boss"] else 9
	projectile.heavy=kind in ["heavy","boss"]
	projectile.excluded.append(get_rid())
	game.add_child(projectile);projectile.global_position=from
	game.effects.muzzle(from,Color(1,.2,.05))
	Sound.play("breacher" if projectile.heavy else "autocannon",from,-8,.8)
	visual.recoil=.5
	cooldown=(2.1 if projectile.heavy else .32)*(1.7 if zone_damage.arm>max_health*.2 else 1)

func take_damage(base: float, at: Vector3, weapon_id: int, impulse: Vector3, hit_zone: String = ""):
	if dead:return
	var zone=hit_zone if hit_zone!="" else ("core" if kind=="drone" else visual.zone_at(at))
	var amount=CombatRules.damage(base,zone,kind,weapon_id)
	health-=amount;zone_damage[zone]+=amount
	last_seen=game.player.global_position;memory=8
	stagger=maxf(stagger,.7 if weapon_id==1 else (.45 if weapon_id==2 else .06))
	velocity+=impulse*(.06 if kind in ["heavy","boss"] else .16)
	if visual:visual.damage_visual(zone,zone_damage[zone]/(max_health*.4))
	if health<=0:destroy()

func destroy():
	if dead:return
	dead=true;state="dead"
	collision_layer=0;collision_mask=0
	for area in find_children("*","Area3D",true,false):area.collision_layer=0
	game.effects.explosion(global_position+Vector3.UP*1.2,kind in ["heavy","boss"])
	game.effects.debris(global_position+Vector3.UP*1.2,8 if kind in ["heavy","boss"] else 5,Industrial.material("metal"))
	if visual:
		var body=RigidBody3D.new();body.collision_layer=1|32;body.collision_mask=1|16|32
		body.mass={"drone":35.0,"android":180.0,"heavy":480.0,"boss":1100.0}[kind]
		body.linear_damp=.5;body.angular_damp=.9
		var shape=CollisionShape3D.new();var box=BoxShape3D.new()
		box.size=Vector3(visual.profile.width*.75,.92,visual.profile.depth)
		shape.shape=box;shape.position.y=visual.profile.torso_y;body.add_child(shape)
		game.effects.add_child(body);body.global_transform=visual.global_transform
		visual.reparent(body);visual.transform=Transform3D.IDENTITY;visual.set_first_person(false)
		body.linear_velocity=Vector3(randf_range(-.6,.6),.9,randf_range(-.6,.6));body.angular_velocity=Vector3(.35,randf_range(-.35,.35),.22)
		var tween=body.create_tween();tween.tween_method(visual.wreck_pose,0.0,1.0,1.25).set_trans(Tween.TRANS_QUAD)
		get_tree().create_timer(35).timeout.connect(body.queue_free)

	game.enemy_destroyed(self)
	get_tree().create_timer(9).timeout.connect(queue_free)
