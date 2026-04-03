extends Node2D
## GameScene.gd - Main gameplay scene.
## Top-down courier arcade with PS1 aesthetic.

# ─── Constants ───────────────────────────────────────────────────────────────
const SCROLL_SPEED = 150.0
const ENEMY_SPAWN_INTERVAL = 4.0
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

var pickup_active: bool = false
var dropoff_active: bool = false
var has_package: bool = false
var pickup_pos: Vector2 = Vector2.ZERO
var dropoff_pos: Vector2 = Vector2.ZERO
var streak: int = 0

var enemies: Array = []
var active_weapons: Array = []
var spawn_timer: float = 0.0
var game_over: bool = false
var paused_game: bool = false

# Scrolling world
var road_marks: Array = []
var buildings_left: Array = []
var buildings_right: Array = []

# ─── Node references ──────────────────────────────────────────────────────────
@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var world: Node2D = $World
@onready var pickup_marker: ColorRect = $Markers/PickupMarker
@onready var dropoff_marker: ColorRect = $Markers/DropoffMarker
@onready var scanline_overlay: ColorRect = $ScanlineOverlay
@onready var game_over_panel: Control = $GameOverPanel
@onready var enemy_container: Node2D = $EnemyContainer
@onready var weapon_container: Node2D = $WeaponContainer

# Weapon scene scripts (instantiated procedurally)
const WeaponScript = preload("res://scripts/Weapon.gd")
const EnemyScript = preload("res://scripts/Enemy.gd")

# ─── Setup ────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_load_mission()
	_setup_world()
	_setup_hud()
	_spawn_pickup()
	_connect_player()
	if hud:
		hud.connect("joystick_moved", _on_joystick_moved)
		hud.connect("fire_pressed", _on_fire_pressed)
		hud.connect("weapon_selected", _on_weapon_selected)

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

	# Road center strip - road marks
	for i in ROAD_MARK_COUNT:
		var mark = ColorRect.new()
		mark.size = Vector2(8, 40)
		mark.color = Color(1.0, 0.9, 0.1)
		mark.position = Vector2(vp.x / 2 - 4, i * 110 - 20)
		world.add_child(mark)
		road_marks.append(mark)

	# Buildings left
	for i in BUILDING_COUNT:
		var b = _create_building(true, i)
		world.add_child(b)
		buildings_left.append(b)

	# Buildings right
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

	# Front face
	var front = ColorRect.new()
	front.size = Vector2(bw, bh)
	front.color = bcolor
	front.position = Vector2(bx, by)
	container.add_child(front)

	# Top face (isometric look)
	var top = ColorRect.new()
	top.size = Vector2(bw, 14)
	top.color = bcolor.lightened(0.25)
	top.position = Vector2(bx, by - 14)
	container.add_child(top)

	# Windows
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

# ─── Main loop ────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if game_over or paused_game:
		return

	_scroll_world(delta)
	_update_timer(delta)
	_check_deliveries()
	_spawn_enemies(delta)
	_check_enemy_player_collision()
	_update_arrow()

	# PS1 wobble on buildings
	_wobble_buildings(delta)

func _scroll_world(delta: float) -> void:
	if not world:
		return

	# Scroll road marks
	for mark in road_marks:
		mark.position.y += SCROLL_SPEED * delta
		if mark.position.y > get_viewport_rect().size.y + 20:
			mark.position.y -= (get_viewport_rect().size.y + 60)

	# Scroll buildings
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

	# Pickup check
	if not has_package and pickup_active and pickup_marker:
		if player.global_position.distance_to(pickup_marker.global_position + pickup_marker.size/2) < 40:
			has_package = true
			pickup_active = false
			pickup_marker.visible = false
			player.has_package = true
			if hud:
				hud.show_delivery_message("¡COGISTE EL PAQUETE!", Color(0.2, 1.0, 0.4))
			_spawn_dropoff()

	# Dropoff check
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

func _spawn_enemies(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_timer = ENEMY_SPAWN_INTERVAL
		_spawn_enemy()

func _spawn_enemy() -> void:
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
	return e

func _check_enemy_player_collision() -> void:
	if not player or player.invincible:
		return
	for e in enemies:
		if not is_instance_valid(e) or not e.active:
			continue
		if player.global_position.distance_to(e.global_position) < 28:
			lives -= 1
			streak = 0
			player.take_hit()
			if hud:
				hud.update_lives(lives)
				hud.show_delivery_message("¡AY! -1 VIDA", Color(1, 0.2, 0.1))
			if lives <= 0:
				player.die()
			break

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

func _spawn_pickup() -> void:
	var vp = get_viewport_rect().size
	pickup_pos = Vector2(randf_range(60, vp.x - 60), randf_range(150, vp.y - 150))
	if pickup_marker:
		pickup_marker.global_position = pickup_pos - pickup_marker.size / 2
		pickup_marker.visible = true
	pickup_active = true

func _spawn_dropoff() -> void:
	var vp = get_viewport_rect().size
	# Make sure dropoff is far from pickup
	var attempts = 0
	dropoff_pos = Vector2(randf_range(60, vp.x - 60), randf_range(150, vp.y - 150))
	while dropoff_pos.distance_to(pickup_pos) < 150 and attempts < 10:
		dropoff_pos = Vector2(randf_range(60, vp.x - 60), randf_range(150, vp.y - 150))
		attempts += 1
	if dropoff_marker:
		dropoff_marker.global_position = dropoff_pos - dropoff_marker.size / 2
		dropoff_marker.visible = true
	dropoff_active = true

# ─── Input ────────────────────────────────────────────────────────────────────
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

func _fire_weapon() -> void:
	var ammo = weapon_ammo.get(current_weapon, 0)
	if ammo <= 0:
		if hud:
			hud.show_message("¡SIN MUNICION!", 1.0)
		return

	weapon_ammo[current_weapon] = ammo - 1

	# Determine fire direction (toward nearest enemy or up)
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
