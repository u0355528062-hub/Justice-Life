class_name FPSPlayer
extends CharacterBody3D
## Joueur en vue subjective : déplacement lent et lourd, balancement de tête,
## respiration, pas, interaction (rayon), modes « bloqué » et « assis ».

signal interacted(target: Interactable)

const EYE_H := 1.66

var speed := 1.9
var mouse_sens := 0.0022
var can_move := true
var can_look := true
var look_limit_yaw := -1.0      # < 0 : illimité ; sinon demi-angle autour de _yaw_center
var _yaw_center := 0.0
var stress := 0.0               # 0..1 : tremblement & respiration
var hud: Node

var head: Node3D
var cam: Camera3D
var ray: RayCast3D
var _pitch := 0.0
var _bob_t := 0.0
var _step_acc := 0.0
var _eye := EYE_H
var _eye_target := EYE_H
var _focused: Interactable
var _t := 0.0
var _shake := 0.0


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	head = Node3D.new()
	head.position.y = EYE_H
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.03
	cam.far = 300.0
	cam.current = true
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = false
	attrs.dof_blur_far_distance = 6.0
	attrs.dof_blur_far_transition = 4.0
	attrs.dof_blur_amount = 0.06
	cam.attributes = attrs
	head.add_child(cam)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -2.3)
	ray.collide_with_areas = true
	ray.collide_with_bodies = true
	ray.collision_mask = 0xFFFFFFFF
	cam.add_child(ray)
	ray.add_exception(self)
	floor_snap_length = 0.3
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_dof(on: bool, dist: float = 4.0) -> void:
	var a := cam.attributes as CameraAttributesPractical
	a.dof_blur_far_enabled = on
	a.dof_blur_far_distance = dist + 1.0
	a.dof_blur_far_transition = 3.0


func lock(move: bool, yaw_limit_deg: float = -1.0) -> void:
	can_move = not move
	if yaw_limit_deg >= 0.0:
		look_limit_yaw = deg_to_rad(yaw_limit_deg)
		_yaw_center = rotation.y
	else:
		look_limit_yaw = -1.0


func set_eye_height(h: float, t: float = 0.6) -> void:
	_eye_target = h
	if t <= 0.0:
		_eye = h
		head.position.y = h


func teleport(pos: Vector3, yaw: float, pitch: float = 0.0) -> void:
	global_position = pos
	rotation.y = yaw
	_yaw_center = yaw
	_pitch = pitch
	head.rotation.x = pitch
	velocity = Vector3.ZERO


## Oriente le regard vers un point (cinématique).
func look_at_point(p: Vector3, t: float = 0.8) -> void:
	var from := head.global_position
	var d := p - from
	var yaw := atan2(-d.x, -d.z)
	var horiz := Vector2(d.x, d.z).length()
	var pitch := atan2(d.y, horiz)
	var cur := rotation.y
	var target_yaw := cur + wrapf(yaw - cur, -PI, PI)
	_yaw_center = target_yaw
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "rotation:y", target_yaw, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "_pitch", pitch, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


## Déplacement scripté (escorte) : le joueur avance seul le long d'un trajet.
func auto_walk(points: Array, spd: float = 1.3) -> void:
	var prev_move := can_move
	can_move = false
	for p in points:
		var target: Vector3 = p
		target.y = global_position.y
		var dist := global_position.distance_to(target)
		if dist < 0.05:
			continue
		var d := target - global_position
		var yaw := atan2(-d.x, -d.z)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "global_position", target, dist / spd)
		tw.tween_property(self, "rotation:y", rotation.y + wrapf(yaw - rotation.y, -PI, PI), 0.5).set_trans(Tween.TRANS_SINE)
		while tw.is_running():
			_bob_t += get_process_delta_time() * spd * 6.0
			_step_acc += get_process_delta_time() * spd
			if _step_acc > 0.62:
				_step_acc = 0.0
				Sfx.play("step", -14.0, randf_range(0.85, 1.1))
			await get_tree().process_frame
	_yaw_center = rotation.y
	can_move = prev_move


func shake(amount: float) -> void:
	_shake = max(_shake, amount)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and can_look:
		rotation.y -= event.relative.x * mouse_sens
		if look_limit_yaw >= 0.0:
			var diff := wrapf(rotation.y - _yaw_center, -PI, PI)
			rotation.y = _yaw_center + clamp(diff, -look_limit_yaw, look_limit_yaw)
		_pitch = clamp(_pitch - event.relative.y * mouse_sens, -1.35, 1.35)
	elif event.is_action_pressed("interact") and _focused and _focused.enabled:
		_focused.use()
		interacted.emit(_focused)


func _physics_process(delta: float) -> void:
	_t += delta
	var input := Vector2.ZERO
	if can_move:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var target_v := dir * speed
	velocity.x = lerp(velocity.x, target_v.x, clamp(delta * 8.0, 0.0, 1.0))
	velocity.z = lerp(velocity.z, target_v.z, clamp(delta * 8.0, 0.0, 1.0))
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = -0.1
	move_and_slide()

	var hv := Vector2(velocity.x, velocity.z).length()
	if hv > 0.3:
		_bob_t += delta * hv * 3.6
		_step_acc += delta * hv
		if _step_acc > 0.95:
			_step_acc = 0.0
			Sfx.play("step", -13.0, randf_range(0.85, 1.1))


func _process(delta: float) -> void:
	_eye = lerp(_eye, _eye_target, clamp(delta * 4.0, 0.0, 1.0))
	var breath := sin(_t * (1.4 + stress * 1.6)) * (0.004 + stress * 0.006)
	var bob_y := sin(_bob_t * 2.0) * 0.028
	var bob_x := cos(_bob_t) * 0.018
	head.position = Vector3(bob_x, _eye + bob_y + breath, 0)
	var sh := _shake + stress * 0.0025
	_shake = max(0.0, _shake - delta * 1.5)
	var n := Vector3(sin(_t * 23.0) * sh, cos(_t * 19.0) * sh, 0)
	head.rotation = Vector3(_pitch + n.x + breath * 0.5, n.y, sin(_bob_t) * 0.006 + sin(_t * 0.4) * 0.004)
	_update_focus()


func _update_focus() -> void:
	var f: Interactable = null
	if ray.is_colliding():
		var c := ray.get_collider()
		var n: Node = c
		while n and not (n is Interactable):
			n = n.get_parent()
		if n is Interactable and (n as Interactable).enabled:
			f = n
	if f != _focused:
		_focused = f
		if hud and hud.has_method("set_prompt"):
			hud.set_prompt(f.prompt if f else "")
