extends Area2D
## Weapon.gd - Projectile/weapon controller.
## Types: platano (boomerang), huevo (straight), salami (arc), fart (aoe slow)

enum WeaponType { PLATANO, HUEVO, SALAMI, FART }

var weapon_type: WeaponType = WeaponType.PLATANO
var velocity: Vector2 = Vector2.ZERO
var damage: int = 1
var lifetime: float = 3.0
var elapsed: float = 0.0
var origin: Vector2 = Vector2.ZERO
var has_hit: bool = false

# Platano boomerang state
var boomerang_returning: bool = false
var boomerang_speed: float = 300.0

# Salami arc
var arc_tween: Tween = null
var arc_target: Vector2 = Vector2.ZERO

# Fart cloud
var fart_radius: float = 60.0
var fart_active: bool = true

@onready var body_rect: ColorRect = $BodyRect
@onready var hit_area: Area2D = $HitDetect if has_node("HitDetect") else null

const WEAPON_COLORS = {
	WeaponType.PLATANO: Color(1.0, 0.85, 0.1),
	WeaponType.HUEVO: Color(0.95, 0.95, 0.85),
	WeaponType.SALAMI: Color(0.8, 0.2, 0.2),
	WeaponType.FART: Color(0.5, 0.9, 0.3, 0.5),
}

signal enemy_hit(enemy: Node)
signal weapon_expired

func _ready() -> void:
	origin = global_position
	_setup_visuals()
	if weapon_type == WeaponType.SALAMI:
		_start_arc()
	elif weapon_type == WeaponType.FART:
		_start_fart()

func _setup_visuals() -> void:
	if not body_rect:
		return
	body_rect.color = WEAPON_COLORS.get(weapon_type, Color.WHITE)
	match weapon_type:
		WeaponType.PLATANO:
			body_rect.size = Vector2(16, 8)
		WeaponType.HUEVO:
			body_rect.size = Vector2(10, 10)
		WeaponType.SALAMI:
			body_rect.size = Vector2(14, 14)
		WeaponType.FART:
			body_rect.size = Vector2(fart_radius * 2, fart_radius * 2)
	body_rect.position = -body_rect.size / 2

func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		emit_signal("weapon_expired")
		queue_free()
		return

	match weapon_type:
		WeaponType.PLATANO:
			_update_platano(delta)
		WeaponType.HUEVO:
			_update_huevo(delta)
		WeaponType.FART:
			_update_fart(delta)

func _update_platano(delta: float) -> void:
	if not boomerang_returning:
		global_position += velocity * delta
		# After 0.4s reverse
		if elapsed > 0.4:
			boomerang_returning = true
			velocity = -velocity * 0.8
	else:
		global_position += velocity * delta
		# Visual spin
		rotation += delta * 10.0
		# If returned near origin
		if global_position.distance_to(origin) < 20:
			emit_signal("weapon_expired")
			queue_free()

func _update_huevo(delta: float) -> void:
	global_position += velocity * delta
	rotation += delta * 5.0
	var vp = get_viewport_rect().size
	if global_position.x < -20 or global_position.x > vp.x + 20 or \
	   global_position.y < -20 or global_position.y > vp.y + 20:
		emit_signal("weapon_expired")
		queue_free()

func _start_arc() -> void:
	arc_target = global_position + Vector2(randf_range(-100, 100), randf_range(80, 200))
	var mid = (global_position + arc_target) / 2 + Vector2(0, -120)
	arc_tween = create_tween()
	arc_tween.set_ease(Tween.EASE_IN_OUT)
	# Simulate arc with position
	arc_tween.tween_method(_arc_move.bind(global_position, arc_target), 0.0, 1.0, 1.0)
	arc_tween.tween_callback(_salami_explode)

func _arc_move(t: float, start: Vector2, end: Vector2) -> void:
	var mid = (start + end) / 2 + Vector2(0, -100)
	# Quadratic bezier
	var p = start.lerp(mid, t).lerp(mid.lerp(end, t), t)
	global_position = p
	rotation += 0.3

func _salami_explode() -> void:
	# Create explosion visual
	if body_rect:
		body_rect.size = Vector2(50, 50)
		body_rect.position = -body_rect.size / 2
		body_rect.color = Color(1.0, 0.4, 0.0, 0.8)
	await get_tree().create_timer(0.3).timeout
	emit_signal("weapon_expired")
	if is_instance_valid(self):
		queue_free()

func _start_fart() -> void:
	if body_rect:
		body_rect.color = Color(0.5, 0.9, 0.3, 0.0)
	var tween = create_tween()
	tween.tween_property(body_rect, "color:a", 0.5, 0.5)
	tween.tween_property(body_rect, "color:a", 0.2, 2.0)

func _update_fart(delta: float) -> void:
	# Wobble slightly
	global_position += Vector2(sin(elapsed * 3) * 20, cos(elapsed * 2) * 10) * delta

func _on_area_entered(area: Area2D) -> void:
	if has_hit:
		return
	if area.is_in_group("enemy_hit"):
		var enemy = area.get_parent()
		if enemy and enemy.has_method("take_damage"):
			if weapon_type == WeaponType.FART:
				if enemy.has_method("apply_slow"):
					enemy.apply_slow(3.0)
			else:
				has_hit = true
				enemy.take_damage(damage)
				emit_signal("enemy_hit", enemy)
				if weapon_type != WeaponType.PLATANO:
					queue_free()

func setup(type: WeaponType, dir: Vector2) -> void:
	weapon_type = type
	match type:
		WeaponType.PLATANO:
			velocity = dir.normalized() * boomerang_speed
			damage = 1
			lifetime = 2.0
		WeaponType.HUEVO:
			velocity = dir.normalized() * 350.0
			damage = 1
			lifetime = 3.0
		WeaponType.SALAMI:
			damage = 2
			lifetime = 4.0
		WeaponType.FART:
			damage = 0
			lifetime = 3.0
