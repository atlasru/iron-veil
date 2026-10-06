class_name RobotVisual
extends Node3D

# The exact same resources are instantiated in gameplay and the service hangar.
const MODELS = {
	"wraith": preload("res://assets/wraith.glb"),
	"sentinel": preload("res://assets/sentinel.glb"),
	"heavy": preload("res://assets/heavy.glb"),
	"warden": preload("res://assets/warden.glb"),
	"scout": preload("res://assets/scout.glb")
}
const WEAPONS = [preload("res://assets/autocannon.glb"),preload("res://assets/breacher.glb"),preload("res://assets/coil_lance.glb")]
static var material_cache: Dictionary = {}
var kind = "wraith"
var profile: Dictionary
var rig: Node3D
var limbs: Dictionary = {}
var original: Dictionary = {}
var weapon_holder: Node3D
var weapon_rig: Node3D
var muzzle: Node3D
var weapon_index = 0
var is_player = false
var phase = 0.0
var recoil = 0.0
var hit = 0.0
var heat = 0.0
var suspension = 0.0
var suspension_velocity = 0.0
var was_grounded = true
var disabled: Dictionary = {}
var legs: Array = []
var last_vertical_speed = 0.0
var frozen = false
var first_person = false
var aim_yaw = 0.0
var surface_meshes: Array = []

static func finish_asset(root: Node3D):
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		if not mesh.mesh:continue
		for i in mesh.mesh.get_surface_count():
			var source = mesh.mesh.surface_get_material(i)
			var key = 0
			if source is StandardMaterial3D and source.emission_enabled:
				key = 1 if source.emission.b>source.emission.r else 2
			if not material_cache.has(key):
				var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/machine.gdshader")
				mat.set_shader_parameter("surface_detail",preload("res://assets/machine_detail.png"))
				mat.set_shader_parameter("emission_color",[Vector3.ZERO,Vector3(.25,.90,1),Vector3(1,.25,.03)][key])
				material_cache[key]=mat
			mesh.set_surface_override_material(i,material_cache[key])

func _ready():
	profile=JSON.parse_string(FileAccess.get_file_as_string("res://assets/mech_profiles.json"))[kind]
	rig=MODELS[kind].instantiate();add_child(rig)
	finish_asset(rig)
	for part in rig.get_children():
		if part is Node3D:
			limbs[str(part.name)]=part
			original[str(part.name)]=part.transform
	for part_name in ["armor_front_L","armor_front_R","sensor","reactor","radiator_L","radiator_R","hardpoint_L","hardpoint_R","ammo","spine","siege_mount","missile_L","missile_R"]:
		if limbs.has(part_name):limbs[part_name].reparent(limbs.torso)
	for i in profile.hips.size():
		var hip: Array=profile.hips[i]
		var leg_name=("L" if hip[0]<0 else "R")+str(i/2)
		var hydraulic_root=Node3D.new();hydraulic_root.name="Hydraulic_"+leg_name;add_child(hydraulic_root)
		var barrel=Industrial.cylinder(hydraulic_root,Vector3.ZERO,.065*profile.leg_scale,1,"dark")
		var piston=Industrial.cylinder(hydraulic_root,Vector3.ZERO,.032*profile.leg_scale,1,"metal")
		var second_barrel=Industrial.cylinder(hydraulic_root,Vector3.ZERO,.054*profile.leg_scale,1,"dark")
		var second_piston=Industrial.cylinder(hydraulic_root,Vector3.ZERO,.028*profile.leg_scale,1,"metal")
		legs.append({"name":leg_name,"hip":Vector3(hip[0],profile.hip_y,hip[1]),"rest":Vector3(hip[0],.15*profile.leg_scale,hip[1]-.13*profile.leg_scale),
			"planted":false,"world":Vector3.ZERO,"normal":Vector3.UP,"stance":false,"barrel":barrel,"piston":piston,"barrel2":second_barrel,"piston2":second_piston})
	weapon_holder=Node3D.new();weapon_holder.name="MountedWeapon";add_child(weapon_holder)
	muzzle=Node3D.new();muzzle.name="Muzzle";weapon_holder.add_child(muzzle)
	surface_meshes=rig.find_children("*","MeshInstance3D",true,false)
	set_weapon(0)
	reset_pose()
	print("IRON_VEIL_ASSET / "+kind+" / "+MODELS[kind].resource_path+" / supports "+str(legs.size()))

func set_weapon(index: int):
	weapon_index=clampi(index,0,2)
	if not weapon_holder:return
	if weapon_rig:
		weapon_holder.remove_child(weapon_rig);weapon_rig.queue_free()
	weapon_rig=WEAPONS[weapon_index].instantiate();weapon_holder.add_child(weapon_rig)
	finish_asset(weapon_rig)
	var scale_weapon=1.36 if kind=="warden" else (1.15 if kind=="heavy" else (.45 if kind=="scout" else 1.0))
	weapon_rig.scale=Vector3.ONE*scale_weapon
	muzzle.position=Vector3(0,0,[-1.79,-1.60,-2.03][weapon_index])*scale_weapon

func reset_pose():
	frozen=false;phase=0;recoil=0;heat=0;hit=0;suspension=0;suspension_velocity=0
	rotation.x=0;rotation.z=0;disabled.clear()
	for leg in legs:leg.planted=false;leg.stance=false
	for mesh in surface_meshes:
		mesh.set_instance_shader_parameter("damage",0.0);mesh.set_instance_shader_parameter("startup",1.0)
	animate(0,Vector3.ZERO,true,0)

func animate(delta: float, motion: Vector3, grounded: bool, aim_pitch: float, reload_progress: float = 0, sprint: bool = false, leg_damage: float = 0):
	if frozen:return
	var speed=Vector2(motion.x,motion.z).length()
	var local=global_basis.inverse()*motion
	var direction=Vector3(local.x,0,local.z).normalized() if speed>.1 else Vector3.FORWARD
	phase+=delta*speed*(2.30 if kind in ["heavy","warden"] else 2.75)
	heat=clampf(heat+recoil*delta*.35-delta*.09,0,1)
	recoil=move_toward(recoil,0,delta*2.8);hit=move_toward(hit,0,delta*3.8)
	if grounded and not was_grounded:suspension_velocity-=minf(4,absf(last_vertical_speed)*.34)
	suspension_velocity+=(-suspension*90-suspension_velocity*13)*delta
	suspension=clampf(suspension+suspension_velocity*delta,-.24,.10)
	was_grounded=grounded;last_vertical_speed=motion.y
	var bob=(absf(sin(phase))*.035 if speed>.1 and grounded else sin(Time.get_ticks_msec()*.0011)*.008)+suspension
	limbs.torso.position.y=profile.torso_y+bob
	limbs.torso.rotation=Vector3(aim_pitch*.13+recoil*.032+hit*.055,aim_yaw*.3,clampf(-local.x*.008,-.09,.09))
	if limbs.has("sensor"):limbs.sensor.rotation=Vector3(aim_pitch*.55,aim_yaw*.5,0)
	for side in ["L","R"]:
		if limbs.has("radiator_"+side):limbs["radiator_"+side].rotation.z=(heat*.20+sin(Time.get_ticks_msec()*.001)*.008)*(-1 if side=="L" else 1)
	if legs.is_empty():
		limbs.torso.rotation.z=-local.x*.025
	else:
		for i in legs.size():
			var leg:Dictionary=legs[i]
			var offset=0.0 if i%2==0 else PI
			if legs.size()>2:offset+=(i/2)*PI*.62
			var cycle=fposmod(phase+offset,TAU)/TAU
			var stride=clampf(speed*.095,0,.79)*profile.leg_scale
			var target:Vector3=leg.rest
			var normal=Vector3.UP
			var stance=grounded and (speed<.2 or cycle<.60)
			if stance:
				if not leg.planted:
					target+=direction*stride
					var ground=ground_at(to_global(target))
					leg.world=ground.position;leg.normal=ground.normal
					if speed>1.0:Sound.play("step",leg.world,-10 if kind in ["heavy","warden"] else -15,.60 if kind in ["heavy","warden"] else .85)
				target=to_local(leg.world)
				var deviation=Vector2(target.x-leg.rest.x,target.z-leg.rest.z)
				if speed<.2 and deviation.length()>.3:
					var planted_ground=ground_at(to_global(leg.rest));leg.world=planted_ground.position;leg.normal=planted_ground.normal;target=to_local(leg.world)
				else:
					deviation=deviation.limit_length(.85*profile.leg_scale)
					target.x=leg.rest.x+deviation.x;target.z=leg.rest.z+deviation.y
				normal=global_basis.inverse()*leg.normal
			elif grounded:
				var t=(cycle-.60)/.40
				target+=direction*lerpf(-stride,stride,smoothstep(0,1,t))
				target.y+=sin(t*PI)*(.20+stride*.35)
				var g=ground_at(to_global(leg.rest+direction*stride))
				target.y+=clampf(to_local(g.position).y-leg.rest.y,-.24,.45)*t
			else:target+=Vector3(0,.28,.25)
			if leg_damage>.5 and i==0:target.z=lerpf(target.z,leg.rest.z,.5)
			leg.planted=stance;leg.stance=stance
			pose_leg(leg,target,normal,bob)
	weapon_holder.position=Vector3(profile.mount[0],profile.mount[1]+bob,profile.mount[2]+recoil*.17)
	weapon_holder.rotation=Vector3(aim_pitch,aim_yaw,0)
	if sprint:weapon_holder.rotation.x+=.22
	if reload_progress>0:
		var cycling=sin(reload_progress*PI)
		weapon_holder.rotation.z=-cycling*.15
		weapon_holder.rotation.x+=cycling*.27
		var breech=weapon_rig.get_node_or_null("breech")
		if breech:breech.position.z=.47+cycling*.18
		var magazine=weapon_rig.get_node_or_null("magazine")
		if magazine:magazine.rotation.z=-cycling*.9
	var barrel=weapon_rig.get_node_or_null("barrel")
	if barrel:
		barrel.position.z=-.35+recoil*.11
		if weapon_index==0:barrel.rotation.z+=delta*(recoil*28)
	for mesh in surface_meshes:mesh.set_instance_shader_parameter("heat",heat)

func ground_at(world:Vector3) -> Dictionary:
	var result={}
	if is_inside_tree():
		var query=PhysicsRayQueryParameters3D.create(world+Vector3.UP*.7,world-Vector3.UP*.85,1)
		result=get_world_3d().direct_space_state.intersect_ray(query)
	if result:return {"position":result.position+result.normal*(.15*profile.leg_scale),"normal":result.normal}
	return {"position":world,"normal":Vector3.UP}

func pose_leg(leg: Dictionary, target: Vector3, normal: Vector3, bob:float):
	var hip:Vector3=leg.hip+Vector3.UP*bob*.25
	var knee=solve_knee(hip,target,profile.upper,profile.lower)
	var leg_name:String=leg.name
	pose_segment(limbs["thigh_"+leg_name],hip,knee,1.12*profile.leg_scale)
	pose_segment(limbs["shin_"+leg_name],knee,target,1.12*profile.leg_scale)
	limbs["hip_"+leg_name].position=hip
	limbs["foot_"+leg_name].position=target
	var up=normal.normalized();var forward=Vector3.FORWARD.slide(up).normalized();var right=forward.cross(up).normalized()
	limbs["foot_"+leg_name].basis=Basis(right,up,-forward)
	var side=-1.0 if hip.x<0 else 1.0
	var outer=Vector3(side*.25*profile.leg_scale,0,0)
	hydraulic(leg.barrel,leg.piston,hip+outer+Vector3(0,.03,.10),knee+outer*.65+Vector3(0,.1,-.04))
	hydraulic(leg.barrel2,leg.piston2,knee+outer*.52+Vector3(0,-.10,.05),target+outer*.4+Vector3(0,.20,.09))

static func hydraulic(barrel: Node3D, piston: Node3D, start: Vector3, end: Vector3):
	var d=end-start;var axis=d.normalized();var distance=d.length()
	barrel.position=start+axis*distance*.31
	barrel.quaternion=Quaternion(Vector3.UP,axis);barrel.scale.y=distance*.62
	piston.position=start+axis*distance*.77
	piston.quaternion=barrel.quaternion;piston.scale.y=distance*.46

static func solve_knee(hip: Vector3, foot: Vector3, upper: float, lower: float) -> Vector3:
	var vector=foot-hip;var distance=clampf(vector.length(),absf(upper-lower)+.001,upper+lower-.005)
	var axis=vector.normalized();var along=(upper*upper-lower*lower+distance*distance)/(2*distance)
	var height=sqrt(maxf(0,upper*upper-along*along))
	var bend=Vector3.BACK.slide(axis).normalized()
	if bend.length_squared()<.1:bend=Vector3.RIGHT.slide(axis).normalized()
	return hip+axis*along+bend*height

static func pose_segment(node: Node3D, start: Vector3, end: Vector3, length_reference:float=1.12):
	node.position=start
	node.quaternion=Quaternion(Vector3.DOWN,(end-start).normalized())
	node.scale=Vector3(1,(end-start).length()/length_reference,1)

func set_first_person(active: bool):
	first_person=active
	limbs.torso.visible=not active
	if limbs.has("pelvis"):limbs.pelvis.visible=not active

func zone_at(position_world: Vector3) -> String:
	var p=to_local(position_world)
	if p.y<profile.hip_y:return "leg"
	if absf(p.x)>profile.width*.42:return "arm"
	if p.z<-profile.depth*.49 and absf(p.x)<.48:return "sensor"
	return "core"

func damage_visual(zone: String, severity: float):
	hit=.7
	var parts={"sensor":["sensor"],"core":["torso","reactor"],"arm":["hardpoint_L","hardpoint_R"],"leg":[]}
	if zone=="leg":
		for leg in legs:parts.leg.append("shin_"+leg.name)
	for key in parts.get(zone,[]):
		if limbs.has(key) and limbs[key] is MeshInstance3D:limbs[key].set_instance_shader_parameter("damage",clampf(severity,0,.95))
	if severity>.65:disabled[zone]=true

func wreck_pose(progress:float):
	frozen=true
	for leg in legs:
		var hip:Vector3=leg.hip
		var target:Vector3=leg.rest+Vector3(signf(hip.x)*progress*.32,progress*profile.hip_y*.68,progress*.24)
		pose_leg(leg,target,Vector3.UP,-progress*.22)
	for mesh in surface_meshes:
		mesh.set_instance_shader_parameter("damage",progress*.75)
		mesh.set_instance_shader_parameter("startup",1-progress)
