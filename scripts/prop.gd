class_name BreakableProp
extends RigidBody3D

var integrity = 55.0
var broken = false
var game: Node3D
var explosive = false

func _ready():
	collision_layer = 16
	collision_mask = 1|2|4|16
	mass = 18 if not explosive else 28
	linear_damp = .6
	angular_damp = 1.6
	var shape = CollisionShape3D.new()
	var resource = BoxShape3D.new()
	resource.size = Vector3(1.05,1.1,1.05)
	shape.shape = resource
	shape.position.y = .55
	add_child(shape)
	Industrial.box(self,Vector3(0,.55,0),Vector3(1,1.05,1),"rust" if explosive else "paint")
	for y in [.14,.96]: Industrial.box(self,Vector3(0,y,0),Vector3(1.06,.1,1.06),"dark")
	for x in [-.47,.47]:
		Industrial.box(self,Vector3(x,.55,-.54),Vector3(.065,.85,.06),"yellow")
	Industrial.box(self,Vector3(0,.56,-.54),Vector3(.43,.26,.04),"red" if explosive else "dark")
	set_meta("surface","metal")

func take_damage(amount: float, at: Vector3, impulse: Vector3):
	if broken: return
	integrity -= amount
	apply_impulse(impulse,at-global_position)
	if integrity <= 0:
		broken = true
		game.effects.explosion(global_position+Vector3.UP*.5,explosive)
		game.effects.debris(global_position+Vector3.UP*.5,6,Industrial.material("paint"))
		if explosive: game.radial_damage(global_position,5.5,80,self)
		queue_free()
