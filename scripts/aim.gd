class_name AimSolver
extends RefCounted

const SHOT_MASK = 1 | 8 | 16
const RANGE = 160.0

static func ray(space: PhysicsDirectSpaceState3D, start: Vector3, end: Vector3, excluded: Array[RID], mask: int = SHOT_MASK) -> Dictionary:
	if start.distance_squared_to(end) < 0.000001: return {}
	var query = PhysicsRayQueryParameters3D.create(start, end, mask)
	query.collide_with_areas = true
	query.exclude = excluded
	return space.intersect_ray(query)

# screen_point is in Camera3D's viewport coordinates, never safe-area/UI units.
static func solve(camera: Camera3D, screen_point: Vector2, muzzle: Vector3, space: PhysicsDirectSpaceState3D, excluded: Array[RID], receiver: Vector3) -> Dictionary:
	var camera_origin = camera.project_ray_origin(screen_point)
	var camera_direction = camera.project_ray_normal(screen_point)
	var camera_hit = ray(space, camera_origin, camera_origin + camera_direction * RANGE, excluded)
	var target: Vector3 = camera_hit.position if camera_hit else camera_origin + camera_direction * RANGE
	# A barrel can intersect a thin wall even while its tip is already beyond it.
	var guard_hit = ray(space, receiver, muzzle, excluded, 1 | 16)
	return {"camera_origin": camera_origin, "camera_direction": camera_direction,
		"camera_hit": camera_hit, "target": target, "muzzle": muzzle,
		"direction": (target - muzzle).normalized(), "guard_hit": guard_hit}

static func trace(solution: Dictionary, space: PhysicsDirectSpaceState3D, excluded: Array[RID], spread: Vector2, camera_basis: Basis) -> Dictionary:
	var direction: Vector3 = (solution.direction + camera_basis.x * spread.x + camera_basis.y * spread.y).normalized()
	var hit: Dictionary = solution.guard_hit if solution.guard_hit else ray(space, solution.muzzle, solution.muzzle + direction * RANGE, excluded)
	var endpoint: Vector3 = hit.position if hit else solution.muzzle + direction * RANGE
	return {"from": solution.muzzle, "to": endpoint, "direction": direction, "hit": hit,
		"obstructed": not solution.guard_hit.is_empty() or (not hit.is_empty() and endpoint.distance_to(solution.target) > 0.08)}
