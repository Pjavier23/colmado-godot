extends Node2D
## GameScene.gd - Main gameplay scene.
## Top-down courier arcade with PS1 aesthetic.
## Spec 2: Collision detection, POW effects, powerup collection, wave spawning.

# ─── Constants ───────────────────────────────────────────────────────────────
const SCROLL_SPEED = 150.0
const ROAD_MARK_COUNT = 8
const BUILDING_COUNT = 6

# ─── Mission config (loaded from GameState) ───────────────────────────────────
var mission_time: float = 120.0
var deliveries_required: int = 3
var mission_reward_per_delivery: int = 50

const MISSIONS_CONFIG = [
	{"time": 120.0, "deliveries": 3, "reward": 50, "enemy_speed_mult": 0.8},
	{"time": 150.0, "deliveries": 6, "reward": 20, "enemy_speed_mult": 1.0},
	{"time": 180.0, "deliveries": 8, "reward": 30, "enemy_speed_mult": 1.3},
	{"time": 200.0, "deliveries": 10, "reward": 40, "enemy_speed_mult": 1.6},
]

# ─── State ────────────────────────────────────────────────────────────────────
var lives: int = 3
var score: int = 0
var mission_timer: float = 120.0
var deliveries_done: int = 0
var enemy_speed_mult: float = 1.0

var current_weapon: String = "platano"
var weapon_ammo: Dictionary = {}
var fire_cooldown_mult: float = 1.0

var pickup_active: bool = false
var dropoff_active: bool = false
var has_package: bool = false
var pickup_pos: Vector2 = Vector2.ZERO
var dropoff_pos: Vector2 = Vector2.ZERO
var streak: int = 0

var enemies: Array = []
var active_weapons: Array = []
var powerups: Array = []
var game_over: bool = false
var paused_game: bool = false
var get_ready: bool = true

const MAX_ENEMIES = 8

# ─── Wave spawn system (Spec 2) ───────────────────────────────────────────────
var spawn_timer: float = 0.0
var spawn_interval: float = 3.0
var wave: int = 0
var enemies_per_wave: int = 3

# Scrolling world
var road_marks: Array = []
var buildings_left: Array = []
var buildings_right: Array = []

var player_direction: Vector2 = Vector2.ZERO

# ─── Node references ──────────────────────────────────────────────────────────
@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var world: Node2D = $World
@onready var pickup_marker: ColorRect = $Markers/PickupMarker
@onready var dropoff_marker: ColorRect = $Markers/DropoffMarker
@onready var scanline_overlay: ColorRect = $ScanlineOverlay
@onready var game_over_panel: ColorRect = $HUD/GameOverPanel
@onready var enemy_container: Node2D = $EnemyContainer
@onready var weapon_container: Node2D = $WeaponContainer

const WeaponScript = preload("res://scripts/Weapon.gd")
const EnemyScript = preload("res://scripts/Enemy.gd")

# ─── Setup ────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_load_mission()
	_setup_world()
	_setup_hud()
	_connect_player()
	_connect_hud()
	_connect_game_over_buttons()
	# Center player on screen
	var vp = get_viewport_rect().size
	if player:
		player.global_position = vp / 2
	_play_get_ready()

func _play_get_ready() -> void:
	get_ready = true
	var label = Label.new()
	label.text = "GET READY!"
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	await tween.finished
	label.queue_free()
	get_ready = false
	_spawn_pickup()

func _connect_hud() -> void:
	if not hud:
		return
	if hud.has_signal("direction_changed"):
		if not hud.direction_changed.is_connected(_on_direction_changed):
			hud.direction_changed.connect(_on_direction_changed)
	if hud.has_signal("joystick_moved"):
		if not hud.joystick_moved.is_connected(_on_joystick_moved):
			hud.joystick_moved.connect(_on_joystick_moved)
	if hud.has_signal("fire_pressed"):
		if not hud.fire_pressed.is_connected(_on_fire_pressed):
			hud.fire_pressed.connect(_on_fire_pressed)
	if hud.has_signal("weapon_selected"):
		if not hud.weapon_selected.is_connected(_on_weapon_selected):
			hud.weapon_selected.connect(_on_weapon_selected)

func _connect_game_over_buttons() -> void:
	var retry_btn = get_node_or_null("HUD/GameOverPanel/RetryButton")
	if retry_btn:
		if not retry_btn.pressed.is_connected(_on_retry_button_pressed):
			retry_btn.pressed.connect(_on_retry_button_pressed)
	var menu_btn = get_node_or_null("HUD/GameOverPanel/MenuButton")
	if menu_btn:
		if not menu_btn.pressed.is_connected(_on_menu_button_pressed):
			menu_btn.pressed.connect(_on_menu_button_pressed)

func _load_mission() -> void:
	var m_idx = clamp(GameState.current_mission, 0, MISSIONS_CONFIG.size() - 1)
	var m = MISSIONS_CONFIG[m_idx]
	mission_time = m["time"]
	mission_timer = mission_time
	deliveries_required = m["deliveries"]
	mission_reward_per_delivery = m["reward"]
	enemy_speed_mult = m["enemy_speed_mult"]
	lives = GameState.lives
	weapon_ammo = GameState.weapon_ammo.duplicate()
	current_weapon = "platano"

func _setup_world() -> void:
	if not world:
		return
	var vp = get_viewport_rect().size

	var road_bg = get_node_or_null("World/RoadBg")
	if road_bg:
		var road_tex = TextureRect.new()
		road_tex.name = "RoadTexture"
		road_tex.texture = load("res://assets/sprites/tiles/road.png")
		road_tex.stretch_mode = TextureRect.STRETCH_TILE
		road_tex.anchors_preset = 15
		road_tex.anchor_right = 1.0
		road_tex.anchor_bottom = 1.0
		road_tex.modulate = Color(1, 1, 1, 0.4)
		road_bg.add_child(road_tex)

	for grass_node_name in ["GrassLeft", "GrassRight"]:
		var grass_node = get_node_or_null("World/" + grass_node_name)
		if grass_node:
			var grass_tex = TextureRect.new()
			grass_tex.texture = load("res://assets/sprites/tiles/grass.png")
			grass_tex.stretch_mode = TextureRect.STRETCH_TILE
			grass_tex.anchors_preset = 15
			grass_tex.anchor_right = 1.0
			grass_tex.anchor_bottom = 1.0
			grass_tex.modulate = Color(1, 1, 1, 0.5)
			grass_node.add_child(grass_tex)

	for sw_node_name in ["SidewalkLeft", "SidewalkRight"]:
		var sw_node = get_node_or_null("World/" + sw_node_name)
		if sw_node:
			var sw_tex = TextureRect.new()
			sw_tex.texture = load("res://assets/sprites/tiles/sidewalk.png")
			sw_tex.stretch_mode = TextureRect.STRETCH_TILE
			sw_tex.anchors_preset = 15
			sw_tex.anchor_right = 1.0
			sw_tex.anchor_bottom = 1.0
			sw_tex.modulate = Color(1, 1, 1, 0.5)
			sw_node.add_child(sw_tex)

	for i in ROAD_MARK_COUNT:
		var mark = ColorRect.new()
		mark.size = Vector2(8, 40)
		mark.color = Color(1.0, 0.9, 0.1)
		mark.position = Vector2(vp.x / 2 - 4, i * 110 - 20)
		world.add_child(mark)
		road_marks.append(mark)

	for i in BUILDING_COUNT:
		var b = _create_building(true, i)
		world.add_child(b)
		buildings_left.append(b)

	for i in BUILDING_COUNT:
		var b = _create_building(false, i)
		world.add_child(b)
		buildings_right.append(b)

func _create_building(left: bool, idx: int) -> Node2D:
	var container = Node2D.new()
	var vp = get_viewport_rect().size
	var bw = randf_range(55, 85)
	var bh = randf_range(80, 180)
	var bx = 0 if left else vp.x - bw
	var by = idx * 160 + randf_range(-20, 20)

	var colors = [Color(0.25, 0.25, 0.45), Color(0.35, 0.20, 0.25), Color(0.20, 0.35, 0.25)]
	var bcolor = colors[randi() % colors.size()]

	var front = ColorRect.new()
	front.size = Vector2(bw, bh)
	front.color = bcolor
	front.position = Vector2(bx, by)
	container.add_child(front)

	var top = ColorRect.new()
	top.size = Vector2(bw, 14)
	top.color = bcolor.lightened(0.25)
	top.position = Vector2(bx, by - 14)
	container.add_child(top)

	var signs = ["COLMADO", "VARIEDADES", "FRIO-FRIO", "LOTERIA", "FARMACIA"]
	var lbl = Label.new()
	lbl.text = signs[randi() % signs.size()]
	lbl.add_theme_font_size_override("font_size", 7)
	lbl.add_theme_color_override("font_color", Color(1, 1, 0.2))
	lbl.position = Vector2(bx + 4, by + 5)
	container.add_child(lbl)

	container.set_meta("reset_y", by)
	container.set_meta("height", bh + 14)
	return container

func _setup_hud() -> void:
	if not hud:
		return
	hud.update_lives(lives)
	hud.update_score(score)
	hud.update_timer(mission_timer)
	hud.update_money(GameState.money)
	hud.update_weapon(current_weapon, weapon_ammo.get(current_weapon, 0))

func _connect_player() -> void:
	if not player:
		return
	player.connect("player_hit", _on_player_hit)
	player.connect("player_died", _on_player_died)
	if player.has_signal("package_dropped"):
		player.connect("package_dropped", _on_package_dropped)

# ─── Main loop ────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if game_over or paused_game or get_ready:
		return

	_scroll_world(delta)
	_update_timer(delta)
	_check_deliveries()
	_update_spawning(delta)
	_check_weapon_hits()
	_check_enemy_player_collision()
	_check_powerup_collection()
	_update_arrow()
	_wobble_buildings(delta)

func _scroll_world(delta: float) -> void:
	if not world:
		return

	for mark in road_marks:
		mark.position.y += SCROLL_SPEED * delta
		if mark.position.y > get_viewport_rect().size.y + 20:
			mark.position.y -= (get_viewport_rect().size.y + 60)

	for b in buildings_left + buildings_right:
		b.position.y += SCROLL_SPEED * delta * 0.3
		var h = b.get_meta("height", 200)
		if b.position.y > get_viewport_rect().size.y + 50:
			b.position.y -= (get_viewport_rect().size.y + h + 100)

func _wobble_buildings(delta: float) -> void:
	var t = Time.get_ticks_msec() / 1000.0
	for i in buildings_left.size():
		var b = buildings_left[i]
		b.position.x = sin(t * 0.8 + i * 0.7) * 1.5 - 2

func _update_timer(delta: float) -> void:
	mission_timer -= delta
	if hud:
		hud.update_timer(mission_timer)
	if mission_timer <= 0:
		_mission_failed()

func _check_deliveries() -> void:
	if not player:
		return

	if not has_package and pickup_active and pickup_marker:
		if player.global_position.distance_to(pickup_marker.global_position + pickup_marker.size/2) < 40:
			has_package = true
			pickup_active = false
			pickup_marker.visible = false
			if colmado_sprite:
				colmado_sprite.visible = false
			player.has_package = true
			if hud:
				hud.show_delivery_message("¡COGISTE EL PAQUETE!", Color(0.2, 1.0, 0.4))
			_spawn_dropoff()

	elif has_package and dropoff_active and dropoff_marker:
		if player.global_position.distance_to(dropoff_marker.global_position + dropoff_marker.size/2) < 40:
			_complete_delivery()

func _complete_delivery() -> void:
	has_package = false
	dropoff_active = false
	player.has_package = false
	if dropoff_marker:
		dropoff_marker.visible = false
	deliveries_done += 1
	streak += 1

	var bonus = streak * 10
	var earned = mission_reward_per_delivery + bonus
	GameState.add_money(earned)
	GameState.add_score(100 + bonus)
	score = GameState.score

	if hud:
		hud.update_money(GameState.money)
		hud.update_score(score)
		hud.show_delivery_message("¡ENTREGADO! +$%d 🔥x%d" % [earned, streak], Color(1.0, 0.9, 0.1))

	if deliveries_done >= deliveries_required:
		_mission_complete()
	else:
		await get_tree().create_timer(0.5).timeout
		_spawn_pickup()
		# Chance to spawn a powerup after delivery
		if randf() < 0.4:
			_spawn_powerup()

# ─── Wave-based spawn system (Spec 2) ─────────────────────────────────────────
func _update_spawning(delta: float) -> void:
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_spawn_wave()
		spawn_interval = max(1.0, spawn_interval - 0.2)  # Gets faster over time

func _spawn_wave() -> void:
	wave += 1
	var count = min(wave, enemies_per_wave)
	for i in count:
		await get_tree().create_timer(i * 0.5).timeout
		if not game_over:
			_spawn_enemy()

func _spawn_enemy() -> void:
	# Cap active enemies for iPhone performance
	if enemy_container and enemy_container.get_child_count() >= MAX_ENEMIES:
		return
	var type_roll = randf()
	var etype
	if type_roll < 0.5:
		etype = Enemy.EnemyType.SABOTEUR
	elif type_roll < 0.8:
		etype = Enemy.EnemyType.CAR
	else:
		etype = Enemy.EnemyType.POLICE

	var e = _create_enemy_node(etype)
	enemy_container.add_child(e)
	enemies.append(e)

func _create_enemy_node(etype) -> CharacterBody2D:
	var e = CharacterBody2D.new()
	e.set_script(EnemyScript)

	var body = ColorRect.new()
	body.name = "BodyRect"
	e.add_child(body)

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(20, 20)
	col.shape = shape
	e.add_child(col)

	var hit_area = Area2D.new()
	hit_area.name = "HitArea"
	hit_area.add_to_group("enemy_hit")
	var hit_col = CollisionShape2D.new()
	var hit_shape = RectangleShape2D.new()
	hit_shape.size = Vector2(22, 22)
	hit_col.shape = hit_shape
	hit_area.add_child(hit_col)
	e.add_child(hit_area)

	var vp = get_viewport_rect().size
	match etype:
		Enemy.EnemyType.SABOTEUR:
			e.global_position = Vector2(randf_range(40, vp.x - 40), -40)
		Enemy.EnemyType.CAR:
			var dir = 1 if randf() > 0.5 else -1
			e.global_position = Vector2(
				-50 if dir == 1 else vp.x + 50,
				randf_range(200, vp.y - 150)
			)
		Enemy.EnemyType.POLICE:
			e.global_position = Vector2(randf_range(40, vp.x - 40), -40)

	e.setup(etype, player)
	e.speed_multiplier = enemy_speed_mult
	return e

# ─── Weapon hit detection (Spec 2) ────────────────────────────────────────────
func _check_weapon_hits() -> void:
	for weapon in weapon_container.get_children():
		if not is_instance_valid(weapon) or not weapon.is_inside_tree():
			continue
		for enemy in enemy_container.get_children():
			if not is_instance_valid(enemy) or not enemy.is_inside_tree():
				continue
			if not enemy.get("active"):
				continue
			if weapon.position.distance_to(enemy.position) < 40:
				if enemy.has_method("take_damage"):
					enemy.take_damage(weapon.damage if "damage" in weapon else 1)
				var wtype = weapon.get("weapon_type")
				if wtype != null and wtype != Weapon.WeaponType.FART:
					_show_hit_effect(weapon.global_position)
					if is_instance_valid(weapon):
						weapon.queue_free()
					break

func _show_hit_effect(pos: Vector2) -> void:
	var label = Label.new()
	label.text = (["POW!", "BAM!", "DALE!", "AY!"] as Array).pick_random()
	label.position = pos - Vector2(20, 20)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.add_theme_font_size_override("font_size", 20)
	add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "position:y", pos.y - 60, 0.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

# ─── Enemy–Player collision ───────────────────────────────────────────────────
func _check_enemy_player_collision() -> void:
	if not player or player.is_invincible:
		return
	for e in enemies:
		if not is_instance_valid(e) or not e.active:
			continue
		if player.global_position.distance_to(e.global_position) < 28:
			lives -= 1
			streak = 0
			player.take_damage(1)
			if hud:
				hud.update_lives(lives)
				hud.show_delivery_message("¡AY! -1 VIDA", Color(1, 0.2, 0.1))
			if lives <= 0:
				player.die()
			break

# ─── Power-up system (Spec 2) ─────────────────────────────────────────────────
func _spawn_powerup() -> void:
	var vp = get_viewport_rect().size
	var types = ["presidente", "mangu", "cafe"]
	var pu_type = types[randi() % types.size()]

	var pu = ColorRect.new()
	pu.size = Vector2(24, 24)
	pu.position = Vector2(randf_range(60, vp.x - 60), randf_range(150, vp.y - 150))
	pu.set_meta("powerup_type", pu_type)

	match pu_type:
		"presidente":
			pu.color = Color(0.0, 0.6, 1.0)
		"mangu":
			pu.color = Color(0.8, 0.4, 0.0)
		"cafe":
			pu.color = Color(0.4, 0.2, 0.0)

	# Label to identify powerup
	var lbl = Label.new()
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.text = pu_type.to_upper()
	lbl.position = Vector2(0, -14)
	pu.add_child(lbl)

	add_child(pu)
	powerups.append(pu)

	# Auto-remove after 15 seconds if not collected
	await get_tree().create_timer(15.0).timeout
	if is_instance_valid(pu):
		powerups.erase(pu)
		pu.queue_free()

func _check_powerup_collection() -> void:
	if not player:
		return
	for pu in powerups.duplicate():
		if not is_instance_valid(pu):
			powerups.erase(pu)
			continue
		var center = pu.position + pu.size / 2
		if player.position.distance_to(center) < 30:
			var pu_type = pu.get_meta("powerup_type", "")
			_apply_powerup(pu_type)
			powerups.erase(pu)
			pu.queue_free()

func _apply_powerup(type: String) -> void:
	match type:
		"presidente":
			if hud:
				hud.show_delivery_message("¡PRESIDENTE! TURBO 10s", Color(0.0, 0.8, 1.0))
			player.speed_multiplier = 2.0
			player.is_invincible = true
			player.invincible_timer = 10.0
			player.flicker_time = 0.0
			await get_tree().create_timer(10.0).timeout
			if is_instance_valid(player):
				player.speed_multiplier = 1.0
				player.is_invincible = false
		"mangu":
			lives = min(lives + 1, 3)
			if player:
				player.lives = lives
			if hud:
				hud.update_lives(lives)
				hud.show_delivery_message("¡MANGÚ! +1 VIDA", Color(0.9, 0.5, 0.1))
		"cafe":
			if hud:
				hud.show_delivery_message("¡CAFÉ! FUEGO RÁPIDO 15s", Color(0.5, 0.3, 0.0))
			fire_cooldown_mult = 0.3
			await get_tree().create_timer(15.0).timeout
			fire_cooldown_mult = 1.0

# ─── Navigation arrow ─────────────────────────────────────────────────────────
func _update_arrow() -> void:
	if not hud:
		return
	if has_package and dropoff_marker and dropoff_active:
		var dir = dropoff_marker.global_position - player.global_position
		hud.update_arrow(dir.normalized())
	elif not has_package and pickup_marker and pickup_active:
		var dir = pickup_marker.global_position - player.global_position
		hud.update_arrow(dir.normalized())
	else:
		hud.update_arrow(Vector2.ZERO)

var colmado_sprite: Sprite2D = null

func _spawn_pickup() -> void:
	var vp = get_viewport_rect().size
	pickup_pos = Vector2(randf_range(60, vp.x - 60), randf_range(150, vp.y - 150))
	if pickup_marker:
		pickup_marker.global_position = pickup_pos - pickup_marker.size / 2
		pickup_marker.visible = true

	if colmado_sprite == null:
		colmado_sprite = Sprite2D.new()
		colmado_sprite.texture = load("res://assets/sprites/buildings/colmado.png")
		add_child(colmado_sprite)
	colmado_sprite.global_position = pickup_pos - Vector2(0, 70)
	colmado_sprite.visible = true
	pickup_active = true

func _spawn_dropoff() -> void:
	var vp = get_viewport_rect().size
	var attempts = 0
	dropoff_pos = Vector2(randf_range(60, vp.x - 60), randf_range(150, vp.y - 150))
	while dropoff_pos.distance_to(pickup_pos) < 150 and attempts < 10:
		dropoff_pos = Vector2(randf_range(60, vp.x - 60), randf_range(150, vp.y - 150))
		attempts += 1
	if dropoff_marker:
		dropoff_marker.global_position = dropoff_pos - dropoff_marker.size / 2
		dropoff_marker.visible = true
	dropoff_active = true

# ─── Input / Signal handlers ──────────────────────────────────────────────────
func _on_direction_changed(dir: Vector2) -> void:
	player_direction = dir
	if player and player.has_method("set_joystick_direction"):
		player.set_joystick_direction(dir)

func _on_joystick_moved(direction: Vector2) -> void:
	if player and player.has_method("set_joystick_direction"):
		player.set_joystick_direction(direction)

func _on_fire_pressed() -> void:
	if not player or game_over:
		return
	_fire_weapon()

func _on_weapon_selected(weapon_name: String) -> void:
	current_weapon = weapon_name
	if hud:
		hud.update_weapon(current_weapon, weapon_ammo.get(current_weapon, 0))

func _on_package_dropped() -> void:
	has_package = false
	streak = 0

func _fire_weapon() -> void:
	var ammo = weapon_ammo.get(current_weapon, 0)
	if ammo <= 0:
		if hud:
			hud.show_message("¡SIN MUNICION!", 1.0)
		return

	weapon_ammo[current_weapon] = ammo - 1

	var fire_dir = Vector2.UP
	if enemies.size() > 0:
		var nearest = _get_nearest_enemy()
		if nearest:
			fire_dir = (nearest.global_position - player.global_position).normalized()

	var w = _create_weapon_node(current_weapon, fire_dir)
	weapon_container.add_child(w)
	active_weapons.append(w)

	if hud:
		hud.update_weapon(current_weapon, weapon_ammo.get(current_weapon, 0))

func _get_nearest_enemy() -> Node:
	var nearest = null
	var min_dist = 9999.0
	for e in enemies:
		if not is_instance_valid(e) or not e.active:
			continue
		var d = player.global_position.distance_to(e.global_position)
		if d < min_dist:
			min_dist = d
			nearest = e
	return nearest

func _create_weapon_node(weapon_name: String, direction: Vector2) -> Area2D:
	var w = Area2D.new()
	w.set_script(WeaponScript)

	var body = ColorRect.new()
	body.name = "BodyRect"
	body.size = Vector2(14, 14)
	body.position = Vector2(-7, -7)
	w.add_child(body)

	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 8.0
	col.shape = shape
	w.add_child(col)

	w.global_position = player.global_position
	w.add_to_group("weapons")
	w.collision_layer = 4
	w.collision_mask = 2

	var wtype_map = {
		"platano": Weapon.WeaponType.PLATANO,
		"huevo": Weapon.WeaponType.HUEVO,
		"salami": Weapon.WeaponType.SALAMI,
		"fart": Weapon.WeaponType.FART,
	}
	var wtype = wtype_map.get(weapon_name, Weapon.WeaponType.PLATANO)
	w.setup(wtype, direction)
	w.connect("weapon_expired", func(): active_weapons.erase(w))
	return w

# ─── Game state transitions ───────────────────────────────────────────────────
func _on_player_hit() -> void:
	has_package = false
	streak = 0
	if hud:
		hud.update_lives(lives)

func _on_player_died() -> void:
	game_over = true
	_show_game_over(false)

func _mission_failed() -> void:
	game_over = true
	_show_game_over(false)

func _mission_complete() -> void:
	game_over = true
	GameState.save()
	_show_game_over(true)

func _show_game_over(won: bool) -> void:
	if game_over_panel:
		game_over_panel.visible = true
		var lbl = game_over_panel.get_node_or_null("ResultLabel")
		if lbl:
			if won:
				lbl.text = "¡MISIÓN COMPLETADA!\n+$%d" % (deliveries_done * mission_reward_per_delivery)
				lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
			else:
				lbl.text = "GAME OVER\nEntregas: %d/%d" % [deliveries_done, deliveries_required]
				lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))

func _on_retry_button_pressed() -> void:
	GameState.reset_run()
	get_tree().change_scene_to_file("res://scenes/GameScene.tscn")

func _on_menu_button_pressed() -> void:
	GameState.save()
	get_tree().change_scene_to_file("res://scenes/MenuScene.tscn")
