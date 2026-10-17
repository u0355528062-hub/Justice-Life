class_name TriggerZone
extends Area3D
## Zone déclenchée quand le joueur y entre.

signal entered


static func make(parent: Node, pos: Vector3, size: Vector3) -> TriggerZone:
	var z := TriggerZone.new()
	z.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	z.add_child(cs)
	z.collision_layer = 0
	z.collision_mask = 1
	z.monitorable = false
	parent.add_child(z)
	z.body_entered.connect(z._on_body)
	return z


func _on_body(b: Node3D) -> void:
	if b is FPSPlayer:
		entered.emit()
