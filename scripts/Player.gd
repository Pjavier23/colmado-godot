class_name Player
extends CharacterBody2D
## Player.gd - Player controller with virtual joystick support.

signal package_picked_up
signal package_delivered(money_earned: int)
signal player_hit
signal player_died

const SPEEDS = {
	"bicycle": 150.0,
	"moped": 250.0,
	"car": 350.0
}

var speed: float = 150.0
var current_vehicle: String = "bicycle"
var has_package: bool = false
var is_dead: bool = false
var invincible: bool = false
var invincible_timer: float = 0.0
const INVINCIBLE_TIME = 2.0

# Joystick state (set by HUD/GameScene)
var joystick_dir: Vector2 = Vector2.ZERO

# Visual flicker for invincibility
var flicker_time: float = 0.0

@onready var body_rect: ColorRect = $BodyRect
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var package_indicator: ColorRect = $PackageIndicator
@onready var hit_area: Area2D = $HitArea

func _ready() -> void:
	current_vehicle = GameState.vehicle
	speed = SPEEDS.get(current_vehicle, 150.0)
	_update_visuals()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Handle invincibility
	if invincible:
		invincible_timer -= delta
		flicker_time += delta
		if body_rect:
			body_rect.visible = fmod(flicker_time, 0.1) < 0.05
		if invincible_timer <= 0:
			invincible = false
			if body_rect:
				body_rect.visible = true

	# Move using joystick direction (set externally) or keyboard
	var input_dir = joystick_dir

	# Keyboard fallback
	if input_dir == Vector2.ZERO:
		input_dir.x = Input.get_axis("move_left", "move_right")
		input_dir.y = Input.get_axis("move_up", "move_down")

	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	velocity = input_dir * speed
	move_and_slide()

	# Clamp to screen
	var vp = get_viewport_rect().size
	position.x = clamp(position.x, 20, vp.x - 20)
	position.y = clamp(position.y, 100, vp.y - 80)

	# Update package indicator
	if package_indicator:
		package_indicator.visible = has_package

	# Rotation based on movement for visual effect
	if velocity.length() > 10:
		if body_rect:
			body_rect.rotation = lerp_angle(body_rect.rotation, atan2(velocity.y, velocity.x) - PI/2, delta * 8.0)

func take_hit() -> void:
	if invincible or is_dead:
		return
	invincible = true
	invincible_timer = INVINCIBLE_TIME
	flicker_time = 0.0
	has_package = false
	emit_signal("player_hit")

func die() -> void:
	is_dead = true
	emit_signal("player_died")
	if body_rect:
		body_rect.color = Color(0.5, 0.0, 0.0)

func pick_up_package() -> void:
	has_package = true
	emit_signal("package_picked_up")

func deliver_package(reward: int) -> void:
	has_package = false
	emit_signal("package_delivered", reward)

func _update_visuals() -> void:
	if not body_rect:
		return
	match current_vehicle:
		"bicycle":
			body_rect.color = Color(0.2, 0.6, 1.0)
			body_rect.size = Vector2(20, 28)
		"moped":
			body_rect.color = Color(0.9, 0.3, 0.1)
			body_rect.size = Vector2(24, 32)
		"car":
			body_rect.color = Color(0.1, 0.8, 0.2)
			body_rect.size = Vector2(30, 40)
	body_rect.position = -body_rect.size / 2

func set_joystick_direction(dir: Vector2) -> void:
	joystick_dir = dir
