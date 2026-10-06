class_name AimDebugger
extends Node3D

var lines = ImmediateMesh.new()
var display: MeshInstance3D
var material: StandardMaterial3D
var last_solution: Dictionary = {}
var last_shot: Dictionary = {}

func _ready():
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	display = MeshInstance3D.new()
	display.mesh = lines
	display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(display)
	visible = false

func segment(a: Vector3, b: Vector3, color: Color):
	lines.surface_set_color(color)
	lines.surface_add_vertex(a)
	lines.surface_add_vertex(b)

func marker(at: Vector3, color: Color, radius: float = 0.12):
	for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]: segment(at - axis * radius, at + axis * radius, color)

func show_shot(solution: Dictionary, shot: Dictionary):
	last_solution = solution
	last_shot = shot
	if not visible: return
	lines.clear_surfaces()
	lines.surface_begin(Mesh.PRIMITIVE_LINES, material)
	segment(solution.camera_origin, solution.target, Color(0.2, 0.8, 1))
	segment(solution.muzzle, solution.target, Color(0.8, 0.4, 1))
	segment(shot.from, shot.to, Color(1, 0.7, 0.2))
	marker(solution.target, Color(0.2, 1, 0.5), 0.18)
	marker(solution.muzzle, Color(0.8, 0.4, 1))
	marker(shot.to, Color(1, 0.2, 0.12) if shot.obstructed else Color(1, 0.85, 0.3), 0.2)
	lines.surface_end()
