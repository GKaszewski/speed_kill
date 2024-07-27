class_name FPSController
extends CharacterBody3D

@export var look_sensitivity := 0.006
@export var controller_look_sensitivity := 0.05
@export var controller_aim_smoothness := 5.0
@export var jump_velocity := 6.0
@export var auto_bhop := true

const HEADBOB_MOVE_AMOUNT = 0.06
const HEADBOB_FREQUENCY = 2.4
var headbob_time := 0.0

@export var air_cap := 0.85
@export var air_acceleration := 800.0
@export var air_move_speed := 500.0

@export var walk_speed := 12.0
@export var ground_acceleration := 14.0
@export var ground_deceleration := 10.0
@export var ground_friction := 6.0

@export var swim_up_speed := 10.0
@export var climb_speed := 7.0

var wish_dir := Vector3.ZERO
var camera_aligned_wish_dir := Vector3.ZERO

const CROUCH_TRANSLATE = 0.7
const CROUCH_JUMP_ADD = CROUCH_TRANSLATE * 0.9 # * 0.9 for sourcelike camera jitter in air on crouch, makes for a nice notifier
var is_crouched := false

var noclip_speed_multiplier := 3.0
var noclip := false

const MAX_STEP_HEIGHT = 0.5
var _snapped_to_stairs_last_frame := false
var _last_frame_was_on_floor = -INF

func get_move_speed() -> float:
	if is_crouched:
		return walk_speed * 0.8
	return walk_speed # later maybe add sprinting

func get_interactable_component_at_shapecast() -> InteractableComponent:
	for i in %InteractShapeCast3D.get_collision_count():
		if i > 0 and %InteractShapeCast3D.get_collider(0) != $".":
			return null
		if %InteractShapeCast3D.get_collider(i).get_node_or_null("InteractableComponent") is InteractableComponent:
			return %InteractShapeCast3D.get_collider(i).get_node_or_null("InteractableComponent")

	return null

func _push_away_rigid_bodies() -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_collider() is RigidBody3D:
			var push_dir = -c.get_normal()
			var velocity_diff_in_push_dir = self.velocity.dot(push_dir) - c.get_collider().linear_velocity.dot(push_dir)
			velocity_diff_in_push_dir = max(0.0, velocity_diff_in_push_dir)
			const MY_APPROX_MASS_KG  = 80.0
			var mass_ratio = min(1., MY_APPROX_MASS_KG / c.get_collider().mass)
			if mass_ratio < 0.25:
				continue
			push_dir.y = 0
			var push_force = mass_ratio * 5.0
			c.get_collider().apply_impulse(push_dir * velocity_diff_in_push_dir * push_force, c.get_position() - c.get_collider().global_position)


func _unhandled_input(event):
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * look_sensitivity)
			%Camera3D.rotate_x(-event.relative.y * look_sensitivity)
			%Camera3D.rotation.x = clamp(%Camera3D.rotation.x, deg_to_rad(-90), deg_to_rad(90))

	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			noclip_speed_multiplier = min(100.0, noclip_speed_multiplier * 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			noclip_speed_multiplier = max(0.1, noclip_speed_multiplier * 0.9)

func _headbob_effect(delta) -> void:
	headbob_time += delta * self.velocity.length()
	%Camera3D.transform.origin = Vector3(
		cos(headbob_time * HEADBOB_FREQUENCY * 0.5) * HEADBOB_MOVE_AMOUNT,
		sin(headbob_time * HEADBOB_FREQUENCY) * HEADBOB_MOVE_AMOUNT,
		0
	)

var _current_controller_look := Vector2.ZERO
func _handle_controller_look_input(delta) -> void:
	var target_look = Input.get_vector("look_left", "look_right", "look_up", "look_down").normalized()
	
	if target_look.length() < _current_controller_look.length():
		_current_controller_look = target_look
	else:
		_current_controller_look = _current_controller_look.lerp(target_look, controller_aim_smoothness * delta)
	rotate_y(-_current_controller_look.x * controller_look_sensitivity)
	%Camera3D.rotate_x(-_current_controller_look.y * controller_look_sensitivity)
	%Camera3D.rotation.x = clamp(%Camera3D.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _ready():
	for child in %WorldModel.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(2, true)

func clip_velocity(normal: Vector3, overbounce : float, _delta : float) -> void:
	var backoff := self.velocity.dot(normal) * overbounce
	if backoff >= 0: return
	
	var change := normal * backoff
	self.velocity -= change
	
	var adjust := self.velocity.dot(normal)
	if adjust < 0.0:
		self.velocity -= normal * adjust

func is_surface_too_steep(normal : Vector3) -> bool:
	return normal.angle_to(Vector3.UP) > self.floor_max_angle

func _run_body_test_motion(from: Transform3D, motion: Vector3, result = null) -> bool:
	if not result: result = PhysicsTestMotionResult3D.new()
	var params = PhysicsTestMotionParameters3D.new()
	params.from = from
	params.motion = motion

	return PhysicsServer3D.body_test_motion(self.get_rid(), params, result)

func _handle_air_physics(delta) -> void:
	self.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	var current_speed_in_wish_dir = self.velocity.dot(wish_dir)
	var capped_speed = min((air_move_speed * wish_dir).length(), air_cap)
	var add_speed_till_cap = capped_speed - current_speed_in_wish_dir

	if add_speed_till_cap > 0:
		var acceleration_speed = air_acceleration * air_move_speed * delta
		acceleration_speed = min(acceleration_speed, add_speed_till_cap)
		self.velocity += wish_dir * acceleration_speed

	if is_on_wall():
		if is_surface_too_steep(get_wall_normal()):
			self.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		else:
			self.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
		clip_velocity(get_wall_normal(), 1.0, delta)
	

func _handle_ground_physics(delta) -> void:
	var current_speed_in_wish_dir = self.velocity.dot(wish_dir)
	var add_speed_till_cap = get_move_speed() - current_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var acceleration_speed = ground_acceleration * get_move_speed() * delta
		acceleration_speed = min(acceleration_speed, add_speed_till_cap)
		self.velocity += wish_dir * acceleration_speed

	# friction
	var control = max(self.velocity.length(), ground_deceleration)
	var drop = control * ground_friction * delta
	var new_speed = max(self.velocity.length() - drop, 0.0)
	if self.velocity.length() > 0:
		self.velocity /= self.velocity.length()
	self.velocity *= new_speed

	_headbob_effect(delta)

func _snap_down_to_stairs_check() -> void:
	var did_snap := false
	var floor_below: bool = %StairsBelowRayCast3D.is_colliding() and not is_surface_too_steep(%StairsBelowRayCast3D.get_collision_normal())
	var was_on_floor_last_frame = Engine.get_physics_frames() - _last_frame_was_on_floor == 1
	if not is_on_floor() and velocity.y <= 0 and (was_on_floor_last_frame or _snapped_to_stairs_last_frame) and floor_below:
		var body_test_result = PhysicsTestMotionResult3D.new()
		if _run_body_test_motion(self.global_transform, Vector3(0, -MAX_STEP_HEIGHT, 0), body_test_result):
			_save_camera_position_for_smoothing()
			var translate_y = body_test_result.get_travel().y
			self.position.y += translate_y
			apply_floor_snap()
			did_snap = true
	_snapped_to_stairs_last_frame = did_snap

func _snap_up_stairs_check(delta) -> bool:
	if not is_on_floor() and not _snapped_to_stairs_last_frame:
		return false
	if self.velocity.y > 0 or (self.velocity * Vector3(1,0,1)).length() == 0: return false
	
	var expected_move_motion = self.velocity * Vector3(1,0,1) * delta
	var step_position_with_clearance = self.global_transform.translated(expected_move_motion + Vector3(0, MAX_STEP_HEIGHT * 2, 0))
	var down_check_result = PhysicsTestMotionResult3D.new()
	if (_run_body_test_motion(step_position_with_clearance, Vector3(0, -MAX_STEP_HEIGHT * 2, 0), down_check_result)
	and (down_check_result.get_collider().is_class("StaticBody3D") or down_check_result.get_collider().is_class("CSGShape3D"))):
		var step_height = ((step_position_with_clearance.origin + down_check_result.get_travel()) - self.global_position).y
		if step_height > MAX_STEP_HEIGHT or step_height <= 0.01 or (down_check_result.get_collision_point() - self.global_position).y > MAX_STEP_HEIGHT:
			return false
		%StairsAheadRayCast3D.global_position = down_check_result.get_collision_point() + Vector3(0, MAX_STEP_HEIGHT, 0) + expected_move_motion.normalized() * 0.1
		%StairsAheadRayCast3D.force_raycast_update()
		if %StairsAheadRayCast3D.is_colliding() and not is_surface_too_steep(%StairsAheadRayCast3D.get_collision_normal()):
			_save_camera_position_for_smoothing()
			self.global_position = step_position_with_clearance.origin + down_check_result.get_travel()
			apply_floor_snap()
			_snapped_to_stairs_last_frame = true
			return true

	return false

var _current_ladder_climbing: Area3D = null
func _handle_ladder_physics() -> bool:
	var was_climbing_ladder := _current_ladder_climbing and _current_ladder_climbing.overlaps_body(self)
	if not was_climbing_ladder:
		_current_ladder_climbing = null
		for ladder in get_tree().get_nodes_in_group("ladder_area3d"):
			if ladder.overlaps_body(self):
				_current_ladder_climbing = ladder
				break
	if _current_ladder_climbing == null:
		return false

	var ladder_global_transform: Transform3D = _current_ladder_climbing.global_transform
	var position_relative_to_ladder := ladder_global_transform.affine_inverse() * self.global_position

	var forward_move := Input.get_action_strength("up") - Input.get_action_strength("down")
	var side_move := Input.get_action_strength("right") - Input.get_action_strength("left")
	var ladder_forward_move = ladder_global_transform.affine_inverse().basis * %Camera3D.global_transform.basis * Vector3(0.0, 0.0, -forward_move)
	var ladder_side_move = ladder_global_transform.affine_inverse().basis * %Camera3D.global_transform.basis * Vector3(side_move, 0.0, 0.0)

	var ladder_strafe_velocity: float = climb_speed * (ladder_side_move.x + ladder_forward_move.x)
	var ladder_climb_velocity: float = climb_speed * - ladder_side_move.z
	var up_wish := Vector3.UP.rotated(Vector3(1.0, 0.0, 0.0), deg_to_rad(-45)).dot(ladder_forward_move)
	ladder_climb_velocity += climb_speed * up_wish

	var should_dismount = false
	if not was_climbing_ladder:
		var mounting_from_top = position_relative_to_ladder.y > _current_ladder_climbing.get_node("TopOfLadder").position.y
		if mounting_from_top:
			if ladder_climb_velocity > 0.0:
				should_dismount = true
			else:
				if (ladder_global_transform.affine_inverse().basis * wish_dir).z >= 0.0:
					should_dismount = true
			if abs(position_relative_to_ladder.z) > 0.1:
				should_dismount = true
	
	if is_on_floor() and ladder_climb_velocity <= 0.0:
		should_dismount = true

	if should_dismount:
		_current_ladder_climbing = null
		return false

	if was_climbing_ladder and Input.is_action_just_pressed("jump"):
		self.velocity = _current_ladder_climbing.global_transform.basis.z * jump_velocity * 1.5
		_current_ladder_climbing = null
		return false

	self.velocity = ladder_global_transform.basis * Vector3(ladder_strafe_velocity, ladder_climb_velocity, 0.0)

	position_relative_to_ladder.z = 0.0
	self.global_position = ladder_global_transform * position_relative_to_ladder

	move_and_slide()
	return true
	

func _handle_water_physics(delta) -> bool:
	if get_tree().get_nodes_in_group("water_area").all(func(area): return !area.overlaps_body(self)):
		return false
	
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * 0.1 * delta 

	self.velocity += camera_aligned_wish_dir * get_move_speed() * delta

	if Input.is_action_pressed("jump"):
		self.velocity.y += swim_up_speed * delta

	self.velocity = self.velocity.lerp(Vector3.ZERO, 2.0 * delta)
	return true

@onready var _original_capsule_height = $CollisionShape3D.shape.height
func _handle_crouch(delta) -> void:
	var was_crouched_last_frame = is_crouched
	if Input.is_action_pressed("crouch"):
		is_crouched = true
	elif is_crouched and not self.test_move(self.global_transform, Vector3(0.0, CROUCH_TRANSLATE, 0.0)):
		is_crouched = false

	var translate_y_if_possible := 0.0
	if was_crouched_last_frame != is_crouched and not is_on_floor() and not _snapped_to_stairs_last_frame:
		translate_y_if_possible = CROUCH_JUMP_ADD if is_crouched else -CROUCH_JUMP_ADD
	
	if translate_y_if_possible != 0.0:
		var result = KinematicCollision3D.new()
		self.test_move(self.global_transform, Vector3(0.0, translate_y_if_possible, 0.0), result)
		self.position.y += result.get_travel().y
		%Head.position.y -= result.get_travel().y
		%Head.position.y = clampf(%Head.position.y, -CROUCH_TRANSLATE, 0.0)

	%Head.position.y = move_toward(%Head.position.y, -CROUCH_TRANSLATE if is_crouched else 0.0, 7.0 * delta)
	$CollisionShape3D.shape.height = _original_capsule_height - CROUCH_TRANSLATE if is_crouched else _original_capsule_height
	$CollisionShape3D.position.y = $CollisionShape3D.shape.height / 2


func _handle_noclip(delta) -> bool:
	if Input.is_action_just_pressed("noclip") and OS.has_feature("debug"):
		noclip = !noclip

	$CollisionShape3D.disabled = noclip

	if not noclip:
		return false

	var speed = get_move_speed() * noclip_speed_multiplier
	self.velocity = camera_aligned_wish_dir * speed
	global_position += self.velocity * delta

	return true

func _physics_process(delta):
	if is_on_floor():
		_last_frame_was_on_floor = Engine.get_physics_frames()

	var input_dir = Input.get_vector("left", "right", "up", "down").normalized()
	wish_dir = self.global_transform.basis * Vector3(input_dir.x, 0., input_dir.y)
	camera_aligned_wish_dir = %Camera3D.global_transform.basis * Vector3(input_dir.x, 0., input_dir.y)

	_handle_crouch(delta)

	if not _handle_noclip(delta) and not _handle_ladder_physics():
		if not _handle_water_physics(delta):
			if is_on_floor() or _snapped_to_stairs_last_frame:
				if Input.is_action_just_pressed("jump") or (auto_bhop and Input.is_action_pressed("jump")):
					self.velocity.y = jump_velocity
				_handle_ground_physics(delta)
			else:
				_handle_air_physics(delta)

		if not _snap_up_stairs_check(delta):
			_push_away_rigid_bodies()
			move_and_slide()
			_snap_down_to_stairs_check()
	_slide_camera_smooth_back_to_origin(delta)

func _process(delta):
	_handle_controller_look_input(delta)
	if get_interactable_component_at_shapecast():
		if Input.is_action_just_pressed("interact"):
			get_interactable_component_at_shapecast().interact_with()

var _saved_camera_global_position = null
func _save_camera_position_for_smoothing() -> void:
	if _saved_camera_global_position == null:
		_saved_camera_global_position = %CameraSmooth.global_position

func _slide_camera_smooth_back_to_origin(delta) -> void:
	if _saved_camera_global_position == null:
		return

	%CameraSmooth.global_position.y = _saved_camera_global_position.y
	%CameraSmooth.position.y = clampf(%CameraSmooth.position.y, -0.7, 0.7)
	var move_amount = max(self.velocity.length() * delta, walk_speed / 2 * delta)
	%CameraSmooth.position.y = move_toward(%CameraSmooth.position.y, 0.0, move_amount)
	_saved_camera_global_position = %CameraSmooth.global_position
	if %CameraSmooth.position.y == 0.0:
		_saved_camera_global_position = null
	
