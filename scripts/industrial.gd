class_name Industrial
extends RefCounted

static var materials: Dictionary = {}
static var meshes: Dictionary = {}

static func material(name: String) -> StandardMaterial3D:
	if materials.has(name): return materials[name]
	var m = StandardMaterial3D.new()
	m.roughness = 0.7
	var texture = "metal"
	match name:
		"concrete": m.albedo_color = Color(0.67,0.72,0.69); texture = "concrete"; m.metallic = 0.0
		"floor": m.albedo_color = Color(0.8,0.86,0.83); texture = "floor"; m.metallic = 0.65
		"metal": m.albedo_color = Color(0.68,0.77,0.77); m.metallic = 0.85
		"paint": m.albedo_color = Color(0.41,0.55,0.55); texture = "armor"; m.metallic = 0.55
		"rust": m.albedo_color = Color(0.65,0.31,0.12); m.metallic = 0.7
		"dark": m.albedo_color = Color(0.19,0.26,0.28); m.metallic = 0.8
		"yellow": m.albedo_color = Color(0.9,0.61,0.2); m.metallic = 0.45
		"lime", "cyan", "red", "white":
			m.albedo_color = {"lime":Color(0.64,0.95,0.36), "cyan":Color(0.33,0.85,1.0), "red":Color(1,0.23,0.1), "white":Color(0.91,0.95,0.89)}[name]
			m.emission_enabled = true
			m.emission = m.albedo_color
			m.emission_energy_multiplier = 2.4
			m.roughness = 0.32
			materials[name] = m
			return m
	m.albedo_texture = load("res://assets/" + texture + ".png")
	m.normal_enabled = true
	m.normal_texture = load("res://assets/" + texture + "_normal.png")
	m.normal_scale = 0.45
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.3
	materials[name] = m
	return m

static func box(parent: Node3D, at: Vector3, size: Vector3, mat: String = "metal", collision: bool = false) -> Node3D:
	var root: Node3D = StaticBody3D.new() if collision else Node3D.new()
	parent.add_child(root)
	root.position = at
	var key = "box"
	if not meshes.has(key):
		var mesh = BoxMesh.new()
		mesh.size = Vector3.ONE
		meshes[key] = mesh
	var visual = MeshInstance3D.new()
	visual.mesh = meshes[key]
	visual.material_override = material(mat)
	visual.scale = size
	visual.visibility_range_end = 135
	root.add_child(visual)
	if collision:
		root.collision_layer = 1
		root.collision_mask = 0
		root.set_meta("surface", "concrete" if mat == "concrete" else "metal")
		var shape = CollisionShape3D.new()
		var resource = BoxShape3D.new()
		resource.size = size
		shape.shape = resource
		root.add_child(shape)
		if size.x>=2 and size.y>=2 and size.z>=.4:
			var occluder=OccluderInstance3D.new()
			var box_occluder=BoxOccluder3D.new()
			box_occluder.size=size*.97
			occluder.occluder=box_occluder
			root.add_child(occluder)
	return root

static func cylinder(parent: Node3D, at: Vector3, radius: float, length: float, mat: String = "metal", horizontal: bool = false) -> MeshInstance3D:
	var key="cylinder"
	if not meshes.has(key):
		var resource = CylinderMesh.new()
		resource.top_radius = 1
		resource.bottom_radius = 1
		resource.height = 1
		resource.radial_segments = 16
		meshes[key]=resource
	var mesh=meshes[key]
	var visual = MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material(mat)
	visual.scale = Vector3(radius,length,radius)
	visual.position = at
	visual.visibility_range_end = 120
	parent.add_child(visual)
	if horizontal: visual.rotation.x = PI * 0.5
	return visual

static func label(parent: Node3D, value: String, at: Vector3, height: float = 0.035, color: Color = Color(0.7,0.8,0.74)) -> Label3D:
	var node = Label3D.new()
	node.text = value
	node.font_size = 64
	node.pixel_size = height
	node.modulate = color
	node.position = at
	node.outline_size = 0
	parent.add_child(node)
	return node

static func light(parent: Node3D, at: Vector3, color: Color, energy: float, radius: float) -> OmniLight3D:
	var node = OmniLight3D.new()
	node.position = at
	node.light_color = color
	node.light_energy = energy
	node.omni_range = radius
	node.distance_fade_enabled = true
	node.distance_fade_begin = 30
	node.distance_fade_length = 15
	parent.add_child(node)
	return node
