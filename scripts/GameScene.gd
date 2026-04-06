extends Node2D
## COLMADO DASH - Road Rash / Temple Run style behind-moped runner
## All game rendering is done in _draw() with perspective projection.
## No external sprite files required — everything drawn in code.

# ─── Screen constants ────────────────────────────────────────────────────────
const SCREEN_W := 390.0
const SCREEN_H := 844.0
const HORIZON_Y := 280.0
const PLAYER_SCREEN_X := 195.0
const PLAYER_SCREEN_Y := 750.0
const LANE_MOVE_SPEED := 6.0

# ─── Perspective math ────────────────────────────────────────────────────────
func world_to_screen(world_x: float, world_z: float) -> Vector2:
	var z = max(world_z, 0.01)
	var perspective = 1.0 / (z + 0.1)
	var screen_x = 195.0 + world_x * perspective * 400.0
	# Far (large z) → near horizon (y=280); close (small z) → near bottom (y=844)
	var screen_y = HORIZON_Y + (SCREEN_H - HORIZON_Y) / (z + 1.0)
	return Vector2(screen_x, screen_y)

func world_to_size(world_z: float, base_size: float) -> float:
	return clamp(base_size / (world_z * 0.4 + 0.1), 2.0, base_size * 5.0)

# ─── Game classes ────────────────────────────────────────────────────────────
class RoadObject:
	var world_x: float = 0.0
	var world_z: float = 6.0
	var type: String = "moped"  # "moped", "car", "person", "powerup"
	var speed: float = 1.5
	var active: bool = true
	var color: Color = Color(0.8, 0.1, 0.1)
	var label: String = ""

class Building:
	var world_x: float = -1.5  # side position
	var world_z: float = 8.0
	var color: Color = Color(0.85, 0.35, 0.1)
	var name_text: String = "COLMADO LA 17"
	var height_norm: float = 1.0  # relative height (1=normal)
	var has_flag: bool = false
	var awning_color: Color = Color.RED

class PalmTree:
	var world_x: float = -1.8
	var world_z: float = 8.0
	var side: int = -1

class Platano:
	var progress: float = 0.0  # 0→1 arc flight
	var from_pos: Vector2 = Vector2.ZERO
	var to_x: float = 0.0  # target world_x
	var to_z: float = 1.0  # target world_z
	var active: bool = true
	var hit_enemy_idx: int = -1

# ─── State ────────────────────────────────────────────────────────────────────
var money: int = 350
var health: int = 3
var score: int = 0
var combo: int = 0
var game_over: bool = false
var game_paused: bool = false
var get_ready: bool = true

var speed: float = 2.0           # world units / second (road speed)
var road_scroll: float = 0.0     # for dash animation
var road_curve: float = 0.0      # road curves left/right

# Player
var player_lane: float = 0.0     # current lateral position (-1 to +1)
var player_target_lane: float = 0.0
var player_lean: float = 0.0
var player_invincible: float = 0.0

# Lane options: snap to -0.5, 0, +0.5 world units
const LANES := [-0.5, 0.0, 0.5]
var current_lane_idx: int = 1

# Objects in the world
var road_objects: Array = []
var buildings: Array = []
var palm_trees: Array = []
var platanos: Array = []

# Spawn timers
var enemy_spawn_timer: float = 0.0
var enemy_spawn_interval: float = 2.5
var building_next_z: float = 2.0  # z where to spawn next building
var palm_next_z: float = 1.5

# Scoring & mission
var mission_time: float = 90.0
var deliveries_done: int = 0
var deliveries_required: int = 3

# HUD reference
@onready var hud: CanvasLayer = $HUD

# Touch input
var touch_start: Vector2 = Vector2.ZERO
var touch_id: int = -1
var fire_touch_id: int = -1

# Pickup system
var has_package: bool = false
var pickup_text: String = "COLMADO EL FAVORITO"
var show_pickup_banner: bool = true
var pickup_banner_timer: float = 4.0

# Weapon system
var current_weapon: String = "platano"
var weapon_ammo: Dictionary = {
	"platano": 99,
	"huevo": 5,
}
var fire_cooldown: float = 0.0

# ─── Setup ────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_load_from_game_state()
	_connect_hud()
	_spawn_initial_world()
	_play_get_ready()
	set_process_input(true)

func _load_from_game_state() -> void:
	if not Engine.has_singleton("GameState"):
		return
	money = GameState.money
	weapon_ammo = GameState.weapon_ammo.duplicate() if GameState.weapon_ammo else weapon_ammo
	health = GameState.lives if GameState.lives > 0 else 3

func _connect_hud() -> void:
	if not hud:
		return
	if hud.has_signal("fire_pressed") and not hud.fire_pressed.is_connected(_on_fire_pressed):
		hud.fire_pressed.connect(_on_fire_pressed)
	if hud.has_signal("direction_changed") and not hud.direction_changed.is_connected(_on_direction_changed):
		hud.direction_changed.connect(_on_direction_changed)
	if hud.has_signal("swipe_left") and not hud.swipe_left.is_connected(_on_swipe_left):
		hud.swipe_left.connect(_on_swipe_left)
	if hud.has_signal("swipe_right") and not hud.swipe_right.is_connected(_on_swipe_right):
		hud.swipe_right.connect(_on_swipe_right)

func _spawn_initial_world() -> void:
	# Pre-spawn some buildings and trees so the world isn't empty
	var building_configs = [
		["COLMADO LA 17", Color(0.9, 0.3, 0.05), Color(0.8, 0.1, 0.1), false],
		["COLMADO LA 24", Color(0.1, 0.4, 0.8), Color(1.0, 0.8, 0.0), false],
		["VARIEDADES EL REY", Color(0.2, 0.6, 0.2), Color(0.9, 0.5, 0.1), false],
		["FRIO-FRIO MARI", Color(0.85, 0.15, 0.5), Color(0.2, 0.6, 0.9), false],
		["COLMADO DON PEDRO", Color(1.0, 0.55, 0.0), Color(0.5, 0.1, 0.8), true],
		["LOTERIA NATIONAL", Color(0.15, 0.2, 0.7), Color(0.9, 0.8, 0.0), false],
		["FARMACIA BELLA", Color(0.0, 0.6, 0.4), Color(0.8, 0.0, 0.1), false],
		["BANCA DIGITAL", Color(0.7, 0.1, 0.1), Color(0.3, 0.8, 1.0), true],
	]

	for i in range(8):
		var cfg = building_configs[i % building_configs.size()]
		# Left side building
		var bl = Building.new()
		bl.world_x = -1.6
		bl.world_z = 1.5 + i * 1.8
		bl.name_text = cfg[0]
		bl.color = cfg[1]
		bl.awning_color = cfg[2]
		bl.has_flag = cfg[3]
		bl.height_norm = randf_range(0.8, 1.6)
		buildings.append(bl)

		# Right side building
		var br = Building.new()
		br.world_x = 1.6
		br.world_z = 1.5 + i * 1.8 + 0.4
		br.name_text = building_configs[(i + 3) % building_configs.size()][0]
		br.color = building_configs[(i + 3) % building_configs.size()][1]
		br.awning_color = building_configs[(i + 3) % building_configs.size()][2]
		br.has_flag = i % 4 == 0
		br.height_norm = randf_range(0.8, 1.6)
		buildings.append(br)

		# Palm trees
		var pt = PalmTree.new()
		pt.world_x = -1.2 - randf_range(0.0, 0.3)
		pt.world_z = 1.0 + i * 1.6
		pt.side = -1
		palm_trees.append(pt)

		var pt2 = PalmTree.new()
		pt2.world_x = 1.2 + randf_range(0.0, 0.3)
		pt2.world_z = 1.2 + i * 1.6
		pt2.side = 1
		palm_trees.append(pt2)

	building_next_z = 15.0

func _play_get_ready() -> void:
	get_ready = true
	await get_tree().create_timer(1.8).timeout
	get_ready = false

# ─── Main loop ────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if game_over or game_paused:
		return
	if get_ready:
		queue_redraw()
		return

	_update_player(delta)
	_update_world(delta)
	_update_enemies(delta)
	_update_platanos(delta)
	_update_spawning(delta)
	_update_game_state(delta)

	queue_redraw()

# ─── Player movement ──────────────────────────────────────────────────────────
func _update_player(delta: float) -> void:
	# Smooth lane transition
	player_lane = lerp(player_lane, player_target_lane, LANE_MOVE_SPEED * delta)
	player_lean = lerp(player_lean, (player_target_lane - player_lane) * 0.5, 8.0 * delta)

	if player_invincible > 0:
		player_invincible -= delta

	fire_cooldown -= delta

func _on_swipe_left() -> void:
	if current_lane_idx > 0:
		current_lane_idx -= 1
		player_target_lane = LANES[current_lane_idx]

func _on_swipe_right() -> void:
	if current_lane_idx < LANES.size() - 1:
		current_lane_idx += 1
		player_target_lane = LANES[current_lane_idx]

func _on_direction_changed(dir: Vector2) -> void:
	if dir.x < -0.3 and player_target_lane > -0.5:
		_on_swipe_left()
	elif dir.x > 0.3 and player_target_lane < 0.5:
		_on_swipe_right()

# ─── World update ─────────────────────────────────────────────────────────────
func _update_world(delta: float) -> void:
	road_scroll += speed * delta * 2.0
	if road_scroll > 1.0:
		road_scroll -= 1.0

	# Move buildings toward player (decrease z)
	for b in buildings:
		b.world_z -= speed * delta
	for pt in palm_trees:
		pt.world_z -= speed * delta

	# Remove passed objects
	buildings = buildings.filter(func(b): return b.world_z > -0.5)
	palm_trees = palm_trees.filter(func(pt): return pt.world_z > -0.5)

# ─── Enemy update ─────────────────────────────────────────────────────────────
func _update_enemies(delta: float) -> void:
	for obj in road_objects:
		if not obj.active:
			continue
		obj.world_z -= (speed + obj.speed) * delta

	# Collision detection: if enemy reaches player (z < 0.25) and same lane
	for obj in road_objects:
		if not obj.active:
			continue
		if obj.world_z < 0.25 and obj.world_z > -0.3:
			if abs(obj.world_x - player_target_lane) < 0.35:
				if player_invincible <= 0:
					_hit_player()
					obj.active = false

	# Remove passed/dead objects
	road_objects = road_objects.filter(func(o): return o.active and o.world_z > -1.0)

# ─── Platano weapons ──────────────────────────────────────────────────────────
func _update_platanos(delta: float) -> void:
	for p in platanos:
		if not p.active:
			continue
		p.progress += delta * 1.8  # arc speed

		# Check hit: find closest enemy at ~target z/x
		for i in range(road_objects.size()):
			var obj = road_objects[i]
			if not obj.active:
				continue
			var target_pos = world_to_screen(p.to_x, p.to_z)
			var obj_pos = world_to_screen(obj.world_x, obj.world_z)
			if target_pos.distance_to(obj_pos) < 30 and p.progress > 0.3 and p.progress < 0.9:
				_hit_enemy(i)
				p.active = false

		if p.progress >= 1.0:
			p.active = false

	platanos = platanos.filter(func(p): return p.active)

func _hit_player() -> void:
	health -= 1
	player_invincible = 2.5
	combo = 0
	if hud:
		hud.update_health(health)
		hud.show_message("¡AY!", Color(1, 0.2, 0.1))
	if health <= 0:
		_game_over(false)

func _hit_enemy(idx: int) -> void:
	if idx >= road_objects.size():
		return
	road_objects[idx].active = false
	combo += 1
	var earned = 10 * combo
	money += earned
	score += earned
	if hud:
		hud.update_money(money)
		hud.show_message(["¡DALE!", "POW!", "BAM!", "¡COGE ESO!"][randi() % 4] + " +$%d" % earned, Color(1, 1, 0))

# ─── Spawning ─────────────────────────────────────────────────────────────────
func _update_spawning(delta: float) -> void:
	# Spawn enemies
	enemy_spawn_timer += delta
	if enemy_spawn_timer >= enemy_spawn_interval:
		enemy_spawn_timer = 0.0
		enemy_spawn_interval = max(1.2, enemy_spawn_interval - 0.05)
		_spawn_enemy()

	# Spawn buildings
	_maybe_spawn_building()
	_maybe_spawn_palms()

func _spawn_enemy() -> void:
	if road_objects.size() >= 10:
		return

	var type_roll = randf()
	var obj = RoadObject.new()

	if type_roll < 0.5:
		obj.type = "moped"
		obj.color = [Color(0.8, 0.1, 0.1), Color(0.1, 0.3, 0.9), Color(0.1, 0.7, 0.2)][randi() % 3]
		obj.speed = randf_range(0.5, 1.5)
		obj.label = "MOTO"
	elif type_roll < 0.8:
		obj.type = "car"
		obj.color = [Color(0.3, 0.3, 0.35), Color(0.8, 0.6, 0.0), Color(0.1, 0.1, 0.8)][randi() % 3]
		obj.speed = randf_range(0.3, 0.9)
		obj.label = "CARRO"
	else:
		obj.type = "person"
		obj.color = Color(0.85, 0.65, 0.45)
		obj.speed = randf_range(0.1, 0.4)
		obj.label = ""

	# Pick a lane
	var lane_choices = [-0.5, 0.0, 0.5]
	obj.world_x = lane_choices[randi() % 3]
	obj.world_z = 7.0 + randf_range(0.0, 2.0)

	road_objects.append(obj)

	# Occasionally spawn a powerup platano bunch
	if randf() < 0.15:
		var pu = RoadObject.new()
		pu.type = "powerup"
		pu.color = Color(1.0, 0.9, 0.1)
		pu.world_x = lane_choices[randi() % 3]
		pu.world_z = 5.0 + randf_range(0.0, 1.0)
		pu.speed = 0.0
		road_objects.append(pu)

func _maybe_spawn_building() -> void:
	# Check if we need to spawn buildings farther away
	var max_z = 0.0
	for b in buildings:
		if b.world_z > max_z:
			max_z = b.world_z

	if max_z < building_next_z:
		return

	var building_configs = [
		["COLMADO LA 17", Color(0.9, 0.3, 0.05), Color(0.8, 0.1, 0.1), false],
		["COLMADO LA 24", Color(0.1, 0.4, 0.8), Color(1.0, 0.8, 0.0), false],
		["COLMADO EL FAVORITO", Color(0.2, 0.6, 0.2), Color(0.9, 0.5, 0.1), true],
		["FRIO-FRIO MARY", Color(0.85, 0.15, 0.5), Color(0.2, 0.6, 0.9), false],
		["COLMADO DON PEDRO", Color(1.0, 0.55, 0.0), Color(0.5, 0.1, 0.8), true],
		["LOTERIA NACIONAL", Color(0.15, 0.2, 0.7), Color(0.9, 0.8, 0.0), false],
		["FARMACIA BELLA", Color(0.0, 0.6, 0.4), Color(0.8, 0.0, 0.1), false],
		["BANCA DIGITAL", Color(0.7, 0.1, 0.1), Color(0.3, 0.8, 1.0), false],
		["CHIMICHURRI 24H", Color(0.85, 0.45, 0.0), Color(0.1, 0.6, 0.2), false],
	]

	var cfg_l = building_configs[randi() % building_configs.size()]
	var cfg_r = building_configs[randi() % building_configs.size()]
	var new_z = max_z + 3.5

	var bl = Building.new()
	bl.world_x = -1.6
	bl.world_z = new_z
	bl.name_text = cfg_l[0]
	bl.color = cfg_l[1]
	bl.awning_color = cfg_l[2]
	bl.has_flag = cfg_l[3]
	bl.height_norm = randf_range(0.8, 1.8)
	buildings.append(bl)

	var br = Building.new()
	br.world_x = 1.6
	br.world_z = new_z + 0.5
	br.name_text = cfg_r[0]
	br.color = cfg_r[1]
	br.awning_color = cfg_r[2]
	br.has_flag = cfg_r[3]
	br.height_norm = randf_range(0.8, 1.8)
	buildings.append(br)

func _maybe_spawn_palms() -> void:
	var max_z = 0.0
	for pt in palm_trees:
		if pt.world_z > max_z:
			max_z = pt.world_z
	if max_z < 10.0:
		var new_z = max_z + 2.5
		var pt_l = PalmTree.new()
		pt_l.world_x = -1.1 - randf_range(0.0, 0.2)
		pt_l.world_z = new_z
		pt_l.side = -1
		palm_trees.append(pt_l)
		var pt_r = PalmTree.new()
		pt_r.world_x = 1.1 + randf_range(0.0, 0.2)
		pt_r.world_z = new_z + 0.3
		pt_r.side = 1
		palm_trees.append(pt_r)

# ─── Game state ────────────────────────────────────────────────────────────────
func _update_game_state(_delta: float) -> void:
	mission_time -= _delta
	if hud:
		hud.update_timer(mission_time)

	if mission_time <= 0:
		_game_over(deliveries_done >= deliveries_required)

	# Check powerup collection
	for i in range(road_objects.size() - 1, -1, -1):
		var obj = road_objects[i]
		if not obj.active or obj.type != "powerup":
			continue
		if obj.world_z < 0.3 and abs(obj.world_x - player_target_lane) < 0.4:
			road_objects[i].active = false
			money += 25
			score += 25
			if hud:
				hud.update_money(money)
				hud.show_message("🍌 +$25", Color(1, 0.9, 0))

func _game_over(won: bool) -> void:
	game_over = true
	if hud:
		hud.show_game_over(won, score, money)

# ─── Fire weapon ──────────────────────────────────────────────────────────────
func _on_fire_pressed() -> void:
	if game_over or get_ready or fire_cooldown > 0:
		return
	fire_cooldown = 0.4

	# Find nearest enemy to target
	var target_x = player_target_lane
	var target_z = 3.0
	var min_dist = 999.0

	for obj in road_objects:
		if not obj.active or obj.type == "powerup":
			continue
		var dist = abs(obj.world_x - player_target_lane) + obj.world_z * 0.3
		if dist < min_dist:
			min_dist = dist
			target_x = obj.world_x
			target_z = obj.world_z

	var p = Platano.new()
	p.from_pos = Vector2(PLAYER_SCREEN_X + player_lane * 80, PLAYER_SCREEN_Y - 40)
	p.to_x = target_x
	p.to_z = target_z
	platanos.append(p)

# ─── Input handling ────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if game_over or get_ready:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			var vp_size = get_viewport_rect().size
			# Right half top zone: fire
			if event.position.x > vp_size.x * 0.6 and event.position.y < vp_size.y * 0.75:
				if fire_touch_id == -1:
					fire_touch_id = event.index
					_on_fire_pressed()
			# Left swipe zone
			elif event.position.x < vp_size.x * 0.5:
				touch_start = event.position
				touch_id = event.index
		else:
			if event.index == fire_touch_id:
				fire_touch_id = -1
			if event.index == touch_id:
				var dx = event.position.x - touch_start.x
				if abs(dx) > 25:
					if dx < 0:
						_on_swipe_left()
					else:
						_on_swipe_right()
				touch_id = -1

	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT, KEY_A:
				_on_swipe_left()
			KEY_RIGHT, KEY_D:
				_on_swipe_right()
			KEY_SPACE, KEY_Z:
				_on_fire_pressed()

# ─── Custom rendering ─────────────────────────────────────────────────────────
func _draw() -> void:
	_draw_sky()
	_draw_road()
	_draw_world_objects()
	_draw_player()
	_draw_platanos()
	if get_ready:
		_draw_get_ready()
	if player_invincible > 0 and fmod(Time.get_ticks_msec() / 100.0, 2) < 1:
		pass  # flicker effect handled in player draw

# ─── Draw sky / background ────────────────────────────────────────────────────
func _draw_sky() -> void:
	# Caribbean sky gradient (drawn as rectangles)
	draw_rect(Rect2(0, 0, SCREEN_W, HORIZON_Y), Color(0.3, 0.65, 1.0))
	# Horizon haze
	draw_rect(Rect2(0, HORIZON_Y - 30, SCREEN_W, 30), Color(0.6, 0.85, 1.0, 0.6))
	# Small sun
	draw_circle(Vector2(310, 80), 28, Color(1.0, 0.92, 0.3))
	draw_circle(Vector2(310, 80), 22, Color(1.0, 0.98, 0.7))
	# Clouds
	_draw_cloud(Vector2(60, 60), 0.9)
	_draw_cloud(Vector2(200, 45), 0.7)
	_draw_cloud(Vector2(280, 90), 0.5)

func _draw_cloud(pos: Vector2, size: float) -> void:
	var c = Color(1.0, 1.0, 1.0, 0.85)
	draw_circle(pos, 18 * size, c)
	draw_circle(pos + Vector2(16 * size, -6 * size), 14 * size, c)
	draw_circle(pos + Vector2(-14 * size, -4 * size), 12 * size, c)
	draw_circle(pos + Vector2(30 * size, 2 * size), 11 * size, c)

# ─── Draw road ────────────────────────────────────────────────────────────────
func _draw_road() -> void:
	# Sidewalk left
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, SCREEN_H), Vector2(55, SCREEN_H),
		Vector2(100, HORIZON_Y), Vector2(0, HORIZON_Y)
	]), Color(0.72, 0.67, 0.58))

	# Sidewalk right
	draw_colored_polygon(PackedVector2Array([
		Vector2(335, SCREEN_H), Vector2(SCREEN_W, SCREEN_H),
		Vector2(SCREEN_W, HORIZON_Y), Vector2(290, HORIZON_Y)
	]), Color(0.72, 0.67, 0.58))

	# Road surface
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, SCREEN_H), Vector2(SCREEN_W, SCREEN_H),
		Vector2(290, HORIZON_Y), Vector2(100, HORIZON_Y)
	]), Color(0.42, 0.42, 0.42))

	# Road center — yellow dashes with perspective scroll
	var scroll_offset = fmod(road_scroll, 0.5)
	for i in range(14):
		var z_val = 0.3 + float(i) * 0.55 - scroll_offset * 0.55
		if z_val <= 0:
			continue
		if int(i) % 2 == 0:
			var p1 = world_to_screen(0.0, z_val)
			var p2 = world_to_screen(0.0, z_val + 0.3)
			var thickness = clamp(4.0 / (z_val * 0.5 + 0.3), 1.0, 7.0)
			draw_line(p1, p2, Color(1.0, 0.88, 0.1), thickness)

	# Lane dividers (subtle white dashes)
	for lane_x in [-0.28, 0.28]:
		for i in range(14):
			var z_val = 0.3 + float(i) * 0.55 - scroll_offset * 0.55
			if z_val <= 0:
				continue
			if int(i) % 2 == 0:
				var p1 = world_to_screen(lane_x, z_val)
				var p2 = world_to_screen(lane_x, z_val + 0.25)
				var thickness = clamp(2.0 / (z_val * 0.5 + 0.3), 0.5, 3.5)
				draw_line(p1, p2, Color(1, 1, 1, 0.3), thickness)

	# Horizon line
	draw_line(Vector2(0, HORIZON_Y), Vector2(SCREEN_W, HORIZON_Y), Color(0.55, 0.8, 1.0), 2)

# ─── Draw world objects (sorted back-to-front) ───────────────────────────────
func _draw_world_objects() -> void:
	# Collect all world objects with their z for depth sorting
	var draw_queue: Array = []

	for b in buildings:
		if b.world_z > 0 and b.world_z < 12:
			draw_queue.append({"type": "building", "z": b.world_z, "obj": b})

	for pt in palm_trees:
		if pt.world_z > 0 and pt.world_z < 12:
			draw_queue.append({"type": "palm", "z": pt.world_z, "obj": pt})

	for obj in road_objects:
		if obj.active and obj.world_z > 0.1 and obj.world_z < 12:
			draw_queue.append({"type": "road_obj", "z": obj.world_z, "obj": obj})

	# Sort back to front (largest z first)
	draw_queue.sort_custom(func(a, b_item): return a["z"] > b_item["z"])

	for item in draw_queue:
		match item["type"]:
			"building":
				_draw_building(item["obj"])
			"palm":
				_draw_palm_tree(item["obj"])
			"road_obj":
				_draw_road_object(item["obj"])

# ─── Draw a colmado building ──────────────────────────────────────────────────
func _draw_building(b: Building) -> void:
	var pos = world_to_screen(b.world_x, b.world_z)
	var scale = world_to_size(b.world_z, 1.0)
	var base_w = 60.0 * scale
	var base_h = 90.0 * scale * b.height_norm

	# Anchor: building base touches sidewalk-level y
	var by = pos.y
	var bx = pos.x

	# Perspective: left-side buildings lean inward
	if b.world_x < 0:
		bx = pos.x - base_w * 0.2  # offset slightly to show side wall

	# Wall
	draw_rect(Rect2(bx - base_w * 0.5, by - base_h, base_w, base_h), b.color)

	# Side wall (for 3D effect)
	var side_w = base_w * 0.2
	if b.world_x < 0:
		draw_colored_polygon(PackedVector2Array([
			Vector2(bx + base_w * 0.5, by - base_h),
			Vector2(bx + base_w * 0.5 + side_w, by - base_h * 0.85),
			Vector2(bx + base_w * 0.5 + side_w, by),
			Vector2(bx + base_w * 0.5, by),
		]), b.color.darkened(0.25))
	else:
		draw_colored_polygon(PackedVector2Array([
			Vector2(bx - base_w * 0.5, by - base_h),
			Vector2(bx - base_w * 0.5 - side_w, by - base_h * 0.85),
			Vector2(bx - base_w * 0.5 - side_w, by),
			Vector2(bx - base_w * 0.5, by),
		]), b.color.darkened(0.25))

	# Roof
	draw_rect(Rect2(bx - base_w * 0.5, by - base_h - scale * 6, base_w, scale * 6),
			  b.color.lightened(0.3))

	# Awning (striped)
	var awn_y = by - base_h * 0.65
	var awn_h = scale * 8
	for strip_i in range(4):
		var c = b.awning_color if strip_i % 2 == 0 else Color.WHITE
		draw_rect(Rect2(bx - base_w * 0.5 + strip_i * base_w / 4, awn_y, base_w / 4, awn_h), c)
	# Awning bottom edge shadow
	draw_rect(Rect2(bx - base_w * 0.5, awn_y + awn_h, base_w, scale * 2), Color(0, 0, 0, 0.3))

	# Windows (iron bars style)
	var win_size = scale * 7
	var win_spacing = base_w / 3
	for wx in range(2):
		for wy in range(2):
			var wpos = Vector2(bx - base_w * 0.3 + wx * win_spacing,
							   by - base_h * 0.85 + wy * (win_size + scale * 5))
			draw_rect(Rect2(wpos, Vector2(win_size, win_size)), Color(0.15, 0.15, 0.35))
			# Iron bars
			draw_line(Vector2(wpos.x, wpos.y), Vector2(wpos.x, wpos.y + win_size),
					  Color(0.5, 0.5, 0.6), max(0.5, scale * 0.8))
			draw_line(Vector2(wpos.x + win_size * 0.5, wpos.y),
					  Vector2(wpos.x + win_size * 0.5, wpos.y + win_size),
					  Color(0.5, 0.5, 0.6), max(0.5, scale * 0.8))

	# COLMADO sign
	if scale > 0.15:
		var sign_y = by - base_h * 0.45
		var sign_h = scale * 10
		draw_rect(Rect2(bx - base_w * 0.5, sign_y, base_w, sign_h), Color(0.1, 0.1, 0.1, 0.85))
		# We can't draw text in _draw() easily, so draw a colored sign indicator
		draw_rect(Rect2(bx - base_w * 0.5 + scale, sign_y + scale, base_w - scale * 2, sign_h - scale * 2),
				  Color(1.0, 0.88, 0.1, 0.9))

	# DR Flag (blue/red/white cross)
	if b.has_flag and scale > 0.2:
		var fx = bx + base_w * 0.35
		var fy = by - base_h - scale * 12
		var fw = scale * 10
		var fh = scale * 7
		# Flag pole
		draw_line(Vector2(fx, fy + fh), Vector2(fx, fy - scale * 3), Color(0.6, 0.5, 0.3), 1.5)
		# Quadrants
		draw_rect(Rect2(fx, fy, fw * 0.5, fh * 0.5), Color(0.0, 0.2, 0.8))
		draw_rect(Rect2(fx + fw * 0.5, fy, fw * 0.5, fh * 0.5), Color(0.8, 0.05, 0.05))
		draw_rect(Rect2(fx, fy + fh * 0.5, fw * 0.5, fh * 0.5), Color(0.8, 0.05, 0.05))
		draw_rect(Rect2(fx + fw * 0.5, fy + fh * 0.5, fw * 0.5, fh * 0.5), Color(0.0, 0.2, 0.8))
		# White cross
		draw_rect(Rect2(fx + fw * 0.4, fy, fw * 0.2, fh), Color(1, 1, 1))
		draw_rect(Rect2(fx, fy + fh * 0.4, fw, fh * 0.2), Color(1, 1, 1))

	# Person sitting outside (pixel art person)
	if scale > 0.3:
		var px = bx - base_w * 0.1
		var py = by - scale * 2
		draw_circle(Vector2(px, py - scale * 6), scale * 3, Color(0.85, 0.65, 0.45))  # head
		draw_rect(Rect2(px - scale * 3, py - scale * 5, scale * 6, scale * 5),
				  [Color(0.8, 0.1, 0.1), Color(0.1, 0.3, 0.8), Color(0.1, 0.6, 0.2)][randi() % 3])

# ─── Draw palm tree ────────────────────────────────────────────────────────────
func _draw_palm_tree(pt: PalmTree) -> void:
	var pos = world_to_screen(pt.world_x, pt.world_z)
	var scale = world_to_size(pt.world_z, 1.0)
	var trunk_h = 55.0 * scale
	var trunk_w = 4.0 * scale

	# Trunk (slightly curved)
	var lean = 8.0 * scale * pt.side
	draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x - trunk_w * 0.5, pos.y),
		Vector2(pos.x + trunk_w * 0.5, pos.y),
		Vector2(pos.x + trunk_w * 0.3 + lean, pos.y - trunk_h),
		Vector2(pos.x - trunk_w * 0.3 + lean, pos.y - trunk_h),
	]), Color(0.55, 0.40, 0.20))

	# Trunk segments
	for seg in range(4):
		var seg_y = pos.y - (trunk_h * (seg + 1)) / 5
		draw_line(Vector2(pos.x - trunk_w * 0.6 + lean * seg / 4, seg_y),
				  Vector2(pos.x + trunk_w * 0.6 + lean * seg / 4, seg_y),
				  Color(0.45, 0.30, 0.15), max(0.5, scale * 1.5))

	# Palm fronds
	var top = Vector2(pos.x + lean, pos.y - trunk_h)
	var frond_colors = [Color(0.15, 0.7, 0.15), Color(0.1, 0.55, 0.1), Color(0.2, 0.8, 0.2)]
	var frond_dirs = [
		Vector2(-1, -0.3), Vector2(-0.7, -0.8), Vector2(0, -1),
		Vector2(0.7, -0.8), Vector2(1, -0.3), Vector2(0.5, 0.2), Vector2(-0.5, 0.2)
	]
	for dir in frond_dirs:
		var fl = 22.0 * scale
		var tip = top + dir * fl
		var fc = frond_colors[randi() % frond_colors.size()]
		draw_line(top, tip, fc, max(1.0, scale * 2.5))
		# Frond leaves
		var perp = Vector2(-dir.y, dir.x) * 5 * scale
		draw_line(top + dir * fl * 0.4, tip + perp, fc, max(0.8, scale * 1.5))
		draw_line(top + dir * fl * 0.4, tip - perp, fc, max(0.8, scale * 1.5))

# ─── Draw enemy road objects ───────────────────────────────────────────────────
func _draw_road_object(obj: RoadObject) -> void:
	var pos = world_to_screen(obj.world_x, obj.world_z)
	var scale = world_to_size(obj.world_z, 1.0)

	match obj.type:
		"moped":
			_draw_enemy_moped(pos, scale, obj.color)
		"car":
			_draw_enemy_car(pos, scale, obj.color)
		"person":
			_draw_enemy_person(pos, scale)
		"powerup":
			_draw_powerup_platano(pos, scale)

func _draw_enemy_moped(pos: Vector2, scale: float, color: Color) -> void:
	var w = 16 * scale
	var h = 24 * scale

	# Moped body (from behind)
	draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x - w * 0.5, pos.y),
		Vector2(pos.x + w * 0.5, pos.y),
		Vector2(pos.x + w * 0.35, pos.y - h * 0.5),
		Vector2(pos.x - w * 0.35, pos.y - h * 0.5),
	]), color)

	# Wheels
	draw_circle(Vector2(pos.x - w * 0.4, pos.y - scale * 2), 5 * scale, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(pos.x + w * 0.4, pos.y - scale * 2), 5 * scale, Color(0.15, 0.15, 0.15))

	# Delivery box (some enemies have one too)
	draw_rect(Rect2(pos.x - w * 0.4, pos.y - h * 0.85, w * 0.8, h * 0.35), Color(0.9, 0.7, 0.0))

	# Rider head
	draw_circle(Vector2(pos.x, pos.y - h * 0.9), 5 * scale, Color(0.75, 0.55, 0.35))
	# Helmet / hat
	draw_rect(Rect2(pos.x - 5 * scale, pos.y - h - 2 * scale, 10 * scale, 7 * scale), color)

func _draw_enemy_car(pos: Vector2, scale: float, color: Color) -> void:
	var w = 26 * scale
	var h = 40 * scale

	# Car body from behind
	draw_rect(Rect2(pos.x - w * 0.5, pos.y - h * 0.6, w, h * 0.6), color)
	# Roof
	draw_rect(Rect2(pos.x - w * 0.35, pos.y - h, w * 0.7, h * 0.4), color.lightened(0.1))
	# Rear windshield
	draw_rect(Rect2(pos.x - w * 0.3, pos.y - h * 0.95, w * 0.6, h * 0.3), Color(0.5, 0.75, 0.95, 0.7))
	# Rear lights
	draw_rect(Rect2(pos.x - w * 0.48, pos.y - h * 0.7, w * 0.12, h * 0.12), Color(1.0, 0.1, 0.1))
	draw_rect(Rect2(pos.x + w * 0.36, pos.y - h * 0.7, w * 0.12, h * 0.12), Color(1.0, 0.1, 0.1))
	# Wheels
	draw_circle(Vector2(pos.x - w * 0.4, pos.y - scale * 2), 6 * scale, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(pos.x + w * 0.4, pos.y - scale * 2), 6 * scale, Color(0.15, 0.15, 0.15))
	# License plate (DR flavor)
	draw_rect(Rect2(pos.x - w * 0.25, pos.y - h * 0.15, w * 0.5, h * 0.1),
			  Color(1, 1, 1))

func _draw_enemy_person(pos: Vector2, scale: float) -> void:
	# Simple pedestrian
	var h = 20 * scale
	draw_circle(Vector2(pos.x, pos.y - h - 4 * scale), 4 * scale, Color(0.85, 0.65, 0.45))
	draw_rect(Rect2(pos.x - 5 * scale, pos.y - h, 10 * scale, h * 0.6),
			  [Color(0.8, 0.1, 0.1), Color(0.1, 0.3, 0.8), Color(0.9, 0.8, 0.1)][randi() % 3])

func _draw_powerup_platano(pos: Vector2, scale: float) -> void:
	# Rotating platano bunch
	var t = Time.get_ticks_msec() / 400.0
	for i in range(3):
		var angle = t + i * TAU / 3.0
		var off = Vector2(cos(angle), sin(angle) * 0.4) * 10 * scale
		_draw_platano_at(pos + off, scale * 0.8)

func _draw_platano_at(pos: Vector2, scale: float) -> void:
	# Banana shape using a polygon
	var pts = PackedVector2Array()
	var c = Color(1.0, 0.9, 0.1)
	var w = 8 * scale
	var h = 14 * scale
	# Simple curved banana shape
	pts.append(pos + Vector2(0, -h * 0.5))
	pts.append(pos + Vector2(w * 0.6, -h * 0.1))
	pts.append(pos + Vector2(w * 0.5, h * 0.4))
	pts.append(pos + Vector2(0, h * 0.5))
	pts.append(pos + Vector2(-w * 0.3, h * 0.3))
	pts.append(pos + Vector2(-w * 0.4, -h * 0.1))
	draw_colored_polygon(pts, c)
	# Brown tip
	draw_circle(pos + Vector2(0, -h * 0.5), 2 * scale, Color(0.4, 0.25, 0.1))

# ─── Draw player moped (from behind, bottom center) ──────────────────────────
func _draw_player() -> void:
	var x = PLAYER_SCREEN_X + player_lane * 80.0
	var y = PLAYER_SCREEN_Y

	# Flicker if invincible
	if player_invincible > 0 and fmod(Time.get_ticks_msec() / 80.0, 2.0) < 1.0:
		return

	var lean = player_lean * 15.0  # degrees of lean

	# Shadow
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 22, y + 2),
		Vector2(x + 22, y + 2),
		Vector2(x + 18, y + 8),
		Vector2(x - 18, y + 8),
	]), Color(0, 0, 0, 0.25))

	# Rear wheel
	draw_circle(Vector2(x, y), 14, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(x, y), 10, Color(0.25, 0.25, 0.28))
	draw_circle(Vector2(x, y), 4, Color(0.6, 0.6, 0.65))

	# Front wheel (slightly above)
	draw_circle(Vector2(x + lean * 0.3, y - 40), 11, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(x + lean * 0.3, y - 40), 7, Color(0.25, 0.25, 0.28))

	# Moped body (red, from behind)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 14, y - 5),
		Vector2(x + 14, y - 5),
		Vector2(x + 12 + lean, y - 42),
		Vector2(x - 12 + lean, y - 42),
	]), Color(0.85, 0.10, 0.08))

	# Engine/exhaust pipes
	draw_line(Vector2(x - 13, y - 15), Vector2(x - 18, y - 5), Color(0.5, 0.5, 0.5), 3)
	draw_line(Vector2(x + 13, y - 15), Vector2(x + 18, y - 5), Color(0.5, 0.5, 0.5), 3)

	# Tail lights
	draw_rect(Rect2(x - 14 + lean * 0.2, y - 30, 6, 5), Color(1.0, 0.15, 0.1))
	draw_rect(Rect2(x + 8 + lean * 0.2, y - 30, 6, 5), Color(1.0, 0.15, 0.1))

	# Yellow DELIVERY box
	draw_rect(Rect2(x - 22 + lean, y - 72, 44, 34), Color(1.0, 0.82, 0.0))
	draw_rect(Rect2(x - 22 + lean, y - 72, 44, 3), Color(0.6, 0.4, 0.0))
	draw_rect(Rect2(x - 22 + lean, y - 72, 3, 34), Color(0.6, 0.4, 0.0))
	draw_rect(Rect2(x + 19 + lean, y - 72, 3, 34), Color(0.6, 0.4, 0.0))
	# DELIVERY text bar
	draw_rect(Rect2(x - 20 + lean, y - 60, 40, 12), Color(0.1, 0.1, 0.1, 0.7))

	# Handlebar
	draw_line(Vector2(x - 16 + lean, y - 56), Vector2(x + 16 + lean, y - 56),
			  Color(0.4, 0.4, 0.45), 3)

	# Rider - back of head
	draw_circle(Vector2(x + lean * 0.5, y - 86), 13, Color(0.85, 0.65, 0.45))
	# Helmet
	draw_circle(Vector2(x + lean * 0.5, y - 89), 14, Color(0.85, 0.10, 0.08))
	draw_rect(Rect2(x - 14 + lean * 0.5, y - 95, 28, 8), Color(0.85, 0.10, 0.08))

	# White shirt shoulders
	draw_rect(Rect2(x - 16 + lean * 0.3, y - 76, 32, 22), Color(0.95, 0.95, 0.95))

	# Arms
	draw_line(Vector2(x - 16 + lean * 0.3, y - 72), Vector2(x - 16 + lean, y - 56),
			  Color(0.85, 0.65, 0.45), 5)
	draw_line(Vector2(x + 16 + lean * 0.3, y - 72), Vector2(x + 16 + lean, y - 56),
			  Color(0.85, 0.65, 0.45), 5)

# ─── Draw platano arc animations ──────────────────────────────────────────────
func _draw_platanos() -> void:
	for p in platanos:
		if not p.active:
			continue
		var t = p.progress
		# Arc: parabolic from player to target
		var start = p.from_pos
		var end_screen = world_to_screen(p.to_x, p.to_z)
		# Control point (peak of arc)
		var mid = (start + end_screen) * 0.5 - Vector2(0, 120)

		# Bezier position
		var bpos = start * (1 - t) * (1 - t) + mid * 2 * (1 - t) * t + end_screen * t * t
		# Rotation based on flight direction
		_draw_platano_at(bpos, 1.2 - t * 0.5)
		# Trail dots
		for trail in range(3):
			var tt = max(0.0, t - trail * 0.08)
			var tbpos = start * (1 - tt) * (1 - tt) + mid * 2 * (1 - tt) * tt + end_screen * tt * tt
			draw_circle(tbpos, max(1.5, (3.0 - trail) * 0.8), Color(1.0, 0.9, 0.2, 0.5 - trail * 0.15))

# ─── Draw GET READY overlay ────────────────────────────────────────────────────
func _draw_get_ready() -> void:
	draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), Color(0, 0, 0, 0.5))
	# Title at top
	draw_rect(Rect2(30, 120, 330, 80), Color(0.1, 0.05, 0.3, 0.95))
	draw_rect(Rect2(32, 122, 326, 76), Color(0.05, 0.03, 0.2, 0.95))
	# COLMADO DASH text block (pixel-art block letters visual)
	for row in range(4):
		draw_rect(Rect2(50 + row * 8, 140, 280, 8), Color(1.0, 0.88, 0.1, 0.9 - row * 0.1))
	draw_rect(Rect2(60, 160, 270, 20), Color(0.9, 0.3, 0.1, 0.9))

	# GET READY box
	draw_rect(Rect2(60, 300, 270, 60), Color(0.1, 0.1, 0.4, 0.95))
	draw_rect(Rect2(62, 302, 266, 56), Color(1.0, 0.85, 0.0, 0.9))
	draw_rect(Rect2(64, 304, 262, 52), Color(0.1, 0.1, 0.4, 0.95))
