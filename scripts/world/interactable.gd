class_name Interactable
extends Area3D
## Zone avec laquelle le joueur peut interagir (touche E).

signal used

var prompt := "Interagir"
var enabled := true


static func make(parent: Node, pos: Vector3, size: Vector3, p_prompt: String) -> Interactable:
	var it := Interactable.new()
	it.prompt = p_prompt
	it.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	it.add_child(cs)
	it.collision_layer = 1
	it.collision_mask = 0
	it.monitoring = false
	parent.add_child(it)
	return it


func use() -> void:
	used.emit()
