class_name Weapon
extends Area2D
## Weapon.gd - Projectile/weapon controller.
## Types: platano (boomerang), huevo (straight), salami (arc), fart (aoe slow)
## Spec 2: Physics-based boomerang arc, grenade explosion arc.

enum WeaponType { PLATANO, HUEVO, SALAMI, FART }

var weapon_type: WeaponType = WeaponType.PLATANO
var velocity: Vector2 = Vector2.ZERO
var damage: int = 1
var lifetime: float = 3.0
var elapsed: float = 0.0
var origin: Vector2 = Vector2.ZERO
var spawn_position: Vector2 = Vector2.ZERO
var has_hit: bool = false

# Platano boomerang state (Spec 2 physics)
var flight_time: float = 0.0
var boomerang_speed: float = 300.0

# Salami arc state (Spec 2 physics)
var arc_velocity: Vector2 = Vector2.ZERO
var arc_gravity: float = 300.0
var has_exploded: bool = false

# Fart cloud
var fart_radius: float = 60.0
var fart_active: bool = true

@onready var body_rect: ColorRect = $BodyRect

const WEAPON_TEXTURES = {
	WeaponType.PLATANO: "res://assets/sprites/weapons/platano.png",
	WeaponType.HUEVO: "res://assets/sprites/weapons/huevo.png",
	WeaponType.SALAMI: "res://assets/sprites/weapons/salami.png",
	WeaponType.FART: "res://assets/sprites/weapons/fart.png",
}

var weapon_sprite: Sprite2D = null

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
	spawn_position = global_position
	_setup_visuals()
	_setup_weapon_sprite()
	if weapon_type == WeaponType.FART:
		_start_fart()

func _setup_weapon_sprite() -> void:
	var tex_path = WEAPON_TEXTURES.get(weapon_type, "")
	if tex_path:
		weapon_sprite = Sprite2D.new()
		weapon_sprite.name = "WeaponSprite"
		weapon_sprite.texture = load(tex_path)
		weapon_sprite.position = Vector2(0, 0)
		add_child(weapon_sprite)
		if body_rect:
			body_rect.visible = false

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
			_platano_update(delta)
		WeaponType.HUEVO:
			_update_huevo(delta)
		WeaponType.SALAMI:
			_salami_update(delta)
		WeaponType.FART:
			_update_fart(delta)

# ─── Platano Boomerang (Spec 2 curved physics) ────────────────────────────────
func _platano_update(delta: float) -> void:
	flight_time += delta
	var t = flight_time / 1.5  # normalize over 1.5 second flight

	if t < 0.5:
		# Outward phase - fly forward with slight curve
		position += velocity * delta
		velocity = velocity.rotated(2.0 * delta)
	elif t < 1.0:
		# Return phase - curve back to spawn origin
		var to_origin = (spawn_position - position).normalized()
		velocity = velocity.lerp(to_origin * 200.0, 0.1)
		position += velocity * delta
	else:
		emit_signal("weapon_expired")
		queue_free()
		return

	# Spin the weapon sprite
	if weapon_sprite:
		weapon_sprite.rotate(8.0 * delta)
	else:
		rotation += 8.0 * delta

# ─── Huevo (Straight shot) ────────────────────────────────────────────────────
func _update_huevo(delta: float) -> void:
	global_position += velocity * delta
	rotation += delta * 5.0
	if weapon_sprite:
		weapon_sprite.rotation += delta * 5.0
	var vp = get_viewport_rect().size
	if global_position.x < -20 or global_position.x > vp.x + 20 or \
	   global_position.y < -20 or global_position.y > vp.y + 20:
		emit_signal("weapon_expired")
		queue_free()

# ─── Salami Grenade (Spec 2 arc + explosion) ─────────────────────────────────
func _salami_update(delta: float) -> void:
	if has_exploded:
		return
	arc_velocity.y += arc_gravity * delta
	position += arc_velocity * delta

	# Rotate to show arc trajectory
	if weapon_sprite:
		weapon_sprite.rotation += 5.0 * delta
	else:
		rotation += 5.0 * delta

	# Check if landed (road level ~y > 500 or past viewport bottom)
	var vp = get_viewport_rect().size
	if position.y > vp.y - 50 and not has_exploded:
		has_exploded = true
		_explode()

func _explode() -> void:
	if not is_inside_tree():
		return

	# Show explosion circle
	var circle = ColorRect.new()
	circle.size = Vector2(80, 80)
	circle.position = global_position - Vector2(40, 40)
	circle.color = Color(1, 0.5, 0, 0.6)
	if get_parent():
		get_parent().add_child(circle)

	# Damage nearby enemies via distance check
	if get_parent():
		var enemy_container = get_parent().get_parent().get_node_or_null("EnemyContainer")
		if enemy_container:
			for enemy in enemy_container.get_children():
				if not is_instance_valid(enemy):
					continue
				if global_position.distance_to(enemy.global_position) < 80:
					if enemy.has_method("take_damage"):
						enemy.take_damage(damage)

	# Fade and remove explosion circle
	var tween = create_tween()
	tween.tween_property(circle, "modulate:a", 0.0, 0.5)
	tween.tween_callback(circle.queue_free)

	emit_signal("weapon_expired")
	queue_free()

# ─── Fart Cloud ───────────────────────────────────────────────────────────────
func _start_fart() -> void:
	if weapon_sprite:
		weapon_sprite.modulate = Color(1, 1, 1, 0.0)
		var tween = create_tween()
		tween.tween_property(weapon_sprite, "modulate:a", 0.7, 0.5)
		tween.tween_property(weapon_sprite, "modulate:a", 0.3, 2.0)
	elif body_rect:
		body_rect.color = Color(0.5, 0.9, 0.3, 0.0)
		var tween = create_tween()
		tween.tween_property(body_rect, "color:a", 0.5, 0.5)
		tween.tween_property(body_rect, "color:a", 0.2, 2.0)

func _update_fart(delta: float) -> void:
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
			# Initial arc velocity: forward with slight upward arc
			arc_velocity = dir.normalized() * 180.0 + Vector2(0, -200.0)
			damage = 2
			lifetime = 5.0
		WeaponType.FART:
			damage = 0
			lifetime = 3.0
