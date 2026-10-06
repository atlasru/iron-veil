class_name CombatEffects
extends Node3D

var traces: Array = []
var particles: Array = []
var decals: Array = []
var debris_bodies: Array = []
var muzzle_lights: Array = []
var random = RandomNumberGenerator.new()
var tracer_mesh: CylinderMesh
var particle_mesh: SphereMesh
var impact_mesh: QuadMesh

func _ready():
	random.seed = 41
	tracer_mesh = CylinderMesh.new()
	tracer_mesh.top_radius = .016
	tracer_mesh.bottom_radius = .016
	tracer_mesh.height = 1
	tracer_mesh.radial_segments = 6
	particle_mesh = SphereMesh.new()
	particle_mesh.radius = .028
	particle_mesh.height = .056
	particle_mesh.radial_segments = 6
	particle_mesh.rings = 3
	impact_mesh = QuadMesh.new()
	impact_mesh.size = Vector2(.16,.16)
	for i in 4:
		var light = Industrial.light(self,Vector3.ZERO,Color(1,.6,.2),0,5)
		light.hide()
		muzzle_lights.append({"node":light,"life":0.0})

func tracer(from: Vector3, to: Vector3, color: Color, rail: bool = false):
	if traces.size()>=28:
		var old=traces.pop_front();old.node.queue_free()
	var node = MeshInstance3D.new()
	node.mesh = tracer_mesh
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3
	node.material_override = mat
	add_child(node)
	node.global_position = (from+to)*.5
	node.quaternion = Quaternion(Vector3.UP,(to-from).normalized())
	node.scale = Vector3(2.2 if rail else 1,(to-from).length(),2.2 if rail else 1)
	traces.append({"node":node,"life":.23 if rail else .07})

func muzzle(at: Vector3, color: Color):
	burst(at,Vector3.UP,4,color,.09,.7)
	if Settings.values.effects>0:
		for entry in muzzle_lights:
			if entry.life<=0:
				entry.node.global_position = at
				entry.node.light_color = color
				entry.node.light_energy = 2
				entry.node.show()
				entry.life = .06
				break

func impact(at: Vector3, normal: Vector3, surface: String, rail: bool = false, persistent_mark: bool = true):
	var color = Color(1,.58,.23) if surface=="metal" else Color(.65,.67,.59)
	burst(at+normal*.03,normal,[3,5,8,12][Settings.values.effects],color,.34,5 if rail else 2.8)
	Sound.play("impact",at,-11,1.4 if surface=="metal" else .75)
	if not persistent_mark:return
	if decals.size()>36:
		var old = decals.pop_front();old.queue_free()
	var mark = MeshInstance3D.new()
	mark.mesh = impact_mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(.045,.047,.044)
	mat.albedo_texture = preload("res://assets/scorch.png")
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mark.material_override = mat
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mark)
	mark.global_position = at+normal*.012
	if absf(normal.y)>.98: mark.look_at(at+normal,Vector3.RIGHT)
	else: mark.look_at(at+normal,Vector3.UP)
	decals.append(mark)

func burst(at: Vector3, normal: Vector3, count: int, color: Color, life: float = .5, power: float = 3):
	var limit = [40,75,120,180][Settings.values.effects]
	for i in mini(count,maxi(0,limit-particles.size())):
		var node = MeshInstance3D.new()
		node.mesh = particle_mesh
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		node.material_override = mat
		add_child(node)
		node.global_position = at
		var direction = (normal + Vector3(random.randf_range(-1,1),random.randf_range(-.5,1),random.randf_range(-1,1))).normalized()
		particles.append({"node":node,"velocity":direction*random.randf_range(power*.4,power),"life":life,"max":life})

func explosion(at: Vector3, large: bool = false):
	burst(at,Vector3.UP,32 if large else 16,Color(1,.48,.16),1.2,8 if large else 4)
	Sound.play("explosion",at,1 if large else -8,.85)
	var smoke=CPUParticles3D.new()
	smoke.amount=[5,8,14,20][Settings.values.effects]
	smoke.one_shot=true
	smoke.lifetime=2.6
	smoke.explosiveness=.8
	smoke.direction=Vector3.UP
	smoke.spread=50
	smoke.initial_velocity_min=.5
	smoke.initial_velocity_max=2
	smoke.gravity=Vector3(0,.3,0)
	smoke.scale_amount_min=.5
	smoke.scale_amount_max=1.8
	var q=QuadMesh.new();q.size=Vector2(.7,.7)
	var mat=StandardMaterial3D.new()
	mat.albedo_texture=preload("res://assets/smoke.png")
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material=mat;smoke.mesh=q
	add_child(smoke);smoke.global_position=at
	get_tree().create_timer(3.1).timeout.connect(smoke.queue_free)

func debris(at: Vector3, count: int, material: Material):
	for i in mini(count,maxi(0,24-debris_bodies.size())):
		var body = RigidBody3D.new()
		body.mass=2
		body.collision_layer=32
		body.collision_mask=1
		body.linear_damp=.3
		var mesh=MeshInstance3D.new()
		var box=BoxMesh.new();box.size=Vector3(random.randf_range(.08,.25),.1,random.randf_range(.12,.4))
		mesh.mesh=box;mesh.material_override=material;body.add_child(mesh)
		var shape=CollisionShape3D.new();var s=BoxShape3D.new();s.size=box.size;shape.shape=s;body.add_child(shape)
		add_child(body);body.global_position=at+Vector3(random.randf_range(-.2,.2),0,random.randf_range(-.2,.2))
		body.linear_velocity=Vector3(random.randf_range(-4,4),random.randf_range(2,5),random.randf_range(-4,4))
		body.angular_velocity=Vector3(random.randf_range(-5,5),3,2)
		debris_bodies.append({"node":body,"life":9.0})

func _process(delta):
	for list in [traces,particles,debris_bodies]:
		for i in range(list.size()-1,-1,-1):
			var entry = list[i]
			entry.life -= delta
			if entry.has("velocity"):
				entry.velocity.y -= 8*delta
				entry.node.position += entry.velocity*delta
				entry.node.scale = Vector3.ONE * maxf(.05,entry.life/entry.max)
			if entry.life<=0:
				entry.node.queue_free();list.remove_at(i)
	for entry in muzzle_lights:
		entry.life-=delta
		if entry.life<=0:entry.node.hide()
