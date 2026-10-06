extends Node3D

var failures = 0
var combinations = 0
var worst_error = 0.0
var viewport: SubViewport
var camera: Camera3D
var target: StaticBody3D

func check(ok: bool, label: String):
	if not ok:
		failures += 1
		push_error("AIM FAIL: " + label)

func obstacle(at: Vector3, dimensions: Vector3) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.collision_layer = 1
	var collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	body.add_child(collider)
	viewport.add_child(body)
	body.position = at
	return body

func _ready():
	call_deferred("run")

func run():
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(1600, 900)
	add_child(viewport)
	camera = Camera3D.new()
	viewport.add_child(camera)
	camera.current = true
	camera.near = 0.075
	camera.far = 200
	target = obstacle(Vector3(0, 3, -20), Vector3(180, 100, 0.1))
	await get_tree().physics_frame
	var excluded: Array[RID] = []
	for resolution in [Vector2i(1280,720), Vector2i(2400,1080), Vector2i(1920,1200), Vector2i(1024,768)]:
		viewport.size = resolution
		for scale in [0.55, 0.85, 1.0]:
			viewport.scaling_3d_scale = scale
			for fov in [60.0, 78.0, 100.0]:
				for third in [false, true]:
					for shoulder in [-1.0, 1.0]:
						for ads in [false, true]:
							camera.fov = fov * (0.72 if ads else 1.0)
							camera.position = Vector3(shoulder * 0.8 if third else 0, 3.0, 5.0 if third else 0)
							camera.rotation = Vector3(-0.04, 0.12, 0)
							for distance in [2.0, 5.0, 10.0, 25.0, 50.0, 120.0]:
								target.position.z = camera.position.z - distance - 0.05
								# Changing a collider needs a physics synchronization before a query.
								PhysicsServer3D.body_set_state(target.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, target.global_transform)
								var center = viewport.get_visible_rect().get_center()
								var muzzle = camera.position + camera.basis * Vector3(0.62, -0.25, -0.4)
								var solution = AimSolver.solve(camera, center, muzzle, viewport.find_world_3d().direct_space_state, excluded, muzzle + Vector3.BACK * 0.1)
								var shot = AimSolver.trace(solution, viewport.find_world_3d().direct_space_state, excluded, Vector2.ZERO, camera.global_basis)
								var error = camera.unproject_position(shot.to).distance_to(center)
								worst_error = maxf(worst_error, error)
								combinations += 1
								check(not shot.hit.is_empty() and shot.hit.collider == target and error < 0.08, "%s scale %.2f FOV %.1f %s shoulder %.0f ADS %s %.0fm / %.4fpx" % [resolution, scale, fov, third, shoulder, ads, distance, error])
	# Reproduce the Android error with a notch on one side only.
	var screen = Vector2(2400, 1080)
	var safe = Rect2(90, 0, 2310, 1080)
	var old_center = safe.get_center()
	check(old_center.distance_to(screen * 0.5) == 45, "asymmetric safe area reproduces 45px crosshair drift")
	var hud = TacticalHUD.new()
	viewport.add_child(hud)
	hud.set_process(false)
	hud.set_process_input(false)
	hud.visible = false
	viewport.size = Vector2i(screen)
	hud.origin = Vector2(90, 0)
	hud.scale_ui = 1.2
	check(hud.crosshair_point().is_equal_approx(screen * 0.5), "HUD crosshair ignores safe-area transform")
	# Shoulder camera sees the target, but the barrel hits low/side cover.
	camera.position = Vector3(0.8, 3, 0)
	camera.rotation = Vector3.ZERO
	target.position = Vector3(0, 3, -20)
	var cover = obstacle(Vector3(0, 2.6, -2), Vector3(0.8, 1.2, 0.4))
	await get_tree().physics_frame
	var space = viewport.find_world_3d().direct_space_state
	var sol = AimSolver.solve(camera, screen * 0.5, Vector3(0, 2.3, -0.5), space, excluded, Vector3(0, 2.3, -0.2))
	var result = AimSolver.trace(sol, space, excluded, Vector2.ZERO, camera.global_basis)
	check(sol.camera_hit.collider == target and result.hit.collider == cover and result.obstructed, "muzzle obstruction wins over camera visibility")
	cover.position = Vector3(0, 2.3, -0.7)
	await get_tree().physics_frame
	sol = AimSolver.solve(camera, screen * 0.5, Vector3(0, 2.3, -1.1), space, excluded, Vector3(0, 2.3, -0.3))
	result = AimSolver.trace(sol, space, excluded, Vector2.ZERO, camera.global_basis)
	check(not sol.guard_hit.is_empty() and result.hit.collider == cover, "barrel guard stops tip-through-wall shooting")
	print("AIM: %d zero-spread combinations / maximum %.5fpx error / %d failures" % [combinations, worst_error, failures])
	get_tree().quit(1 if failures else 0)
