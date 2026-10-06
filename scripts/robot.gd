class_name RobotVisual
extends Node3D

var rig: Node3D
var limbs: Dictionary = {}
var weapon_holder: Node3D
var muzzle: Node3D
var weapon_index = 0
var phase = 0.0
var recoil = 0.0
var hit = 0.0
var foot_phase = [false, false]
var original: Dictionary = {}
var disabled: Dictionary = {}
var is_player = false

func _ready():
	rig = preload("res://assets/wraith.glb").instantiate()
	add_child(rig)
	for part in rig.get_children():
		if part is Node3D:
			limbs[part.name] = part
			original[part.name] = part.position
			if part is MeshInstance3D:
				for i in part.mesh.get_surface_count():
					var material_source=part.mesh.surface_get_material(i)
					if material_source is StandardMaterial3D and not material_source.emission_enabled:
						var worn=material_source.duplicate()
						worn.albedo_texture=preload("res://assets/armor.png") if material_source.albedo_color.r>.5 else preload("res://assets/metal.png")
						worn.uv1_triplanar=true
						worn.uv1_scale=Vector3.ONE*2.7
						part.set_surface_override_material(i,worn)
	weapon_holder = Node3D.new()
	add_child(weapon_holder)
	muzzle = Node3D.new()
	weapon_holder.add_child(muzzle)
	muzzle.position = Vector3(0,0,-0.92)
	set_weapon(0)

func set_weapon(index: int):
	weapon_index = index
	if not weapon_holder: return
	for child in weapon_holder.get_children():
		if child != muzzle: child.queue_free()
	var scenes = [preload("res://assets/autocannon.glb"), preload("res://assets/breacher.glb"), preload("res://assets/coil_lance.glb")]
	weapon_holder.add_child(scenes[index].instantiate())

func tint_enemy(heavy: bool = false):
	for node in rig.get_children():
		if node is MeshInstance3D:
			for i in node.mesh.get_surface_count():
				var source = node.get_active_material(i)
				if source is StandardMaterial3D:
					var material_copy = source.duplicate()
					if material_copy.emission_enabled:
						material_copy.emission = Color(1,0.2,0.04)
						material_copy.albedo_color = Color(1,0.3,0.1)
					elif source.albedo_color.r > 0.5:
						material_copy.albedo_color = Color(0.5,0.28,0.17) if heavy else Color(0.36,0.43,0.45)
					node.set_surface_override_material(i,material_copy)

func animate(delta: float, motion: Vector3, grounded: bool, aim_pitch: float, reload_progress: float = 0, sprint: bool = false, leg_damage: float = 0):
	var speed = Vector2(motion.x,motion.z).length()
	phase += delta * speed * 2.5
	recoil = move_toward(recoil,0,delta*3)
	hit = move_toward(hit,0,delta*4)
	var local = basis.inverse() * motion
	var direction = Vector3(local.x,0,local.z).normalized() if speed > 0.1 else Vector3(0,0,-1)
	var stride = clampf(speed * 0.065,0,0.51)
	var body_bob = absf(sin(phase)) * stride * 0.06 if grounded else 0
	limbs.torso.position = original.torso + Vector3(0,body_bob,0)
	limbs.torso.rotation = Vector3(aim_pitch*.15 + recoil*.18 + hit*.2,0,-local.x*.012)
	limbs.head.rotation.x = aim_pitch * 0.7
	for i in 2:
		var side = "L" if i == 0 else "R"
		var sign_x = -1.0 if i==0 else 1.0
		var cycle = phase + i*PI
		var swing = sin(cycle)
		var target = Vector3(sign_x*.3,0.11,0) + direction * swing * stride
		target.y += maxf(0,cos(cycle)) * stride * 0.45
		if not grounded: target = Vector3(sign_x*.3,0.32,0.19 + i*.1)
		if leg_damage > .5 and i==0: target.y = .11; target.z *= .4
		# Terrain foot placement is limited to the step envelope; ray never drags a foot through walls.
		if grounded and speed < 9 and is_inside_tree():
			var world_target = to_global(target)
			var query = PhysicsRayQueryParameters3D.create(world_target+Vector3.UP*.65,world_target-Vector3.UP*.4,1)
			var result = get_world_3d().direct_space_state.intersect_ray(query)
			if result:
				target.y += clampf(to_local(result.position).y,-.23,.45)
		var hip = Vector3(sign_x*.3,1.24+body_bob,0)
		var knee = solve_knee(hip,target,.53,.54)
		pose_segment(limbs["thigh_"+side],hip,knee)
		pose_segment(limbs["shin_"+side],knee,target)
		limbs["foot_"+side].position = target
		limbs["foot_"+side].rotation.x = clampf(swing*stride*.24,-.12,.12)
		var stepping = cos(cycle)<-.7
		if stepping and not foot_phase[i] and grounded and speed>1:
			Sound.play("step",to_global(target),-13,0.9 + speed*.02)
		foot_phase[i] = stepping
	weapon_holder.position = Vector3(.36,1.86+body_bob,-.44+recoil*.22)
	weapon_holder.rotation = Vector3(aim_pitch,0,0)
	if reload_progress>0:
		weapon_holder.rotation.z = -sin(reload_progress*PI)*.65
		weapon_holder.rotation.x += sin(reload_progress*PI)*.45
	if sprint:
		weapon_holder.rotation.x += .25
		weapon_holder.rotation.z -= .28
	for i in 2:
		var side = "L" if i==0 else "R"
		var sx = -1.0 if i==0 else 1.0
		var shoulder_at = Vector3(sx*.63,2.08+body_bob,0)
		var hand = weapon_holder.position + weapon_holder.basis*Vector3(-.11 if i==0 else .03,-.11,-.2 if i==0 else .12)
		if reload_progress>0 and i==0: hand += Vector3(-.22,-sin(reload_progress*PI)*.45,.12)
		var elbow = (shoulder_at+hand)*.5+Vector3(sx*.17,-.25,.22)
		pose_segment(limbs["upper_arm_"+side],shoulder_at,elbow)
		pose_segment(limbs["forearm_"+side],elbow,hand)

static func solve_knee(hip: Vector3, foot: Vector3, upper: float, lower: float) -> Vector3:
	var vector = foot-hip
	var distance = clampf(vector.length(),.05,upper+lower-.005)
	var along = (upper*upper-lower*lower+distance*distance)/(2*distance)
	var height = sqrt(maxf(0,upper*upper-along*along))
	var bend = Vector3(0,0,-1).slide(vector.normalized()).normalized()
	return hip + vector.normalized()*along + bend*height

static func pose_segment(node: Node3D, start: Vector3, end: Vector3):
	node.position = start
	var direction = (end-start).normalized()
	node.quaternion = Quaternion(Vector3.DOWN,direction)

func set_first_person(active: bool):
	for key in ["head","torso"]:
		if limbs.has(key): limbs[key].visible = not active

func zone_at(position_world: Vector3) -> String:
	var p = to_local(position_world)
	if p.y>2.22: return "sensor"
	if p.y<1.2: return "leg"
	if absf(p.x)>.43: return "arm"
	return "core"

func damage_visual(zone: String, severity: float):
	hit = .7
	if disabled.has(zone) or severity < .65: return
	disabled[zone] = true
	var part = {"sensor":"head", "leg":"shin_L", "arm":"upper_arm_L", "core":"torso"}.get(zone,"torso")
	if limbs.has(part) and limbs[part] is MeshInstance3D:
		var target: MeshInstance3D = limbs[part]
		for i in target.mesh.get_surface_count():
			var m = target.get_active_material(i)
			if m is StandardMaterial3D:
				var damaged = m.duplicate()
				damaged.albedo_color *= Color(.32,.35,.36)
				damaged.emission_enabled = false
				target.set_surface_override_material(i,damaged)
