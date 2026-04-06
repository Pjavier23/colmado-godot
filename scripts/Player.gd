class_name Player
extends CharacterBody2D
## Player.gd - Player controller with virtual joystick support.
## Spec 2: Physics-based movement with moped traction feel.

signal package_picked_up
signal package_delivered(money_earned: int)
signal player_hit
signal player_died
signal package_dropped

# ─── Physics constants ────────────────────────────────────────────────────────
const ACCELERATION = 400.0
const FRICTION = 300.0
const MAX_SPEED_BIKE = 120.0
const MAX_SPEED_MOPED = 220.0
const MAX_SPEED_CAR = 320.0
const TURN_SPEED = 3.0  # radians per second
const INVINCIBLE_TIME = 2.0

# ─── State ────────────────────────────────────────────────────────────────────
var current_vehicle: String = "bicycle"
var has_package: bool = false
var is_dead: bool = false
var is_invincible: bool = false
var invincible_timer: float = 0.0
var lives: int = 3
var speed_multiplier: float = 1.0

# Physics state
var speed: float = 0.0
var facing_angle: float = -PI / 2  # Start facing up

# Joystick state (set by HUD/GameScene)
var joystick_dir: Vector2 = Vector2.ZERO

# Visual flicker for invincibility
var flicker_time: float = 0.0

# Sprite reference
var player_sprite: Sprite2D = null

@onready var body_rect: ColorRect = $BodyRect
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var package_indicator: ColorRect = $PackageIndicator
@onready var hit_area: Area2D = $HitArea

func _ready() -> void:
	current_vehicle = GameState.vehicle
	lives = GameState.lives
	_update_visuals()
	_setup_player_sprite()

func _setup_player_sprite() -> void:
	var tex_path = ""
	match current_vehicle:
		"moped":
			tex_path = "res://assets/sprites/vehicles/moped_player.png"
		"bicycle":
			tex_path = "res://assets/sprites/vehicles/bicycle_player.png"
		"car":
			tex_path = "res://assets/sprites/vehicles/enemy_car1.png"
	if tex_path:
		player_sprite = Sprite2D.new()
		player_sprite.name = "PlayerSprite"
		player_sprite.texture = load(tex_path)
		player_sprite.position = Vector2(0, 0)
		add_child(player_sprite)
		if body_rect:
			body_rect.visible = false
		var wf = get_node_or_null("WheelFront")
		if wf: wf.visible = false
		var wb = get_node_or_null("WheelBack")
		if wb: wb.visible = false

func get_max_speed() -> float:
	var base: float = MAX_SPEED_BIKE
	match current_vehicle:
		"bicycle":
			base = MAX_SPEED_BIKE
		"moped":
			base = MAX_SPEED_MOPED
		"car":
			base = MAX_SPEED_CAR
	return base * speed_multiplier

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Handle invincibility flicker
	if is_invincible:
		invincible_timer -= delta
		flicker_time += delta
		var flicker_vis = fmod(flicker_time, 0.1) < 0.05
		if body_rect:
			body_rect.visible = flicker_vis
		if player_sprite:
			player_sprite.visible = flicker_vis
		if invincible_timer <= 0:
			is_invincible = false
			invincible_timer = 0.0
			if body_rect:
				body_rect.visible = false
			if player_sprite:
				player_sprite.visible = true

	# Get input direction
	var input_dir: Vector2 = joystick_dir
	if input_dir == Vector2.ZERO:
		input_dir.x = Input.get_axis("move_left", "move_right")
		input_dir.y = Input.get_axis("move_up", "move_down")
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	# Physics-based movement: acceleration, friction, turning
	if input_dir.length() > 0.1:
		var target_angle = input_dir.angle()
		facing_angle = lerp_angle(facing_angle, target_angle, TURN_SPEED * delta)
		speed = move_toward(speed, get_max_speed(), ACCELERATION * delta)
	else:
		speed = move_toward(speed, 0.0, FRICTION * delta)

	velocity = Vector2(cos(facing_angle), sin(facing_angle)) * speed
	move_and_slide()

	# Clamp to screen bounds
	var vp = get_viewport_rect().size
	position.x = clamp(position.x, 20, vp.x - 20)
	position.y = clamp(position.y, 100, vp.y - 80)

	# Rotate sprite to face direction
	if speed > 10:
		if player_sprite:
			player_sprite.rotation = facing_angle + PI / 2
		elif body_rect:
			body_rect.rotation = facing_angle + PI / 2

	# Update package indicator
	if package_indicator:
		package_indicator.visible = has_package

func take_damage(amount: int = 1) -> void:
	if is_invincible or is_dead:
		return

	lives -= amount
	is_invincible = true
	invincible_timer = INVINCIBLE_TIME
	flicker_time = 0.0

	# Drop package if carrying
	if has_package:
		has_package = false
		_drop_package()
		emit_signal("package_dropped")

	emit_signal("player_hit")

func _drop_package() -> void:
	var pkg = Sprite2D.new()
	var tex = load("res://assets/sprites/ui/pickup_marker.png")
	if tex:
		pkg.texture = tex
	else:
		# Fallback: yellow rect
		var rect = ColorRect.new()
		rect.size = Vector2(20, 20)
		rect.position = Vector2(-10, -10)
		rect.color = Color(1.0, 0.9, 0.1)
		pkg.add_child(rect)
	pkg.position = position
	if get_parent():
		get_parent().add_child(pkg)
	# Package disappears after 5 seconds
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(pkg):
		pkg.queue_free()

# Legacy compatibility wrapper
func take_hit() -> void:
	take_damage(1)

func die() -> void:
	is_dead = true
	speed = 0.0
	emit_signal("player_died")
	if player_sprite:
		player_sprite.modulate = Color(0.5, 0.0, 0.0)
	elif body_rect:
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
