extends Node2D
## MenuScene.gd - Colmado Dash title screen
## Behind-moped pixel art style matching the game's Road Rash aesthetic

const SCREEN_W := 390.0
const SCREEN_H := 844.0
const HORIZON_Y := 300.0

var road_scroll: float = 0.0
var speed: float = 2.5
var _intro_done: bool = false
var wobble_time: float = 0.0

# Road-side buildings (same system as game)
class MenuBuilding:
	var world_x: float = -1.6
	var z: float = 5.0
	var color: Color = Color.ORANGE_RED
	var name_text: String = "COLMADO"
	var awning_color: Color = Color.RED
	var height_norm: float = 1.0
	var side: int = -1  # -1 left, +1 right

var buildings: Array = []
var palm_z_offsets: Array = []
var moped_x: float = -80.0

func _ready() -> void:
	_spawn_buildings()
	_play_intro()
	set_process_input(true)

func _play_intro() -> void:
	_intro_done = false
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.6)
	await tween.finished
	_intro_done = true

func _spawn_buildings() -> void:
	var configs = [
		["COLMADO LA 17", Color(0.9, 0.3, 0.05), Color(0.8, 0.1, 0.1), -1],
		["COLMADO LA 24", Color(0.1, 0.4, 0.8), Color(1.0, 0.8, 0.0), 1],
		["VARIEDADES REY", Color(0.2, 0.6, 0.2), Color(0.9, 0.5, 0.1), -1],
		["FRIO-FRIO MARY", Color(0.85, 0.15, 0.5), Color(0.2, 0.6, 0.9), 1],
		["COLMADO FAVORITO", Color(1.0, 0.5, 0.0), Color(0.3, 0.8, 0.1), -1],
		["LOTERIA NACIONAL", Color(0.15, 0.2, 0.7), Color(0.9, 0.8, 0.0), 1],
		["CHIMICHURRI 24H", Color(0.85, 0.45, 0.0), Color(0.1, 0.6, 0.2), -1],
		["FARMACIA BELLA", Color(0.0, 0.6, 0.4), Color(0.8, 0.0, 0.1), 1],
	]
	for i in range(configs.size()):
		var cfg = configs[i]
		var b = MenuBuilding.new()
		b.side = int(cfg[3])
		b.world_x = float(cfg[3]) * 1.6
		b.z = 1.5 + i * 2.0
		b.name_text = cfg[0]
		b.color = cfg[1]
		b.awning_color = cfg[2]
		b.height_norm = randf_range(0.9, 1.6)
		buildings.append(b)

	for i in range(6):
		palm_z_offsets.append(1.0 + i * 2.2)

func _process(delta: float) -> void:
	road_scroll += speed * delta * 2.0
	if road_scroll > 1.0:
		road_scroll -= 1.0

	wobble_time += delta * 2.5

	# Scroll buildings
	for b in buildings:
		b.z -= speed * delta

	buildings = buildings.filter(func(b): return b.z > -0.5)

	# Respawn buildings at back
	if buildings.is_empty() or buildings.back().z < 12:
		_spawn_next_building()

	# Moped animation
	moped_x += delta * 200.0
	if moped_x > SCREEN_W + 80:
		moped_x = -80.0

	queue_redraw()

func _spawn_next_building() -> void:
	var max_z = 0.0
	for b in buildings:
		if b.z > max_z:
			max_z = b.z

	var configs = [
		["COLMADO LA 17", Color(0.9, 0.3, 0.05), Color(0.8, 0.1, 0.1)],
		["COLMADO LA 24", Color(0.1, 0.4, 0.8), Color(1.0, 0.8, 0.0)],
		["VARIEDADES REY", Color(0.2, 0.6, 0.2), Color(0.9, 0.5, 0.1)],
		["FRIO-FRIO MARY", Color(0.85, 0.15, 0.5), Color(0.2, 0.6, 0.9)],
		["COLMADO FAVORITO", Color(1.0, 0.5, 0.0), Color(0.3, 0.8, 0.1)],
	]

	for side in [-1, 1]:
		var cfg = configs[randi() % configs.size()]
		var b = MenuBuilding.new()
		b.side = side
		b.world_x = float(side) * 1.6
		b.z = max_z + 3.0
		b.name_text = cfg[0]
		b.color = cfg[1]
		b.awning_color = cfg[2]
		b.height_norm = randf_range(0.9, 1.6)
		buildings.append(b)

# Helper - same perspective as game
func world_to_screen(world_x: float, world_z: float) -> Vector2:
	var z = max(world_z, 0.01)
	var perspective = 1.0 / (z + 0.1)
	var screen_x = 195.0 + world_x * perspective * 400.0
	var screen_y = HORIZON_Y + (SCREEN_H - HORIZON_Y) / (z + 1.0)
	return Vector2(screen_x, screen_y)

func world_to_size(world_z: float, base_size: float) -> float:
	return clamp(base_size / (world_z * 0.4 + 0.1), 2.0, base_size * 5.0)

func _draw() -> void:
	# Sky
	draw_rect(Rect2(0, 0, SCREEN_W, HORIZON_Y), Color(0.25, 0.55, 0.95))
	draw_rect(Rect2(0, HORIZON_Y - 30, SCREEN_W, 35), Color(0.55, 0.8, 1.0, 0.6))
	draw_circle(Vector2(320, 70), 30, Color(1.0, 0.92, 0.3))
	draw_circle(Vector2(320, 70), 24, Color(1.0, 0.98, 0.75))

	# Clouds
	_draw_cloud(Vector2(60, 55), 1.0)
	_draw_cloud(Vector2(200, 40), 0.75)

	# Road
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, SCREEN_H), Vector2(55, SCREEN_H),
		Vector2(100, HORIZON_Y), Vector2(0, HORIZON_Y)
	]), Color(0.72, 0.67, 0.58))
	draw_colored_polygon(PackedVector2Array([
		Vector2(335, SCREEN_H), Vector2(SCREEN_W, SCREEN_H),
		Vector2(SCREEN_W, HORIZON_Y), Vector2(290, HORIZON_Y)
	]), Color(0.72, 0.67, 0.58))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, SCREEN_H), Vector2(SCREEN_W, SCREEN_H),
		Vector2(290, HORIZON_Y), Vector2(100, HORIZON_Y)
	]), Color(0.42, 0.42, 0.42))

	# Dashes
	var scroll_offset = fmod(road_scroll, 0.5)
	for i in range(14):
		var z_val = 0.3 + float(i) * 0.55 - scroll_offset * 0.55
		if z_val <= 0:
			continue
		if int(i) % 2 == 0:
			var p1 = world_to_screen(0.0, z_val)
			var p2 = world_to_screen(0.0, z_val + 0.3)
			draw_line(p1, p2, Color(1.0, 0.88, 0.1), clamp(4.0 / (z_val * 0.5 + 0.3), 1.0, 7.0))

	# World objects (depth sorted)
	var draw_list: Array = []
	for b in buildings:
		if b.z > 0 and b.z < 12:
			draw_list.append({"z": b.z, "type": "building", "obj": b})
	for i in range(palm_z_offsets.size()):
		var pz = fmod(palm_z_offsets[i] + road_scroll * 5.0, 14.0)
		if pz > 0.2 and pz < 12:
			draw_list.append({"z": pz, "type": "palm_l", "pz": pz})
			draw_list.append({"z": pz + 0.3, "type": "palm_r", "pz": pz + 0.3})

	draw_list.sort_custom(func(a, b): return a["z"] > b["z"])

	for item in draw_list:
		if item["type"] == "building":
			_draw_building(item["obj"])
		elif item["type"] == "palm_l":
			_draw_palm(item["pz"], -1)
		elif item["type"] == "palm_r":
			_draw_palm(item["pz"], 1)

	# Player moped on menu (side-scrolling moped riding right)
	_draw_menu_moped(moped_x, SCREEN_H - 80.0)

	# Title overlay
	_draw_title()

	# Blink "TAP TO START"
	var blink = fmod(Time.get_ticks_msec() / 600.0, 2.0) < 1.2
	if blink:
		_draw_tap_to_start()

	# SANTO DOMINGO at bottom
	_draw_bottom_bar()

func _draw_cloud(pos: Vector2, size: float) -> void:
	var c = Color(1.0, 1.0, 1.0, 0.85)
	draw_circle(pos, 18 * size, c)
	draw_circle(pos + Vector2(16 * size, -6 * size), 14 * size, c)
	draw_circle(pos + Vector2(-14 * size, -4 * size), 12 * size, c)
	draw_circle(pos + Vector2(30 * size, 2 * size), 11 * size, c)

func _draw_building(b: MenuBuilding) -> void:
	var pos = world_to_screen(b.world_x, b.z)
	var scale = world_to_size(b.z, 1.0)
	var base_w = 60.0 * scale
	var base_h = 90.0 * scale * b.height_norm
	var bx = pos.x
	var by = pos.y

	draw_rect(Rect2(bx - base_w * 0.5, by - base_h, base_w, base_h), b.color)
	draw_rect(Rect2(bx - base_w * 0.5, by - base_h - scale * 6, base_w, scale * 6), b.color.lightened(0.3))

	# Awning
	var awn_y = by - base_h * 0.65
	var awn_h = scale * 8
	for strip_i in range(4):
		var sc = b.awning_color if strip_i % 2 == 0 else Color.WHITE
		draw_rect(Rect2(bx - base_w * 0.5 + strip_i * base_w / 4, awn_y, base_w / 4, awn_h), sc)

	if scale > 0.2:
		draw_rect(Rect2(bx - base_w * 0.5, by - base_h * 0.45, base_w, scale * 10), Color(0.1, 0.1, 0.1, 0.85))
		draw_rect(Rect2(bx - base_w * 0.5 + scale, by - base_h * 0.45 + scale, base_w - scale * 2, scale * 8),
				  Color(1.0, 0.88, 0.1, 0.9))

func _draw_palm(pz: float, side: int) -> void:
	var world_x = side * (1.1 + randf() * 0.1)
	var pos = world_to_screen(world_x * 1.0, pz)
	var scale = world_to_size(pz, 1.0)
	var trunk_h = 55.0 * scale
	var lean = 8.0 * scale * side

	draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x - 3*scale, pos.y),
		Vector2(pos.x + 3*scale, pos.y),
		Vector2(pos.x + 2*scale + lean, pos.y - trunk_h),
		Vector2(pos.x - 2*scale + lean, pos.y - trunk_h),
	]), Color(0.55, 0.40, 0.20))

	var top = Vector2(pos.x + lean, pos.y - trunk_h)
	var gc = Color(0.15, 0.65, 0.15)
	for dir in [Vector2(-1, -0.3), Vector2(-0.7, -0.8), Vector2(0, -1),
				Vector2(0.7, -0.8), Vector2(1, -0.3)]:
		draw_line(top, top + dir * 20 * scale, gc, max(1.0, scale * 2.0))

func _draw_menu_moped(x: float, y: float) -> void:
	# Side view moped (not behind - menu is top-down street view)
	# Draw a simple side-view moped
	var lean = sin(wobble_time * 4) * 1.5  # slight bob

	# Shadow
	draw_ellipse_approx(Vector2(x, y + 4), 28, 6, Color(0, 0, 0, 0.2))

	# Wheels
	draw_circle(Vector2(x - 20, y - 2 + lean), 12, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(x - 20, y - 2 + lean), 7, Color(0.3, 0.3, 0.3))
	draw_circle(Vector2(x + 18, y - 5 + lean), 11, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(x + 18, y - 5 + lean), 6, Color(0.3, 0.3, 0.3))

	# Body
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 20, y - 5 + lean), Vector2(x + 18, y - 8 + lean),
		Vector2(x + 14, y - 25 + lean), Vector2(x - 16, y - 22 + lean),
	]), Color(0.85, 0.10, 0.08))

	# Yellow delivery box
	draw_rect(Rect2(x - 14, y - 40 + lean, 28, 20), Color(1.0, 0.82, 0.0))
	draw_rect(Rect2(x - 14, y - 40 + lean, 28, 2), Color(0.6, 0.4, 0.0))

	# Rider
	draw_circle(Vector2(x + 5, y - 48 + lean), 9, Color(0.85, 0.65, 0.45))
	draw_rect(Rect2(x - 4, y - 42 + lean, 18, 14), Color(0.95, 0.95, 0.95))

func draw_ellipse_approx(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts = PackedVector2Array()
	var segments = 16
	for i in range(segments):
		var angle = i * TAU / segments
		pts.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_colored_polygon(pts, color)

func _draw_title() -> void:
	var cx = SCREEN_W * 0.5
	var ty = 350.0

	# Title panel
	draw_rect(Rect2(20, ty - 10, SCREEN_W - 40, 130), Color(0.0, 0.0, 0.0, 0.78))
	draw_rect(Rect2(22, ty - 8, SCREEN_W - 44, 126), Color(0.04, 0.04, 0.18, 0.9))

	# Top border (animated color)
	var t = Time.get_ticks_msec() / 800.0
	var border_c = Color(
		0.5 + 0.5 * sin(t),
		0.5 + 0.5 * sin(t + TAU / 3),
		0.5 + 0.5 * sin(t + 2 * TAU / 3)
	)
	draw_rect(Rect2(20, ty - 10, SCREEN_W - 40, 4), border_c)
	draw_rect(Rect2(20, ty + 120, SCREEN_W - 40, 4), border_c)

	# COLMADO text (big yellow)
	var px = 35.0 + sin(wobble_time * 0.5) * 3
	_draw_big_text("COLMADO", Vector2(px, ty + 5), Color(1.0, 0.88, 0.1))

	# DASH text (red)
	_draw_big_text("DASH", Vector2(px + 20, ty + 55), Color(0.9, 0.2, 0.1))

	# Subtitle
	_draw_small_text("EL DELIVERY MAS LOCO DE SD", Vector2(cx - 120, ty + 100), Color(0.7, 0.9, 1.0))

func _draw_big_text(text: String, pos: Vector2, color: Color) -> void:
	# Draw each character as a large pixel block letter
	var x = pos.x
	for ch in text:
		_draw_big_char(ch, Vector2(x, pos.y), color)
		x += 45.0

func _draw_big_char(ch: String, pos: Vector2, color: Color) -> void:
	var s = 5.0
	var x = pos.x
	var y = pos.y
	var c = color

	match ch.to_upper():
		"C":
			draw_rect(Rect2(x + s, y, 5*s, s), c); draw_rect(Rect2(x, y + s, s, 7*s), c)
			draw_rect(Rect2(x + s, y + 8*s, 5*s, s), c)
		"O":
			draw_rect(Rect2(x + s, y, 4*s, s), c); draw_rect(Rect2(x + s, y + 8*s, 4*s, s), c)
			draw_rect(Rect2(x, y + s, s, 7*s), c); draw_rect(Rect2(x + 5*s, y + s, s, 7*s), c)
		"L":
			draw_rect(Rect2(x, y, s, 9*s), c); draw_rect(Rect2(x, y + 8*s, 6*s, s), c)
		"M":
			draw_rect(Rect2(x, y, s, 9*s), c); draw_rect(Rect2(x + 6*s, y, s, 9*s), c)
			draw_rect(Rect2(x + s, y, s, 4*s), c); draw_rect(Rect2(x + 5*s, y, s, 4*s), c)
			draw_rect(Rect2(x + 2*s, y + s, s, 3*s), c); draw_rect(Rect2(x + 4*s, y + s, s, 3*s), c)
			draw_rect(Rect2(x + 3*s, y + 2*s, s, 2*s), c)
		"A":
			draw_rect(Rect2(x + s, y, 4*s, s), c); draw_rect(Rect2(x, y + s, s, 8*s), c)
			draw_rect(Rect2(x + 5*s, y + s, s, 8*s), c); draw_rect(Rect2(x, y + 4*s, 6*s, s), c)
		"D":
			draw_rect(Rect2(x, y, s, 9*s), c); draw_rect(Rect2(x, y, 4*s, s), c)
			draw_rect(Rect2(x, y + 8*s, 4*s, s), c); draw_rect(Rect2(x + 5*s, y + s, s, 7*s), c)
			draw_rect(Rect2(x + 4*s, y, s, s), c); draw_rect(Rect2(x + 4*s, y + 8*s, s, s), c)
		"H":
			draw_rect(Rect2(x, y, s, 9*s), c); draw_rect(Rect2(x + 5*s, y, s, 9*s), c)
			draw_rect(Rect2(x, y + 4*s, 6*s, s), c)
		"S":
			draw_rect(Rect2(x + s, y, 5*s, s), c); draw_rect(Rect2(x, y, s, 4*s), c)
			draw_rect(Rect2(x, y + 4*s, 6*s, s), c); draw_rect(Rect2(x + 5*s, y + 4*s, s, 4*s), c)
			draw_rect(Rect2(x, y + 8*s, 5*s, s), c)
		_:
			draw_rect(Rect2(x + s, y + s, 4*s, 7*s), Color(color.r, color.g, color.b, 0.5))

func _draw_small_text(text: String, pos: Vector2, color: Color) -> void:
	var x = pos.x
	for ch in text:
		if ch == " ":
			x += 7.0
			continue
		_draw_small_char(ch, Vector2(x, pos.y), color)
		x += 7.0

func _draw_small_char(ch: String, pos: Vector2, color: Color) -> void:
	var s = 1.2
	var x = pos.x
	var y = pos.y
	# Super simple block
	match ch.to_upper():
		"A","B","C","D","E","F","G","H","I","J","K","L","M",
		"N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
		"0","1","2","3","4","5","6","7","8","9":
			draw_rect(Rect2(x, y, 5*s, s), color)
			draw_rect(Rect2(x, y + s, s, 4*s), color)
			draw_rect(Rect2(x + 4*s, y + s, s, 4*s), color)
			draw_rect(Rect2(x, y + 5*s, 5*s, s), color)
		_:
			draw_rect(Rect2(x + s, y + 2*s, 3*s, 2*s), Color(color.r, color.g, color.b, 0.4))

func _draw_tap_to_start() -> void:
	var cx = SCREEN_W * 0.5
	var ty = 510.0

	draw_rect(Rect2(50, ty - 5, SCREEN_W - 100, 40), Color(0.0, 0.0, 0.0, 0.65))
	_draw_small_text("TAP TO START", Vector2(cx - 42, ty + 6), Color(1.0, 0.9, 0.1))

func _draw_bottom_bar() -> void:
	draw_rect(Rect2(0, SCREEN_H - 40, SCREEN_W, 40), Color(0.03, 0.03, 0.12, 0.9))
	draw_rect(Rect2(0, SCREEN_H - 40, SCREEN_W, 2), Color(1.0, 0.88, 0.0, 0.7))
	_draw_small_text("SANTO DOMINGO, REPUBLICA DOMINICANA", Vector2(30, SCREEN_H - 26), Color(0.8, 0.8, 0.8))
	# DR flag mini
	var fx = SCREEN_W - 30.0
	var fy = SCREEN_H - 32.0
	draw_rect(Rect2(fx, fy, 10, 5), Color(0.0, 0.2, 0.8))
	draw_rect(Rect2(fx + 10, fy, 10, 5), Color(0.8, 0.05, 0.05))
	draw_rect(Rect2(fx, fy + 5, 10, 5), Color(0.8, 0.05, 0.05))
	draw_rect(Rect2(fx + 10, fy + 5, 10, 5), Color(0.0, 0.2, 0.8))
	draw_rect(Rect2(fx + 8, fy, 4, 10), Color(1, 1, 1))
	draw_rect(Rect2(fx, fy + 4, 20, 3), Color(1, 1, 1))

func _input(event: InputEvent) -> void:
	if not _intro_done:
		return
	if (event is InputEventScreenTouch and event.pressed) or \
	   (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_tree().change_scene_to_file("res://scenes/GameScene.tscn")
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		get_tree().change_scene_to_file("res://scenes/GameScene.tscn")
