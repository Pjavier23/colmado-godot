class_name Enemy
extends CharacterBody2D
## Enemy.gd - Enemy AI controller.
## Types: saboteur, car, police
## Spec 2: Smart AI — zigzag saboteur, lane-keeping car, fast police chase.

enum EnemyType { SABOTEUR, CAR, POLICE }

var enemy_type: EnemyType = EnemyType.SABOTEUR
var player_ref: Node2D = null
var health: int = 2
var is_slowed: bool = false
var slow_timer: float = 0.0
var base_speed: float = 80.0
var speed_multiplier: float = 1.0
var lane_offset: float = 0.0  # horizontal lane bias for cars
var direction: int = 1         # For car type: 1 = right, -1 = left
var active: bool = true
var stun_timer: float = 0.0
var ai_timer: float = 0.0

@onready var body_rect: ColorRect = $BodyRect
@onready var hit_area: Area2D = $HitArea

var enemy_sprite: Sprite2D = null

const ENEMY_TEXTURES = {
	EnemyType.SABOTEUR: "res://assets/sprites/characters/saboteur.png",
	EnemyType.CAR: "res://assets/kenney/racing/car_red_1.png",
	EnemyType.POLICE: "res://assets/kenney/racing/car_blue_small_1.png",
}

const ENEMY_COLORS = {
	EnemyType.SABOTEUR: Color(0.9, 0.1, 0.1),
	EnemyType.CAR: Color(0.8, 0.6, 0.0),
	EnemyType.POLICE: Color(0.1, 0.1, 0.9),
}

const ENEMY_SPEEDS = {
	EnemyType.SABOTEUR: 75.0,
	EnemyType.CAR: 200.0,
	EnemyType.POLICE: 130.0,
}

func _ready() -> void:
	base_speed = ENEMY_SPEEDS.get(enemy_type, 80.0)
	# Randomize lane offset for cars
	if enemy_type == EnemyType.CAR:
		lane_offset = randf_range(-30.0, 30.0)
	if body_rect:
		body_rect.color = ENEMY_COLORS.get(enemy_type, Color(1, 0, 0))
		match enemy_type:
			EnemyType.SABOTEUR:
				body_rect.size = Vector2(22, 22)
			EnemyType.CAR:
				body_rect.size = Vector2(34, 50)
			EnemyType.POLICE:
				body_rect.size = Vector2(26, 36)
		body_rect.position = -body_rect.size / 2
	_setup_enemy_sprite()

func _setup_enemy_sprite() -> void:
	var tex_path = ENEMY_TEXTURES.get(enemy_type, "")
	if tex_path:
		enemy_sprite = Sprite2D.new()
		enemy_sprite.name = "EnemySprite"
		enemy_sprite.texture = load(tex_path)
		enemy_sprite.position = Vector2(0, 0)
		add_child(enemy_sprite)
		if body_rect:
			body_rect.visible = false

func _physics_process(delta: float) -> void:
	if not active:
		return

	# Handle slow effect
	if is_slowed:
		slow_timer -= delta
		if slow_timer <= 0:
			is_slowed = false
			speed_multiplier = 1.0

	# Handle stun
	if stun_timer > 0:
		stun_timer -= delta
		return

	ai_timer += delta

	match enemy_type:
		EnemyType.SABOTEUR:
			_saboteur_ai(delta)
		EnemyType.CAR:
			_car_ai(delta)
		EnemyType.POLICE:
			_police_ai(delta)

# ─── Saboteur: zigzag chase (Spec 2) ─────────────────────────────────────────
func _saboteur_ai(delta: float) -> void:
	if not player_ref:
		return

	var to_player = (player_ref.position - position).normalized()

	# Add zigzag oscillation
	var zigzag = sin(ai_timer * 3.0) * 0.5
	var dir = to_player.rotated(zigzag)

	var current_speed = base_speed * speed_multiplier
	if is_slowed:
		current_speed *= 0.4
	velocity = dir * current_speed
	move_and_slide()

# ─── Car: lane-keeping with player swerve (Spec 2) ───────────────────────────
func _car_ai(delta: float) -> void:
	var current_speed = base_speed * speed_multiplier
	if is_slowed:
		current_speed *= 0.4

	velocity = Vector2(direction * current_speed + lane_offset * 0.1, 0)
	move_and_slide()

	# Swerve toward player if close
	if player_ref and position.distance_to(player_ref.position) < 150:
		var swerve = (player_ref.position.x - position.x) * 0.3
		velocity.x += swerve
		move_and_slide()

	# Wrap around viewport
	var vp = get_viewport_rect().size
	if position.x > vp.x + 60:
		position.x = -60
		position.y = randf_range(200, vp.y - 150)
	elif position.x < -60:
		position.x = vp.x + 60
		position.y = randf_range(200, vp.y - 150)

# ─── Police: fast direct chase (Spec 2) ──────────────────────────────────────
func _police_ai(delta: float) -> void:
	if not player_ref:
		return

	var current_speed = base_speed * speed_multiplier
	if is_slowed:
		current_speed *= 0.4

	# Police always chases directly at 1.5x speed
	var dir = (player_ref.position - position).normalized()
	velocity = dir * current_speed * 1.5
	move_and_slide()

func apply_slow(duration: float) -> void:
	is_slowed = true
	slow_timer = duration
	speed_multiplier = 0.4

func take_damage(amount: int = 1) -> bool:
	health -= amount
	# Flash white
	if enemy_sprite:
		enemy_sprite.modulate = Color.WHITE
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self) and enemy_sprite:
			enemy_sprite.modulate = Color.WHITE
	elif body_rect:
		var original = body_rect.color
		body_rect.color = Color.WHITE
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self) and body_rect:
			body_rect.color = original
	if health <= 0:
		_die()
		return true
	return false

func _die() -> void:
	active = false
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(2, 2), 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

func setup(type: EnemyType, player: Node2D) -> void:
	enemy_type = type
	player_ref = player
