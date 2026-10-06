class_name DamageZone
extends Area3D

var enemy: EnemyRobot
var zone="core"

func _ready():
	collision_layer=8
	collision_mask=0
	monitoring=false
	monitorable=false
	set_meta("surface","metal")

static func attach(parent: Node3D, enemy_node: EnemyRobot, name_zone: String, at: Vector3, size_zone: Vector3):
	var area=DamageZone.new();area.enemy=enemy_node;area.zone=name_zone
	parent.add_child(area);area.position=at
	var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=size_zone;shape.shape=box;area.add_child(shape)
