class_name FacilityLevel
extends Node3D

var game: Node3D
var grid = AStarGrid2D.new()
var blockers: Array[Rect2] = []
var terminals: Array[Node3D] = []
var gates: Array[Node3D] = []
var lamps: Array[Light3D] = []
var environment: Environment
var ambient: AudioStreamPlayer3D
const OBJECTIVES = [Vector3(-13,0,-24),Vector3(13,0,-53),Vector3(-12,0,-93),Vector3(0,0,-116)]
const SPAWNS = [Vector3(0,.1,9),Vector3(0,.1,-33),Vector3(0,.1,-66),Vector3(0,.1,-103)]

func _ready():
	build_environment()
	build_yard()
	build_maintenance()
	build_reactor()
	build_background()
	build_navigation()
	batch_static_geometry()
	apply_graphics()

func batch_static_geometry():
	var groups={}
	for node in find_children("*","MeshInstance3D",true,false):
		var ancestor=node.get_parent();var dynamic=false
		while ancestor and ancestor!=self:
			if ancestor is RigidBody3D or ancestor in gates:dynamic=true;break
			ancestor=ancestor.get_parent()
		if dynamic or not node.material_override:continue
		var key=str(node.mesh.get_rid())+str(node.material_override.get_rid())
		if not groups.has(key):groups[key]=[]
		groups[key].append(node)
	for group in groups.values():
		if group.size()<3:continue
		# Spatial buckets keep whole-facility instances from defeating frustum culling.
		var buckets={}
		for node in group:
			var cell=Vector2i(floori(node.global_position.x/16),floori(node.global_position.z/20))
			if not buckets.has(cell):buckets[cell]=[]
			buckets[cell].append(node)
		for bucket in buckets.values():
			if bucket.size()<2:continue
			var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=bucket[0].mesh;multi.instance_count=bucket.size()
			for i in bucket.size():multi.set_instance_transform(i,bucket[i].global_transform)
			var instance=MultiMeshInstance3D.new();instance.multimesh=multi;instance.material_override=bucket[0].material_override;instance.visibility_range_end=135
			add_child(instance)
			for node in bucket:node.hide()

func solid(at: Vector3, size: Vector3, mat: String = "metal", blocks: bool = true) -> Node3D:
	var node=Industrial.box(self,at,size,mat,true)
	if blocks and at.y-size.y*.5<1.8 and at.y+size.y*.5>.3:
		blockers.append(Rect2(Vector2(at.x-size.x*.5-.55,at.z-size.z*.5-.55),Vector2(size.x+1.1,size.z+1.1)))
	return node

func build_environment():
	var world=WorldEnvironment.new();environment=Environment.new();world.environment=environment;add_child(world)
	environment.background_mode=Environment.BG_SKY
	var sky=Sky.new();var material=ProceduralSkyMaterial.new()
	material.sky_top_color=Color(.075,.14,.19);material.sky_horizon_color=Color(.43,.53,.55)
	material.ground_bottom_color=Color(.045,.064,.07);material.ground_horizon_color=Color(.32,.41,.43)
	material.sun_angle_max=10;material.sun_curve=.08;sky.sky_material=material;environment.sky=sky
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color(.46,.61,.68)
	environment.ambient_light_energy=.56
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure=1.1
	environment.fog_enabled=true
	environment.fog_light_color=Color(.24,.37,.42)
	environment.fog_density=.008
	environment.fog_aerial_perspective=.25
	environment.glow_enabled=true
	environment.glow_intensity=.6
	var sun=DirectionalLight3D.new();sun.name="Sun";sun.rotation_degrees=Vector3(-43,-27,0)
	sun.light_color=Color(1,.85,.66);sun.light_energy=1.9;sun.shadow_enabled=true
	sun.directional_shadow_max_distance=80;sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_bias=.04;sun.light_angular_distance=.3;add_child(sun)

func wall_panels(x: float, z_start: float, count: int, height: float):
	for i in count:
		var z=z_start-i*5
		solid(Vector3(x,height*.5,z),Vector3(.6,height,5),"concrete")
		Industrial.box(self,Vector3(x-signf(x)*.4,height*.56,z),Vector3(.15,height*.5,4.4),"paint")
		Industrial.box(self,Vector3(x-signf(x)*.5,.45,z),Vector3(.2,.18,4.7),"yellow")
		Industrial.box(self,Vector3(x-signf(x)*.5,height-.35,z),Vector3(.22,.15,4.8),"dark")
		for y in [.7,height-.7]:Industrial.box(self,Vector3(x-signf(x)*.57,y,z),Vector3(.11,.25,.6),"rust")

func beam(at: Vector3, height: float):
	solid(at+Vector3.UP*height*.5,Vector3(.5,height,.65),"dark")
	for x in [-.29,.29]:Industrial.box(self,at+Vector3(x,height*.5,0),Vector3(.13,height,.83),"metal")
	Industrial.box(self,at+Vector3.UP*.1,Vector3(1,.2,1.1),"rust")

func shipping_container(at: Vector3, color: String, rotation_y: float = 0):
	var root=solid(at+Vector3.UP*1.6,Vector3(3.8,3.2,8),color)
	root.rotation.y=rotation_y
	for z in range(-3,4):
		for x in [-1.93,1.93]:Industrial.box(root,Vector3(x,0,z),Vector3(.08,2.95,.08),"dark")
	for y in [-1.51,1.51]:Industrial.box(root,Vector3(0,y,0),Vector3(3.9,.13,8.1),"metal")
	Industrial.label(root,"IV / 08",Vector3(0,.4,4.02),.007,Color(.79,.84,.77))
	for x in [-1.25,1.25]:Industrial.box(root,Vector3(x,0,4.06),Vector3(.075,2.9,.08),"metal")

func prop(at: Vector3, explosive: bool = false):
	var p=BreakableProp.new();p.game=game;p.explosive=explosive
	add_child(p);p.position=at

func terminal(at: Vector3, number: int):
	var node=Node3D.new();node.position=at;add_child(node)
	Industrial.box(node,Vector3(0,.65,0),Vector3(1.05,1.3,.65),"dark",true)
	var screen=Industrial.box(node,Vector3(0,1.43,-.05),Vector3(1.28,.72,.35),"paint")
	screen.rotation.x=-.25
	Industrial.box(node,Vector3(0,1.49,.17),Vector3(.94,.45,.025),"cyan")
	Industrial.label(node,"NODE 0"+str(number+1),Vector3(0,2.25,0),.009,Color(.66,.95,.46))
	lamps.append(Industrial.light(node,Vector3(0,1.9,.6),Color(.35,.8,1),1.2,4))
	terminals.append(node)

func build_yard():
	solid(Vector3(0,-.4,-9),Vector3(48,.8,48),"concrete",false)
	wall_panels(-24,11,10,7);wall_panels(24,11,10,7)
	solid(Vector3(0,4,15),Vector3(48,8,.6),"concrete")
	for x in [-18,-9,9,18]:
		beam(Vector3(x,0,-29),9)
		Industrial.box(self,Vector3(x,8.7,-9),Vector3(.9,.8,40),"dark")
		for z in [-25,-8,9]:
			Industrial.box(self,Vector3(x,8.2,z),Vector3(2,.1,.65),"white")
	for at in [Vector3(-16,0,-4),Vector3(-17,0,-15),Vector3(13,0,-11),Vector3(16,0,-24)]:shipping_container(at,"paint" if at.x<0 else "rust")
	for z in range(-27,13,4):
		Industrial.box(self,Vector3(0,.01,z),Vector3(.17,.02,1.4),"yellow")
		for x in [-7,7]:Industrial.box(self,Vector3(x,.012,z),Vector3(.075,.025,3.8),"yellow")
	for i in 8:prop(Vector3(-8+(i%4)*4,0,-5-floorf(i/4.0)*15),i in [2,5])
	for x in [-22,22]:
		Industrial.cylinder(self,Vector3(x,6.6,-8),.3,38,"rust",true)
		for z in [-23,-12,-1,10]:Industrial.cylinder(self,Vector3(x,6.6,z),.37,.18,"metal",true)
	Industrial.label(self,"VEIL INDUSTRIAL / 09",Vector3(0,6.2,-30),.026,Color(.73,.85,.81))
	Industrial.label(self,"RELAY YARD",Vector3(-13,4.3,-29.5),.016)
	terminal(OBJECTIVES[0],0)
	gate(-32,0)
	# Accessible 3.0m maintenance catwalk with real stairs and guardrails.
	solid(Vector3(-21,2.85,-10.6),Vector3(4,.3,22.2),"floor",false)
	stairs(Vector3(-21,0,8),3.0,4.0,15)
	for z in range(-20,3,3):
		Industrial.box(self,Vector3(-18.9,3.5,z),Vector3(.08,1.2,.08),"yellow")
	Industrial.box(self,Vector3(-18.9,4,-10.6),Vector3(.07,.07,22.2),"yellow")
	lamps.append(Industrial.light(self,Vector3(-10,6,-17),Color(.34,.69,.8),2,16))

func stairs(start: Vector3, height: float, width: float, count: int):
	var depth=.55
	for i in count:
		var h=height*(i+1)/count
		solid(start+Vector3(0,h*.5,-i*depth),Vector3(width,h,depth+.015),"floor",false)
		Industrial.box(self,start+Vector3(0,h+.013,-i*depth+depth*.42),Vector3(width,.024,.08),"yellow")

func gate(z: float, index: int):
	solid(Vector3(-16.5,4,z),Vector3(15,8,1),"concrete")
	solid(Vector3(16.5,4,z),Vector3(15,8,1),"concrete")
	solid(Vector3(0,7.5,z),Vector3(18,1,1.5),"dark")
	var door=solid(Vector3(0,3.5,z),Vector3(17,7,.65),"metal",false)
	for x in range(-7,8,2):Industrial.box(door,Vector3(x,0,.38),Vector3(.4,6.6,.1),"paint")
	Industrial.box(door,Vector3(0,0,.42),Vector3(.12,6.8,.05),"red")
	Industrial.label(door,"0"+str(index+1)+" / INTERLOCK",Vector3(0,1.9,.44),.012)
	gates.append(door)

func build_maintenance():
	solid(Vector3(0,-.4,-48),Vector3(48,.8,32),"floor",false)
	wall_panels(-24,-36,6,8);wall_panels(24,-36,6,8)
	solid(Vector3(0,8.1,-48),Vector3(48,.4,32),"dark",false)
	for z in [-37,-44,-51,-58]:
		for x in [-19,19]:beam(Vector3(x,0,z),8)
		Industrial.box(self,Vector3(0,7.7,z),Vector3(44,.35,.35),"metal")
		Industrial.box(self,Vector3(0,7.48,z),Vector3(9,.12,.3),"cyan")
		lamps.append(Industrial.light(self,Vector3(0,6,z),Color(.28,.63,.7),1.4,12))
	for x in [-14,14]:
		for z in [-39,-47]:
			var machine=solid(Vector3(x,1.65,z),Vector3(4,3.3,4.5),"paint")
			for y in [-.8,-.3,.2,.7]:Industrial.box(machine,Vector3(0,y,2.3),Vector3(3.4,.15,.1),"dark")
			Industrial.cylinder(machine,Vector3(0,1.95,0),1.1,.9,"metal")
			Industrial.cylinder(machine,Vector3(0,2.5,0),.6,.5,"rust")
	for x in [-9,9]:Industrial.cylinder(self,Vector3(x,6.2,-47),.5,28,"rust",true)
	for i in 6:prop(Vector3(-6+(i%3)*6,0,-43-floorf(i/3.0)*13),i==4)
	Industrial.label(self,"02 / COOLANT CONTROL",Vector3(0,5.6,-62.5),.021)
	terminal(OBJECTIVES[1],1)
	gate(-64,1)
	# Steam from damaged pressure relief valves. Bounded count, no dynamic lights.
	for x in [-12,12]:
		var steam=CPUParticles3D.new();steam.amount=12;steam.lifetime=3;steam.direction=Vector3.UP;steam.spread=15
		steam.initial_velocity_min=.6;steam.initial_velocity_max=1.3;steam.gravity=Vector3(.1,.1,0)
		steam.scale_amount_min=.5;steam.scale_amount_max=1.2
		var q=QuadMesh.new();q.size=Vector2(.6,.6);var m=StandardMaterial3D.new()
		m.albedo_texture=preload("res://assets/smoke.png");m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		q.material=m;steam.mesh=q;add_child(steam);steam.position=Vector3(x,3.9,-47)
		steam.add_to_group("atmosphere")

func build_reactor():
	solid(Vector3(0,-.4,-93),Vector3(48,.8,58),"concrete",false)
	wall_panels(-24,-68,11,12);wall_panels(24,-68,11,12)
	solid(Vector3(0,6,-122),Vector3(48,12,.6),"concrete")
	for x in [-18,18]:
		for z in [-71,-85,-100,-116]:beam(Vector3(x,0,z),12)
	for z in [-73,-96,-118]:
		Industrial.box(self,Vector3(0,11.5,z),Vector3(48,.8,.7),"dark")
		Industrial.box(self,Vector3(0,11.9,z),Vector3(48,.15,1.2),"metal")
	for at in [Vector3(-13,0,-76),Vector3(13,0,-82)]:
		solid(at+Vector3.UP*2,Vector3(5,4,5),"dark")
		Industrial.cylinder(self,at+Vector3.UP*3,2.1,5.5,"metal")
		for y in [1.2,3.2,5.2]:Industrial.cylinder(self,at+Vector3.UP*y,2.2,.15,"rust")
		Industrial.cylinder(self,at+Vector3.UP*6.1,.9,1,"cyan")
		lamps.append(Industrial.light(self,at+Vector3.UP*6.9,Color(.3,.8,1),2.1,12))
	# Suspended reactor ring and cables form the hall's focal silhouette.
	var ring=MeshInstance3D.new();var torus=TorusMesh.new();torus.inner_radius=4.1;torus.outer_radius=4.6;torus.rings=36;torus.ring_segments=8
	ring.mesh=torus;ring.material_override=Industrial.material("rust");ring.position=Vector3(0,8,-108);add_child(ring)
	Industrial.cylinder(self,Vector3(0,8,-108),2.9,1.8,"dark")
	Industrial.cylinder(self,Vector3(0,6.99,-108),2.15,.2,"cyan")
	for x in [-4,4]:Industrial.cylinder(self,Vector3(x,10,-108),.08,8,"metal")
	lamps.append(Industrial.light(self,Vector3(0,6,-108),Color(.34,.8,1),3,20))
	for i in 8:prop(Vector3(-9+(i%4)*6,0,-71-floorf(i/4.0)*22),i in [0,7])
	for x in [-8,8]:
		Industrial.box(self,Vector3(x,.03,-100),Vector3(.12,.035,38),"yellow")
	Industrial.label(self,"VEIL / CORE 09",Vector3(0,8.8,-121.5),.035,Color(.47,.81,.85))
	Industrial.label(self,"UNAUTHORIZED ACTUATION",Vector3(0,6.9,-121.4),.012,Color(1,.45,.22))
	terminal(OBJECTIVES[2],2)
	terminal(OBJECTIVES[3],3)
	# Exit gantry with a walkable shallow ramp.
	var ramp=solid(Vector3(19,1,-108),Vector3(5,.25,10),"floor",false)
	ramp.rotation.x=deg_to_rad(11)
	solid(Vector3(19,1.94,-116),Vector3(5,.28,6),"floor",false)

func build_background():
	for i in 12:
		var x=-45+(i%6)*18;var z=-145-floorf(i/6.0)*28;var h=15+(i%4)*6
		Industrial.box(self,Vector3(x,h*.5,z),Vector3(12,h,15),"dark")
		for y in range(4,h,5):Industrial.box(self,Vector3(x,y,z+7.6),Vector3(9,.28,.1),"cyan")
	for x in [-40,40]:
		Industrial.cylinder(self,Vector3(x,18,-40),3,36,"metal")
		for y in [12,20,28]:Industrial.cylinder(self,Vector3(x,y,-40),3.2,.4,"rust")
		Industrial.box(self,Vector3(x,35,-40),Vector3(7,.25,7),"dark")

func build_navigation():
	grid.region=Rect2i(-11,-60,23,68)
	grid.cell_size=Vector2(2,2)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for id_z in range(-60,8):
		for id_x in range(-11,12):
			var p=Vector2(id_x*2,id_z*2)
			for rect in blockers:
				if rect.has_point(p):grid.set_point_solid(Vector2i(id_x,id_z));break

func path_to(from: Vector3, to: Vector3) -> PackedVector3Array:
	var start=Vector2i(clampi(roundi(from.x/2),-11,11),clampi(roundi(from.z/2),-60,7))
	var end=Vector2i(clampi(roundi(to.x/2),-11,11),clampi(roundi(to.z/2),-60,7))
	if grid.is_point_solid(start) or grid.is_point_solid(end):return PackedVector3Array()
	var result=PackedVector3Array()
	for point in grid.get_point_path(start,end):result.append(Vector3(point.x,0,point.y))
	return result

func open_gate(index: int):
	if index>=gates.size():return
	var tween=create_tween();tween.tween_property(gates[index],"position:y",10.8,2.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	Sound.play("servo",gates[index].global_position,3,.4)

func restore_gates(stage: int):
	for i in mini(stage,gates.size()):gates[i].position.y=10.8

func apply_graphics():
	get_node("Sun").shadow_enabled=Settings.values.shadows>0
	get_node("Sun").directional_shadow_max_distance=[0,38,70,100][Settings.values.shadows]
	environment.glow_enabled=Settings.values.effects>0
	environment.fog_density=.006 if Settings.values.preset==0 else .008
	for lamp in lamps:lamp.visible=Settings.values.preset>0
	for particle in get_tree().get_nodes_in_group("atmosphere"):
		particle.emitting=Settings.values.effects>0
