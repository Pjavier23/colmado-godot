class_name Enemy
extends CharacterBody2D
## Enemy.gd - Enemy AI controller.
## Types: saboteur, car, police

enum EnemyType { SABOTEUR, CAR, POLICE }

var enemy_type: EnemyType = EnemyType.SABOTEUR
var player_ref: Node2D = null
var speed: float = 80.0
var health: int = 2
var is_slowed: bool = false
var slow_timer: float = 0.0
var base_speed: float = 80.0
var lane_y: float = 400.0  # For car type
var direction: int = 1     # For car type: 1 = right, -1 = left
var active: bool = true
var stun_timer: float = 0.0

@onready var body_rect: ColorRect = $BodyRect
@onready var hit_area: Area2D = $HitArea

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
	speed = base_speed
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

func _physics_process(delta: float) -> void:
	if not active:
		return

	# Handle slow effect
	if is_slowed:
		slow_timer -= delta
		if slow_timer <= 0:
			is_slowed = false
			speed = base_speed

	# Handle stun
	if stun_timer > 0:
		stun_timer -= delta
		return

	match enemy_type:
		EnemyType.SABOTEUR:
			_chase_player(delta)
		EnemyType.CAR:
			_drive_lane(delta)
		EnemyType.POLICE:
			_police_chase(delta)

func _chase_player(delta: float) -> void:
	if not player_ref:
		return
	var dir = (player_ref.global_position - global_position).normalized()
	velocity = dir * speed
	move_and_slide()

func _drive_lane(delta: float) -> void:
	velocity = Vector2(direction * speed, 0)
	move_and_slide()
	var vp = get_viewport_rect().size
	if global_position.x > vp.x + 60:
		global_position.x = -60
		lane_y = randf_range(200, vp.y - 150)
		global_position.y = lane_y
	elif global_position.x < -60:
		global_position.x = vp.x + 60
		lane_y = randf_range(200, vp.y - 150)
		global_position.y = lane_y

func _police_chase(delta: float) -> void:
	if not player_ref:
		return
	# Police only chases if player score is high
	if GameState.score < 500:
		# Patrol
		velocity = Vector2(direction * speed * 0.5, 0)
		move_and_slide()
		if global_position.x > 350 or global_position.x < 40:
			direction *= -1
	else:
		var dir = (player_ref.global_position - global_position).normalized()
		velocity = dir * speed * 1.2
		move_and_slide()

func apply_slow(duration: float) -> void:
	is_slowed = true
	slow_timer = duration
	speed = base_speed * 0.4

func take_damage(amount: int = 1) -> bool:
	health -= amount
	if body_rect:
		# Flash white
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
	# Simple death animation
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(2, 2), 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

func setup(type: EnemyType, player: Node2D) -> void:
	enemy_type = type
	player_ref = player
