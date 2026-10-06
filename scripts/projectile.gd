class_name EnemyProjectile
extends Node3D

var game: Node3D
var velocity = Vector3.ZERO
var damage = 14.0
var life = 5.0
var source: Vector3
var excluded: Array[RID] = []
var heavy = false

func _ready():
	var sphere=SphereMesh.new();sphere.radius=.14 if heavy else .045;sphere.height=sphere.radius*2;sphere.radial_segments=8;sphere.rings=4
	var mesh=MeshInstance3D.new();mesh.mesh=sphere;mesh.material_override=Industrial.material("red");add_child(mesh)

func _physics_process(delta):
	if not game.playing:return
	life-=delta
	var next=global_position+velocity*delta
	var query=PhysicsRayQueryParameters3D.create(global_position,next,1|2|16)
	query.exclude=excluded
	var result=get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		game.effects.impact(result.position,result.normal,str(result.collider.get_meta("surface","metal")),false,result.collider is StaticBody3D)
		if result.collider is PlayerRobot:result.collider.take_damage(damage,source)
		if result.collider is BreakableProp:result.collider.take_damage(damage,result.position,velocity*.18)
		if heavy:
			game.effects.explosion(result.position)
			game.radial_damage(result.position,2.8,damage*.45,null)
		queue_free()
	else:global_position=next
	if life<=0:queue_free()
