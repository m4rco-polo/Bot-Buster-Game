extends CharacterBody3D

var speed
const WALK_SPEED = 3.8
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
var SENSITIVITY = 0.009
const SLIDE_SPEED = 20
var slide = "slide"
var RESET = "RESET"
var sliding = false
var Arms_Fire = "Arms_Fire"
var Arms_Idle = "Arms_Idle"
var firing = false
var Arms_Reset = "RESET"
var Arms_Sprint = "Arms_Sprint"
var sprinting = false
var Arms_Inspect = "Arms_Inspect"
var inspecting = false
var idle = false
# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 9.8

# fov variables
var fov = 80
const FOV_CHANGE = 2.5

@onready var model = $MeshInstance3D
@onready var head = $Head
@onready var camera = $Head/Camera3D
@export var camera_rotation_amount : float = 0.02
@onready var particles = $particles
@onready var anim_tree = $AnimationTree
@onready var anim_state = $AnimationTree.get("parameters/playback")
@onready var anim_tree1 = $Head/Camera3D/WeaponHolder/MP5/AnimationTree
@onready var anim_state1 = $Head/Camera3D/WeaponHolder/MP5/AnimationTree.get("parameters/playback")
@onready var draw_audio = $Head/Camera3D/WeaponHolder/MP5/MP5_Draw
@onready var weapon_holder = $Head/Camera3D/WeaponHolder
@export var weapon_sway_amount : float = 2
@export var weapon_rotation_amount : float = 0.18
var def_weapon_holder_pos : Vector3
#bob variables
const BOB_FREQ = 3
const BOB_AMP = 0.05
var t_bob = 0.0

#footstep variables
var can_play : bool = true
signal step

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	def_weapon_holder_pos = weapon_holder.position
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
#head bobbing
	t_bob += delta * velocity.length() * float (is_on_floor())
	camera.transform.origin = _headbob(t_bob)
	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	#Sprint
	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 2.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 2.0)
	
	move_and_slide()
	cam_tilt(input_dir.x, delta)
	weapon_tilt(input_dir.x, delta)
	weapon_bob(velocity.length(),delta)
#weapon and camera sway/tilt
func cam_tilt(input_x, delta):
	if camera:
		camera.rotation.z = lerp(camera.rotation.z, -input_x * camera_rotation_amount, 10 * delta)
func weapon_tilt(input_x, delta):
	if weapon_holder:
		weapon_holder.rotation.z = lerp(weapon_holder.rotation.z, -input_x * weapon_rotation_amount, 10 * delta)
#sliding
	anim_tree.set("parameters/conditions/sliding", sliding)
	if Input.is_action_just_pressed("slide") and Input.is_action_pressed("sprint") and is_on_floor():
		speed = SLIDE_SPEED
		sliding = true
		anim_state.travel(slide)
	if Input.is_action_just_released("slide"):
		particles.emitting = false
		sliding = false
		speed = SPRINT_SPEED
		anim_state.travel(RESET)
	# FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 1.5)
	var target_fov = fov + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	#shooting anim
	if Input.is_action_just_pressed("fire"):
		anim_tree1.set("parameters/conditions/firing", firing)
		firing = true
	if Input.is_action_just_released("fire"):
		firing = false
		anim_state1.travel(Arms_Idle)
#inspect anim
	if Input.is_action_just_pressed("inspect"):
		anim_tree1.set("parameters/conditions/inspecting", inspecting)
		inspecting = true
		anim_state1.travel(Arms_Inspect)
	if velocity == Vector3.ZERO:
		anim_tree1.set("parameters/conditions/idle", idle)
		idle = true
		anim_state1.travel(Arms_Idle)
func _play_draw_mp5_audio():
	draw_audio.play()
func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	
	var low_pos = BOB_AMP - 0.05
	
	if pos.y > -low_pos:
		can_play = true
		
	if pos.y < -low_pos and can_play:
		can_play = false
		emit_signal("step")
		
	return pos

func weapon_bob(vel : float, delta):
	if weapon_holder:
		if vel > 3.7 and is_on_floor():
			var bob_amount : float = 0.01
			var bob_freq : float = 0.01
			weapon_holder.position.y = lerp(weapon_holder.position.y, def_weapon_holder_pos.y + sin(Time.get_ticks_msec() * bob_freq) * bob_amount, 10 * delta)
			weapon_holder.position.x = lerp(weapon_holder.position.x, def_weapon_holder_pos.x + sin(Time.get_ticks_msec() * bob_freq * 0.5) * bob_amount, 10 * delta)
			
		else:
			weapon_holder.position.y = lerp(weapon_holder.position.y, def_weapon_holder_pos.y, 10 * delta)
			weapon_holder.position.x = lerp(weapon_holder.position.x, def_weapon_holder_pos.x, 10 * delta)
