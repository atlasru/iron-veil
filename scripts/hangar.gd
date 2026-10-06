class_name MechHangar
extends Node3D
var game: Node3D
var display: RobotVisual
var camera: Camera3D
var environment: Environment
var shell: Node3D
var active=false
var orbit=-.57
var desired_orbit=-.57
var distance=8.5
var desired_distance=8.5
var focus="chassis"
var clock=0.0
var drag_id=-1
var key_lights: Array[Light3D] = []
func _ready():
	name="ServiceHangar";position=Vector3(0,0,70)
	shell=preload("res://assets/hangar.glb").instantiate();add_child(shell);RobotVisual.finish_asset(shell)
	var floor_body=StaticBody3D.new();floor_body.collision_layer=1;floor_body.collision_mask=0;add_child(floor_body)
	var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(36,.3,32);shape.shape=box;shape.position.y=-.15;floor_body.add_child(shape)
	var plinth=CollisionShape3D.new();var platform=CylinderShape3D.new();platform.radius=3.4;platform.height=.28;plinth.shape=platform;plinth.position.y=.14;floor_body.add_child(plinth)
	display=RobotVisual.new();display.kind="wraith";add_child(display);display.position=Vector3(0,.28,0)
	environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color(.025,.043,.055)
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color(.40,.51,.58);environment.ambient_light_energy=.55
	var sky=Sky.new();var sky_material=ProceduralSkyMaterial.new()
	sky_material.sky_top_color=Color(.055,.095,.15);sky_material.sky_horizon_color=Color(.4,.48,.53)
	sky_material.ground_bottom_color=Color(.04,.065,.08);sky_material.ground_horizon_color=Color(.29,.33,.34)
	sky.sky_material=sky_material;environment.sky=sky;environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode=Environment.TONE_MAPPER_ACES;environment.tonemap_exposure=1.15
	environment.glow_enabled=true;environment.glow_intensity=.5
	environment.fog_enabled=true;environment.fog_density=.009;environment.fog_light_color=Color(.12,.20,.23)
	camera=Camera3D.new();camera.near=.1;camera.far=75;camera.fov=49;camera.environment=environment;add_child(camera)
	spot(Vector3(-5,8,-4),Vector3(0,1.8,0),Color(1,.81,.59),7.5,19,40,true)
	spot(Vector3(5,7,3),Vector3(0,2,0),Color(.32,.69,1),8.0,18,42,true)
	spot(Vector3(1,6,-8),Vector3(0,2,0),Color(.74,.86,1),5.0,16,44,false)
	spot(Vector3(-8,10,8),Vector3(0,3,13),Color(1,.60,.27),5,26,52,false)
	for sx in [-1,1]:
		for z in [-10,9]:key_lights.append(Industrial.light(self,Vector3(sx*10,5.7,z),Color(.28,.63,.76),2.0,17))
	var fill=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-38,144,0);fill.light_color=Color(.64,.75,.85);fill.light_energy=1.5;add_child(fill)
	var probe=ReflectionProbe.new();probe.position=Vector3(0,4,0);probe.size=Vector3(33,12,29);probe.interior=true;probe.box_projection=true;probe.max_distance=34;add_child(probe)
	Industrial.label(self,"VEIL  /  SERVICE BAY 09",Vector3(0,7.8,15.0),.014,Color(.67,.80,.82)).rotation.y=PI
	Industrial.label(self,"ACTUATOR CLEARANCE",Vector3(-7,2.9,14.9),.008,Color(.95,.64,.29)).rotation.y=PI
	Industrial.label(self,"REACTOR SERVICE",Vector3(8.2,2.9,14.9),.008,Color(.43,.79,.9)).rotation.y=PI
	update_camera(0);set_active(false)
func spot(at:Vector3,target:Vector3,color:Color,energy:float,radius:float,angle:float,shadow:bool):
	var light=SpotLight3D.new();add_child(light);light.position=at;light.look_at(to_global(target))
	light.light_color=color;light.light_energy=energy;light.spot_range=radius;light.spot_angle=angle;light.spot_attenuation=1.15;light.shadow_enabled=shadow;key_lights.append(light)
func set_active(value:bool):
	active=value;visible=value;set_process(value);drag_id=-1
	if value:
		focus="chassis";desired_distance=8.5;desired_orbit=-.57
		display.set_first_person(false);display.set_weapon(int(Settings.values.loadout));display.reset_pose()
		camera.make_current();update_camera(0)
	apply_graphics()
func inspect_system(value:String):
	focus=value;desired_distance=6.0 if value!="chassis" else 8.5
	desired_orbit=PI-.25 if value=="reactor" else (-.30 if value=="optics" else -.7)
func apply_graphics():
	if not environment:return
	environment.glow_enabled=Settings.values.effects>0
	for light in key_lights:
		if light is SpotLight3D:light.shadow_enabled=(Settings.values.shadows>0 and light==key_lights[0]) or (Settings.values.shadows>1 and light==key_lights[1])
func _process(delta):
	clock+=delta;display.animate(delta,Vector3.ZERO,true,.035*sin(clock*.4))
	var crane=shell.get_node_or_null("bridge_crane")
	if crane:crane.position.z=sin(clock*.13)*1.4
	for side in ["L","R"]:
		var arm=shell.get_node_or_null("service_arm_"+side)
		if arm:arm.rotation.y=sin(clock*.21)*.07
	update_camera(delta)
func update_camera(delta:float):
	orbit=lerp_angle(orbit,desired_orbit,1-exp(-delta*5)) if delta>0 else desired_orbit
	distance=lerpf(distance,desired_distance,1-exp(-delta*5)) if delta>0 else desired_distance
	var target=Vector3(0,2.1,0)
	if focus=="optics":target=Vector3(0,2.98,-.35)
	if focus=="locomotion":target=Vector3(0,1.1,0)
	if focus=="reactor":target=Vector3(0,2.9,.5)
	camera.position=target+Vector3(sin(orbit)*distance,2.4,-cos(orbit)*distance)
	camera.look_at(to_global(target));camera.look_at(to_global(target)-camera.global_basis.x*(1.85 if focus=="chassis" else 1.25))
func _unhandled_input(event):
	if not active or game.hud.menu_kind in ["cinematic","settings"]:return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:desired_distance=clampf(desired_distance-.5,5.0,14.0)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:desired_distance=clampf(desired_distance+.5,5.0,14.0)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):desired_orbit-=event.relative.x*.005
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x>get_viewport().get_visible_rect().size.x*.46:drag_id=event.index
		elif event.index==drag_id:drag_id=-1
	if event is InputEventScreenDrag and event.index==drag_id:desired_orbit-=event.relative.x*.005

