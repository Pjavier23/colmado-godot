extends CanvasLayer
## HUD.gd - Behind-moped runner HUD matching the reference image
## Signals for game controls

signal direction_changed(dir: Vector2)
signal joystick_moved(direction: Vector2)
signal fire_pressed
signal weapon_selected(weapon_name: String)
signal swipe_left
signal swipe_right

# HUD node refs
@onready var top_bar: ColorRect = $TopBar

# Touch control state
var _joy_finger: int = -1
var _joy_origin: Vector2 = Vector2.ZERO
var _fire_finger: int = -1
var touch_start: Vector2 = Vector2.ZERO
var touch_id: int = -1

const JOYSTICK_RADIUS := 60.0
var joystick_active: bool = false

# Game data to display
var health: int = 3
var money: int = 350
var score: int = 0
var timer: float = 90.0
var current_weapon: String = "platano"
var ammo: int = 99

# HUD state
var message_text: String = ""
var message_color: Color = Color.YELLOW
var message_timer: float = 0.0
var pickup_text: String = "COLMADO EL FAVORITO"
var show_pickup: bool = true
var pickup_timer: float = 4.0
var game_over_visible: bool = false
var game_over_won: bool = false
var game_over_score: int = 0
var game_over_money: int = 0

# Mini-map data
var minimap_route: Array = [
	Vector2(0.1, 0.9), Vector2(0.1, 0.3), Vector2(0.5, 0.3),
	Vector2(0.5, 0.7), Vector2(0.9, 0.7), Vector2(0.9, 0.1)
]

# Weapon slots
var weapon_slots = [
	{"name": "PLATANO", "ammo": 99, "color": Color(1.0, 0.9, 0.1)},
	{"name": "MINI GRAAPM", "ammo": 3, "color": Color(0.8, 0.2, 0.2)},
	{"name": "HUEVO", "ammo": 5, "color": Color(0.95, 0.92, 0.75)},
]
var selected_weapon_idx: int = 0

func _ready() -> void:
	set_process_unhandled_input(true)
	set_process(true)

func _process(delta: float) -> void:
	if message_timer > 0:
		message_timer -= delta
	if show_pickup and pickup_timer > 0:
		pickup_timer -= delta
	queue_redraw()

# ─── Public update methods ────────────────────────────────────────────────────

func update_health(h: int) -> void:
	health = h

func update_money(m: int) -> void:
	money = m

func update_score(s: int) -> void:
	score = s

func update_timer(t: float) -> void:
	timer = t

func update_weapon(weapon: String, weapon_ammo: int) -> void:
	current_weapon = weapon
	ammo = weapon_ammo

func show_message(msg: String, color: Color = Color.YELLOW) -> void:
	message_text = msg
	message_color = color
	message_timer = 1.8

func show_delivery_message(msg: String, color: Color = Color.YELLOW) -> void:
	show_message(msg, color)

func show_game_over(won: bool, final_score: int, final_money: int) -> void:
	game_over_visible = true
	game_over_won = won
	game_over_score = final_score
	game_over_money = final_money

func update_arrow(_dir: Vector2) -> void:
	pass  # Handled in draw

# ─── Drawing ──────────────────────────────────────────────────────────────────
func _draw() -> void:
	_draw_top_left_money()
	_draw_health_center()
	_draw_minimap_top_right()
	_draw_weapon_slots_bottom_right()
	_draw_santo_domingo_bottom()
	_draw_fire_button()
	_draw_joystick_hint()

	if show_pickup and pickup_timer > 0:
		_draw_pickup_banner()

	if message_timer > 0:
		_draw_message()

	if game_over_visible:
		_draw_game_over()

# ─── TOP LEFT: Money earned ───────────────────────────────────────────────────
func _draw_top_left_money() -> void:
	var vp = get_viewport().get_visible_rect().size
	var bx = 8.0
	var by = 8.0

	# Background panel
	draw_rect(Rect2(bx, by, 160, 85), Color(0.0, 0.0, 0.0, 0.65))
	draw_rect(Rect2(bx + 2, by + 2, 156, 81), Color(0.05, 0.05, 0.18, 0.75))

	# Money amount (big yellow)
	_draw_pixel_text("$%d" % money, Vector2(bx + 8, by + 12), Color(1.0, 0.9, 0.1), 2.5)
	# Bonus line
	_draw_pixel_text("+$%d BONUS" % maxi(0, score / 10), Vector2(bx + 8, by + 36), Color(0.8, 1.0, 0.4), 1.2)
	# Pickup label
	_draw_pixel_text("PICKED UP FROM", Vector2(bx + 8, by + 52), Color(0.7, 0.7, 0.7), 1.0)
	_draw_pixel_text("COLMADO EL FAVORITO", Vector2(bx + 8, by + 64), Color(1.0, 0.9, 0.1), 1.1)

# ─── TOP CENTER: Health hearts ─────────────────────────────────────────────────
func _draw_health_center() -> void:
	var vp = get_viewport().get_visible_rect().size
	var cx = vp.x * 0.5
	var by = 10.0
	var heart_size = 16.0
	var total = 5
	var spacing = heart_size + 4

	# Background
	var bar_w = total * spacing + 8
	draw_rect(Rect2(cx - bar_w * 0.5, by, bar_w, heart_size + 10), Color(0, 0, 0, 0.6))

	for i in range(total):
		var hx = cx - (total * spacing) * 0.5 + i * spacing + 4
		var hy = by + 4
		var filled = i < health
		_draw_heart(Vector2(hx, hy), heart_size * 0.5, filled)

	# Timer below hearts
	var mins = int(max(timer, 0)) / 60
	var secs = int(max(timer, 0)) % 60
	var time_str = "%d:%02d" % [mins, secs]
	var t_color = Color(1, 0.2, 0.2) if timer < 20 else Color(1.0, 0.9, 0.1)
	_draw_pixel_text(time_str, Vector2(cx - 20, by + heart_size + 6), t_color, 1.6)

func _draw_heart(pos: Vector2, r: float, filled: bool) -> void:
	var c = Color(1.0, 0.18, 0.28) if filled else Color(0.4, 0.2, 0.25)
	# Two circles + triangle
	draw_circle(pos + Vector2(-r * 0.5, 0), r * 0.75, c)
	draw_circle(pos + Vector2(r * 0.5, 0), r * 0.75, c)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-r * 1.2, r * 0.3),
		pos + Vector2(r * 1.2, r * 0.3),
		pos + Vector2(0, r * 1.5),
	]), c)

# ─── TOP RIGHT: Mini-map ──────────────────────────────────────────────────────
func _draw_minimap_top_right() -> void:
	var vp = get_viewport().get_visible_rect().size
	var mx = vp.x - 82.0
	var my = 8.0
	var mw = 74.0
	var mh = 74.0

	# Background
	draw_rect(Rect2(mx, my, mw, mh), Color(0.0, 0.0, 0.0, 0.75))
	draw_rect(Rect2(mx + 2, my + 2, mw - 4, mh - 4), Color(0.05, 0.12, 0.05, 0.85))

	# Mini-map grid
	for i in range(1, 4):
		var gx = mx + i * mw / 4
		draw_line(Vector2(gx, my), Vector2(gx, my + mh), Color(0.2, 0.4, 0.2, 0.4), 0.5)
		draw_line(Vector2(mx, my + i * mh / 4), Vector2(mx + mw, my + i * mh / 4),
				  Color(0.2, 0.4, 0.2, 0.4), 0.5)

	# Route path
	for i in range(minimap_route.size() - 1):
		var p1 = Vector2(mx + 4 + minimap_route[i].x * (mw - 8),
						 my + 4 + minimap_route[i].y * (mh - 8))
		var p2 = Vector2(mx + 4 + minimap_route[i + 1].x * (mw - 8),
						 my + 4 + minimap_route[i + 1].y * (mh - 8))
		draw_line(p1, p2, Color(1.0, 0.88, 0.0, 0.8), 2)

	# Player dot (blinking)
	var t = Time.get_ticks_msec() / 500.0
	var blink_a = 0.6 + sin(t * TAU) * 0.4
	var player_route_t = fmod(Time.get_ticks_msec() / 8000.0, 1.0)
	var player_dot_seg = int(player_route_t * (minimap_route.size() - 1))
	player_dot_seg = clampi(player_dot_seg, 0, minimap_route.size() - 2)
	var pt = player_route_t * (minimap_route.size() - 1) - player_dot_seg
	var p_pos_norm = minimap_route[player_dot_seg].lerp(minimap_route[player_dot_seg + 1], pt)
	var p_dot = Vector2(mx + 4 + p_pos_norm.x * (mw - 8), my + 4 + p_pos_norm.y * (mh - 8))
	draw_circle(p_dot, 4, Color(0.2, 1.0, 0.3, blink_a))
	draw_circle(p_dot, 2.5, Color(1.0, 1.0, 1.0, blink_a))

	# SANTO DOMINGO text in minimap
	_draw_pixel_text("SD", Vector2(mx + 4, my + mh - 14), Color(0.4, 0.8, 0.4), 1.0)

# ─── BOTTOM RIGHT: Weapon slots ────────────────────────────────────────────────
func _draw_weapon_slots_bottom_right() -> void:
	var vp = get_viewport().get_visible_rect().size
	var slot_w = 80.0
	var slot_h = 54.0
	var bx = vp.x - slot_w - 8.0
	var by = vp.y - (weapon_slots.size() * (slot_h + 4)) - 8.0

	for i in range(weapon_slots.size()):
		var slot = weapon_slots[i]
		var sx = bx
		var sy = by + i * (slot_h + 4)
		var is_selected = (i == selected_weapon_idx)

		# Slot background
		var bg_color = Color(0.05, 0.1, 0.05, 0.85) if not is_selected else Color(0.1, 0.25, 0.1, 0.9)
		draw_rect(Rect2(sx, sy, slot_w, slot_h), bg_color)
		# Border
		var border_c = slot["color"] if is_selected else Color(0.3, 0.3, 0.3, 0.6)
		draw_rect(Rect2(sx, sy, slot_w, 2), border_c)
		draw_rect(Rect2(sx, sy + slot_h - 2, slot_w, 2), border_c)
		draw_rect(Rect2(sx, sy, 2, slot_h), border_c)
		draw_rect(Rect2(sx + slot_w - 2, sy, 2, slot_h), border_c)

		# Weapon icon
		_draw_weapon_icon(Vector2(sx + 14, sy + slot_h * 0.5), slot["name"], i == selected_weapon_idx)

		# Weapon name
		_draw_pixel_text(slot["name"], Vector2(sx + 30, sy + 8), slot["color"], 0.85)
		# Ammo
		_draw_pixel_text("x%d" % slot["ammo"], Vector2(sx + 30, sy + 26), Color(0.8, 0.8, 0.8), 1.1)

		# Selected indicator
		if is_selected:
			draw_rect(Rect2(sx, sy, 4, slot_h), slot["color"])

func _draw_weapon_icon(pos: Vector2, weapon_name: String, selected: bool) -> void:
	var c = Color(1.0, 0.9, 0.1) if selected else Color(0.7, 0.65, 0.5)
	match weapon_name:
		"PLATANO":
			# Small banana
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(0, -8), pos + Vector2(5, -2),
				pos + Vector2(4, 5), pos + Vector2(0, 8),
				pos + Vector2(-3, 5), pos + Vector2(-3, -2)
			]), c)
		"MINI GRAAPM":
			# Round grenade
			draw_circle(pos, 7, c)
			draw_line(pos + Vector2(0, -7), pos + Vector2(3, -11), c, 2)
		"HUEVO":
			# Egg
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(0, -8), pos + Vector2(5, -3),
				pos + Vector2(5, 4), pos + Vector2(0, 8),
				pos + Vector2(-5, 4), pos + Vector2(-5, -3)
			]), c)
		_:
			draw_circle(pos, 5, c)

# ─── BOTTOM CENTER: SANTO DOMINGO label ────────────────────────────────────────
func _draw_santo_domingo_bottom() -> void:
	var vp = get_viewport().get_visible_rect().size
	var cx = vp.x * 0.5

	# Bottom bar
	draw_rect(Rect2(0, vp.y - 36, vp.x, 36), Color(0.03, 0.03, 0.12, 0.88))
	draw_rect(Rect2(0, vp.y - 36, vp.x, 2), Color(1.0, 0.88, 0.0, 0.7))

	_draw_pixel_text("SANTO DOMINGO", Vector2(cx - 70, vp.y - 25), Color(1.0, 0.88, 0.1), 1.6)

	# Joystick area hint lines
	draw_rect(Rect2(0, vp.y - 36, 155, 36), Color(0.08, 0.05, 0.05, 0.4))

	# Score / deliveries right side
	_draw_pixel_text("SCORE: %d" % score, Vector2(cx + 60, vp.y - 25), Color(0.7, 0.7, 0.7), 1.0)

# ─── Fire button (bottom right area) ──────────────────────────────────────────
func _draw_fire_button() -> void:
	var vp = get_viewport().get_visible_rect().size
	var bx = vp.x - 95.0
	var by = vp.y - 220.0

	# Fire button circle
	draw_circle(Vector2(bx + 35, by + 35), 34, Color(0.7, 0.1, 0.1, 0.45))
	draw_circle(Vector2(bx + 35, by + 35), 30, Color(0.85, 0.12, 0.12, 0.65))
	# Inner highlight
	draw_circle(Vector2(bx + 35, by + 30), 8, Color(1.0, 0.3, 0.3, 0.4))

	# Platano icon
	_draw_weapon_icon(Vector2(bx + 35, by + 30), "PLATANO", true)
	_draw_pixel_text("TIRA", Vector2(bx + 18, by + 56), Color(1.0, 0.9, 0.1), 1.1)

# ─── Joystick hint ─────────────────────────────────────────────────────────────
func _draw_joystick_hint() -> void:
	var vp = get_viewport().get_visible_rect().size
	var cx = 80.0
	var cy = vp.y - 120.0

	# Outer ring
	draw_circle(Vector2(cx, cy), 48, Color(1, 1, 1, 0.1))
	draw_circle(Vector2(cx, cy), 44, Color(0, 0, 0, 0.3))

	# Inner knob - positioned by lean
	var knob_off = Vector2.ZERO
	if _joy_finger >= 0 and _joy_origin != Vector2.ZERO:
		knob_off = Vector2.ZERO  # will be updated dynamically
	draw_circle(Vector2(cx, cy) + knob_off, 22, Color(0.9, 0.9, 1.0, 0.45))

	# Arrows
	var arrow_c = Color(1, 1, 1, 0.5)
	# Left arrow
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 35, cy), Vector2(cx - 25, cy - 8), Vector2(cx - 25, cy + 8)
	]), arrow_c)
	# Right arrow
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 35, cy), Vector2(cx + 25, cy - 8), Vector2(cx + 25, cy + 8)
	]), arrow_c)

# ─── Pickup banner ────────────────────────────────────────────────────────────
func _draw_pickup_banner() -> void:
	var vp = get_viewport().get_visible_rect().size
	var alpha = clamp(pickup_timer / 1.5, 0.0, 1.0)
	var by = 100.0

	draw_rect(Rect2(20, by, vp.x - 40, 50), Color(0.05, 0.1, 0.05, 0.9 * alpha))
	draw_rect(Rect2(22, by + 2, vp.x - 44, 46), Color(0.0, 0.0, 0.0, 0.8 * alpha))
	draw_rect(Rect2(20, by, vp.x - 40, 3), Color(0.2, 0.9, 0.3, alpha))
	draw_rect(Rect2(20, by + 47, vp.x - 40, 3), Color(0.2, 0.9, 0.3, alpha))

	_draw_pixel_text("RECENTLY PICKED UP FROM", Vector2(50, by + 8),
					 Color(0.7, 0.7, 0.7, alpha), 1.2)
	_draw_pixel_text("COLMADO EL FAVORITO", Vector2(40, by + 26),
					 Color(1.0, 0.9, 0.1, alpha), 1.8)

# ─── Message display ──────────────────────────────────────────────────────────
func _draw_message() -> void:
	var vp = get_viewport().get_visible_rect().size
	var alpha = clamp(message_timer / 0.4, 0.0, 1.0)
	var by = vp.y * 0.45

	var c = message_color
	c.a = alpha

	# Shadow
	_draw_pixel_text(message_text, Vector2(vp.x * 0.5 - 70 + 2, by + 2), Color(0, 0, 0, alpha * 0.7), 2.2)
	_draw_pixel_text(message_text, Vector2(vp.x * 0.5 - 70, by), c, 2.2)

# ─── Game over screen ─────────────────────────────────────────────────────────
func _draw_game_over() -> void:
	var vp = get_viewport().get_visible_rect().size

	# Dark overlay
	draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0, 0, 0, 0.78))

	# Panel
	var px = 30.0
	var py = 180.0
	var pw = vp.x - 60
	var ph = 420.0

	draw_rect(Rect2(px, py, pw, ph), Color(0.05, 0.05, 0.2, 0.97))
	draw_rect(Rect2(px + 3, py + 3, pw - 6, ph - 6), Color(0.08, 0.06, 0.15, 0.97))

	# Border glow
	var bc = Color(1.0, 0.88, 0.0) if game_over_won else Color(0.8, 0.1, 0.1)
	for i in range(3):
		draw_rect(Rect2(px + i, py + i, pw - i * 2, 3), bc * Color(1, 1, 1, 1.0 - i * 0.3))
		draw_rect(Rect2(px + i, py + ph - 3 - i, pw - i * 2, 3), bc * Color(1, 1, 1, 1.0 - i * 0.3))
		draw_rect(Rect2(px + i, py + i, 3, ph - i * 2), bc * Color(1, 1, 1, 1.0 - i * 0.3))
		draw_rect(Rect2(px + pw - 3 - i, py + i, 3, ph - i * 2), bc * Color(1, 1, 1, 1.0 - i * 0.3))

	if game_over_won:
		_draw_pixel_text("¡MISION", Vector2(px + 40, py + 30), Color(0.2, 1.0, 0.4), 3.0)
		_draw_pixel_text("COMPLETADA!", Vector2(px + 20, py + 70), Color(0.2, 1.0, 0.4), 2.5)
	else:
		_draw_pixel_text("GAME OVER", Vector2(px + 50, py + 50), Color(1.0, 0.2, 0.2), 3.0)

	_draw_pixel_text("SCORE: %d" % game_over_score, Vector2(px + 30, py + 130), Color(1.0, 0.9, 0.1), 2.0)
	_draw_pixel_text("MONEY: $%d" % game_over_money, Vector2(px + 30, py + 165), Color(0.2, 1.0, 0.4), 2.0)

	# Retry button
	draw_rect(Rect2(px + 20, py + 240, pw - 40, 55), Color(0.1, 0.4, 0.1, 0.95))
	draw_rect(Rect2(px + 22, py + 242, pw - 44, 51), Color(0.15, 0.5, 0.15, 0.95))
	_draw_pixel_text("▶ REINTENTAR", Vector2(px + 55, py + 259), Color(0.2, 1.0, 0.3), 1.8)

	# Menu button
	draw_rect(Rect2(px + 20, py + 310, pw - 40, 55), Color(0.1, 0.1, 0.35, 0.95))
	draw_rect(Rect2(px + 22, py + 312, pw - 44, 51), Color(0.12, 0.12, 0.45, 0.95))
	_draw_pixel_text("← MENU", Vector2(px + 75, py + 329), Color(0.6, 0.8, 1.0), 1.8)

# ─── Pixel text renderer (manual bitmap-like text) ────────────────────────────
func _draw_pixel_text(text: String, pos: Vector2, color: Color, size: float = 1.0) -> void:
	# We use a very simple 4x5 pixel font representation
	# This is an approximation since we can't load fonts easily in _draw()
	# Each character is drawn as a small colored block with sizing
	var char_w = 6.0 * size
	var char_h = 8.0 * size
	var x = pos.x
	for ch in text:
		if ch == " ":
			x += char_w * 0.6
			continue
		_draw_char(ch, Vector2(x, pos.y), color, size)
		x += char_w * 0.85

func _draw_char(ch: String, pos: Vector2, color: Color, size: float) -> void:
	# Simple block character rendering — draw small rectangles for each character
	var s = size
	var c = color
	var x = pos.x
	var y = pos.y

	# Characters are 5px wide x 7px tall at scale 1
	# We'll use a simplified approach: draw the character as filled blocks
	match ch:
		"$":
			draw_rect(Rect2(x, y + s, 5*s, s), c)
			draw_rect(Rect2(x, y + 3*s, 5*s, s), c)
			draw_rect(Rect2(x, y + 5*s, 5*s, s), c)
			draw_rect(Rect2(x + 2*s, y, s, 7*s), c)
			draw_rect(Rect2(x, y, 4*s, s), c)
			draw_rect(Rect2(x + s, y + 2*s, 4*s, s), c)
		"+":
			draw_rect(Rect2(x + 2*s, y, s, 5*s), c)
			draw_rect(Rect2(x, y + 2*s, 5*s, s), c)
		"-":
			draw_rect(Rect2(x, y + 2*s, 5*s, s), c)
		"!":
			draw_rect(Rect2(x + 2*s, y, s, 4*s), c)
			draw_rect(Rect2(x + 2*s, y + 5*s, s, s), c)
		":":
			draw_rect(Rect2(x + 2*s, y + s, s, s), c)
			draw_rect(Rect2(x + 2*s, y + 4*s, s, s), c)
		"▶":
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(0, 0), pos + Vector2(5*s, 3*s), pos + Vector2(0, 6*s)
			]), c)
		"←":
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(0, 3*s), pos + Vector2(3*s, 0), pos + Vector2(3*s, 6*s)
			]), c)
			draw_rect(Rect2(x + 3*s, y + 2*s, 3*s, 2*s), c)
		"¡":
			draw_rect(Rect2(x + 2*s, y, s, s), c)
			draw_rect(Rect2(x + 2*s, y + 2*s, s, 5*s), c)
		"¿":
			draw_rect(Rect2(x + 2*s, y + 5*s, s, s), c)
			draw_rect(Rect2(x, y, 4*s, s), c)
			draw_rect(Rect2(x, y, s, 3*s), c)
			draw_rect(Rect2(x + 2*s, y + 2*s, 3*s, s), c)
			draw_rect(Rect2(x + 2*s, y + 3*s, s, 2*s), c)
		_:
			# Fallback: render using a small solid rectangle approximation
			_draw_alphanumeric(ch, pos, c, s)

func _draw_alphanumeric(ch: String, pos: Vector2, color: Color, s: float) -> void:
	var x = pos.x
	var y = pos.y
	var c = color

	match ch.to_upper():
		"0":
			draw_rect(Rect2(x, y, 5*s, s), c); draw_rect(Rect2(x, y + 6*s, 5*s, s), c)
			draw_rect(Rect2(x, y, s, 7*s), c); draw_rect(Rect2(x + 4*s, y, s, 7*s), c)
		"1":
			draw_rect(Rect2(x + 2*s, y, s, 7*s), c)
			draw_rect(Rect2(x + s, y + s, 2*s, s), c)
			draw_rect(Rect2(x, y + 6*s, 5*s, s), c)
		"2":
			draw_rect(Rect2(x, y, 5*s, s), c); draw_rect(Rect2(x + 4*s, y, s, 3*s), c)
			draw_rect(Rect2(x, y + 3*s, 5*s, s), c); draw_rect(Rect2(x, y + 3*s, s, 3*s), c)
			draw_rect(Rect2(x, y + 6*s, 5*s, s), c)
		"3":
			draw_rect(Rect2(x, y, 5*s, s), c); draw_rect(Rect2(x + 4*s, y, s, 7*s), c)
			draw_rect(Rect2(x, y + 3*s, 4*s, s), c); draw_rect(Rect2(x, y + 6*s, 5*s, s), c)
		"4":
			draw_rect(Rect2(x, y, s, 4*s), c); draw_rect(Rect2(x + 4*s, y, s, 7*s), c)
			draw_rect(Rect2(x, y + 3*s, 5*s, s), c)
		"5":
			draw_rect(Rect2(x, y, 5*s, s), c); draw_rect(Rect2(x, y, s, 3*s), c)
			draw_rect(Rect2(x, y + 3*s, 5*s, s), c); draw_rect(Rect2(x + 4*s, y + 3*s, s, 3*s), c)
			draw_rect(Rect2(x, y + 6*s, 5*s, s), c)
		"6":
			draw_rect(Rect2(x, y, 5*s, s), c); draw_rect(Rect2(x, y, s, 7*s), c)
			draw_rect(Rect2(x, y + 3*s, 5*s, s), c); draw_rect(Rect2(x + 4*s, y + 3*s, s, 4*s), c)
			draw_rect(Rect2(x, y + 6*s, 5*s, s), c)
		"7":
			draw_rect(Rect2(x, y, 5*s, s), c); draw_rect(Rect2(x + 4*s, y, s, 4*s), c)
			draw_rect(Rect2(x + 2*s, y + 3*s, s, 4*s), c)
		"8":
			draw_rect(Rect2(x, y, 5*s, s), c); draw_rect(Rect2(x, y, s, 7*s), c)
			draw_rect(Rect2(x + 4*s, y, s, 7*s), c); draw_rect(Rect2(x, y + 3*s, 5*s, s), c)
			draw_rect(Rect2(x, y + 6*s, 5*s, s), c)
		"9":
			draw_rect(Rect2(x, y, 5*s, s), c); draw_rect(Rect2(x, y, s, 4*s), c)
			draw_rect(Rect2(x + 4*s, y, s, 7*s), c); draw_rect(Rect2(x, y + 3*s, 5*s, s), c)
			draw_rect(Rect2(x, y + 6*s, 5*s, s), c)
		"A":
			draw_rect(Rect2(x, y + s, s, 6*s), c); draw_rect(Rect2(x + 4*s, y + s, s, 6*s), c)
			draw_rect(Rect2(x + s, y, 3*s, s), c); draw_rect(Rect2(x, y + 3*s, 5*s, s), c)
		"B":
			draw_rect(Rect2(x, y, s, 7*s), c); draw_rect(Rect2(x, y, 4*s, s), c)
			draw_rect(Rect2(x, y + 3*s, 4*s, s), c); draw_rect(Rect2(x, y + 6*s, 4*s, s), c)
			draw_rect(Rect2(x + 4*s, y, s, 3*s), c); draw_rect(Rect2(x + 4*s, y + 3*s, s, 4*s), c)
		"C":
			draw_rect(Rect2(x + s, y, 4*s, s), c); draw_rect(Rect2(x, y + s, s, 5*s), c)
			draw_rect(Rect2(x + s, y + 6*s, 4*s, s), c)
		"D":
			draw_rect(Rect2(x, y, s, 7*s), c); draw_rect(Rect2(x, y, 3*s, s), c)
			draw_rect(Rect2(x, y + 6*s, 3*s, s), c); draw_rect(Rect2(x + 4*s, y + s, s, 5*s), c)
			draw_rect(Rect2(x + 3*s, y, s, s), c); draw_rect(Rect2(x + 3*s, y + 6*s, s, s), c)
		"E":
			draw_rect(Rect2(x, y, s, 7*s), c); draw_rect(Rect2(x, y, 5*s, s), c)
			draw_rect(Rect2(x, y + 3*s, 4*s, s), c); draw_rect(Rect2(x, y + 6*s, 5*s, s), c)
		"F":
			draw_rect(Rect2(x, y, s, 7*s), c); draw_rect(Rect2(x, y, 5*s, s), c)
			draw_rect(Rect2(x, y + 3*s, 4*s, s), c)
		"G":
			draw_rect(Rect2(x + s, y, 4*s, s), c); draw_rect(Rect2(x, y + s, s, 5*s), c)
			draw_rect(Rect2(x + s, y + 6*s, 4*s, s), c); draw_rect(Rect2(x + 4*s, y + 3*s, s, 4*s), c)
			draw_rect(Rect2(x + 2*s, y + 3*s, 2*s, s), c)
		"H":
			draw_rect(Rect2(x, y, s, 7*s), c); draw_rect(Rect2(x + 4*s, y, s, 7*s), c)
			draw_rect(Rect2(x, y + 3*s, 5*s, s), c)
		"I":
			draw_rect(Rect2(x, y, 5*s, s), c); draw_rect(Rect2(x, y + 6*s, 5*s, s), c)
			draw_rect(Rect2(x + 2*s, y, s, 7*s), c)
		"J":
			draw_rect(Rect2(x, y, 5*s, s), c); draw_rect(Rect2(x + 3*s, y, s, 6*s), c)
			draw_rect(Rect2(x, y + 6*s, 4*s, s), c); draw_rect(Rect2(x, y + 4*s, s, 2*s), c)
		"K":
			draw_rect(Rect2(x, y, s, 7*s), c); draw_rect(Rect2(x + s, y + 3*s, s, s), c)
			draw_rect(Rect2(x + 2*s, y + s, s, 2*s), c); draw_rect(Rect2(x + 2*s, y + 4*s, s, 2*s), c)
			draw_rect(Rect2(x + 3*s, y, s, s), c); draw_rect(Rect2(x + 3*s, y + 6*s, s, s), c)
			draw_rect(Rect2(x + 4*s, y, s, s), c); draw_rect(Rect2(x + 4*s, y + 6*s, s, s), c)
		"L":
			draw_rect(Rect2(x, y, s, 7*s), c); draw_rect(Rect2(x, y + 6*s, 5*s, s), c)
		"M":
			draw_rect(Rect2(x, y, s, 7*s), c); draw_rect(Rect2(x + 4*s, y, s, 7*s), c)
			draw_rect(Rect2(x + s, y, s, 3*s), c); draw_rect(Rect2(x + 3*s, y, s, 3*s), c)
			draw_rect(Rect2(x + 2*s, y + s, s, 2*s), c)
		"N":
			draw_rect(Rect2(x, y, s, 7*s), c); draw_rect(Rect2(x + 4*s, y, s, 7*s), c)
			draw_rect(Rect2(x + s, y + s, s, s), c); draw_rect(Rect2(x + 2*s, y + 2*s, s, s), c)
			draw_rect(Rect2(x + 3*s, y + 3*s, s, s), c)
		"O":
			draw_rect(Rect2(x + s, y, 3*s, s), c); draw_rect(Rect2(x + s, y + 6*s, 3*s, s), c)
			draw_rect(Rect2(x, y + s, s, 5*s), c); draw_rect(Rect2(x + 4*s, y + s, s, 5*s), c)
		"P":
			draw_rect(Rect2(x, y, s, 7*s), c); draw_rect(Rect2(x, y, 4*s, s), c)
			draw_rect(Rect2(x, y + 3*s, 4*s, s), c); draw_rect(Rect2(x + 4*s, y, s, 3*s), c)
		"Q":
			draw_rect(Rect2(x + s, y, 3*s, s), c); draw_rect(Rect2(x + s, y + 6*s, 3*s, s), c)
			draw_rect(Rect2(x, y + s, s, 5*s), c); draw_rect(Rect2(x + 4*s, y + s, s, 5*s), c)
			draw_rect(Rect2(x + 3*s, y + 4*s, s, s), c); draw_rect(Rect2(x + 4*s, y + 5*s, s, 2*s), c)
		"R":
			draw_rect(Rect2(x, y, s, 7*s), c); draw_rect(Rect2(x, y, 4*s, s), c)
			draw_rect(Rect2(x, y + 3*s, 4*s, s), c); draw_rect(Rect2(x + 4*s, y, s, 3*s), c)
			draw_rect(Rect2(x + 2*s, y + 4*s, s, s), c); draw_rect(Rect2(x + 3*s, y + 5*s, s, s), c)
			draw_rect(Rect2(x + 4*s, y + 6*s, s, s), c)
		"S":
			draw_rect(Rect2(x + s, y, 4*s, s), c); draw_rect(Rect2(x, y, s, 3*s), c)
			draw_rect(Rect2(x, y + 3*s, 5*s, s), c); draw_rect(Rect2(x + 4*s, y + 3*s, s, 4*s), c)
			draw_rect(Rect2(x, y + 6*s, 4*s, s), c)
		"T":
			draw_rect(Rect2(x, y, 5*s, s), c); draw_rect(Rect2(x + 2*s, y, s, 7*s), c)
		"U":
			draw_rect(Rect2(x, y, s, 6*s), c); draw_rect(Rect2(x + 4*s, y, s, 6*s), c)
			draw_rect(Rect2(x + s, y + 6*s, 3*s, s), c)
		"V":
			draw_rect(Rect2(x, y, s, 4*s), c); draw_rect(Rect2(x + 4*s, y, s, 4*s), c)
			draw_rect(Rect2(x + s, y + 4*s, s, s), c); draw_rect(Rect2(x + 3*s, y + 4*s, s, s), c)
			draw_rect(Rect2(x + 2*s, y + 5*s, s, 2*s), c)
		"W":
			draw_rect(Rect2(x, y, s, 7*s), c); draw_rect(Rect2(x + 4*s, y, s, 7*s), c)
			draw_rect(Rect2(x + s, y + 4*s, s, 3*s), c); draw_rect(Rect2(x + 3*s, y + 4*s, s, 3*s), c)
			draw_rect(Rect2(x + 2*s, y + 3*s, s, 4*s), c)
		"X":
			draw_rect(Rect2(x, y, s, 2*s), c); draw_rect(Rect2(x + 4*s, y, s, 2*s), c)
			draw_rect(Rect2(x + s, y + 2*s, s, s), c); draw_rect(Rect2(x + 3*s, y + 2*s, s, s), c)
			draw_rect(Rect2(x + 2*s, y + 3*s, s, s), c); draw_rect(Rect2(x + s, y + 4*s, s, s), c)
			draw_rect(Rect2(x + 3*s, y + 4*s, s, s), c); draw_rect(Rect2(x, y + 5*s, s, 2*s), c)
			draw_rect(Rect2(x + 4*s, y + 5*s, s, 2*s), c)
		"Y":
			draw_rect(Rect2(x, y, s, 3*s), c); draw_rect(Rect2(x + 4*s, y, s, 3*s), c)
			draw_rect(Rect2(x + s, y + 3*s, s, s), c); draw_rect(Rect2(x + 3*s, y + 3*s, s, s), c)
			draw_rect(Rect2(x + 2*s, y + 3*s, s, 4*s), c)
		"Z":
			draw_rect(Rect2(x, y, 5*s, s), c); draw_rect(Rect2(x + 3*s, y + s, s, s), c)
			draw_rect(Rect2(x + 2*s, y + 2*s, s, s), c); draw_rect(Rect2(x + s, y + 3*s, s, 2*s), c)
			draw_rect(Rect2(x, y + 5*s, s, s), c); draw_rect(Rect2(x, y + 6*s, 5*s, s), c)
		"/":
			draw_rect(Rect2(x + 4*s, y, s, 2*s), c); draw_rect(Rect2(x + 3*s, y + 2*s, s, s), c)
			draw_rect(Rect2(x + 2*s, y + 3*s, s, s), c); draw_rect(Rect2(x + s, y + 4*s, s, s), c)
			draw_rect(Rect2(x, y + 5*s, s, 2*s), c)
		"¿", "?":
			draw_rect(Rect2(x + s, y, 3*s, s), c); draw_rect(Rect2(x + 4*s, y, s, 3*s), c)
			draw_rect(Rect2(x + s, y + 3*s, 4*s, s), c); draw_rect(Rect2(x + 2*s, y + 5*s, s, s), c)
		_:
			# Unknown char - draw a block
			draw_rect(Rect2(x + s, y + s, 3*s, 5*s), Color(color.r, color.g, color.b, color.a * 0.5))

# ─── Touch input ──────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if game_over_visible:
		_handle_game_over_input(event)
		return

	var vp_size = get_viewport().get_visible_rect().size

	if event is InputEventScreenTouch:
		if event.pressed:
			# Right area top = fire
			if event.position.x > vp_size.x * 0.55 and event.position.y < vp_size.y * 0.78:
				_fire_finger = event.index
				emit_signal("fire_pressed")
			# Left area = swipe zone
			elif event.position.x <= vp_size.x * 0.55:
				_joy_finger = event.index
				_joy_origin = event.position
				touch_id = event.index
		else:
			if event.index == _fire_finger:
				_fire_finger = -1
			if event.index == _joy_finger:
				_joy_finger = -1
				var dx = event.position.x - _joy_origin.x
				if abs(dx) > 20:
					if dx < 0:
						emit_signal("swipe_left")
					else:
						emit_signal("swipe_right")
				emit_signal("direction_changed", Vector2.ZERO)

	elif event is InputEventScreenDrag:
		if event.index == _joy_finger:
			var offset = event.position - _joy_origin
			if offset.length() > 10:
				emit_signal("direction_changed", offset.normalized())

	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT, KEY_A:
				emit_signal("swipe_left")
			KEY_RIGHT, KEY_D:
				emit_signal("swipe_right")
			KEY_SPACE, KEY_Z:
				emit_signal("fire_pressed")

func _handle_game_over_input(event: InputEvent) -> void:
	var vp = get_viewport().get_visible_rect().size
	var px = 30.0
	var py = 180.0
	var pw = vp.x - 60

	if event is InputEventScreenTouch and event.pressed or \
	   (event is InputEventMouseButton and event.pressed):
		var click_pos: Vector2
		if event is InputEventScreenTouch:
			click_pos = event.position
		else:
			click_pos = event.position

		# Retry button
		if Rect2(px + 20, py + 240, pw - 40, 55).has_point(click_pos):
			get_tree().change_scene_to_file("res://scenes/GameScene.tscn")
		# Menu button
		elif Rect2(px + 20, py + 310, pw - 40, 55).has_point(click_pos):
			get_tree().change_scene_to_file("res://scenes/MenuScene.tscn")

# Legacy compat methods
func update_lives(h: int) -> void:
	update_health(h)

func cycle_weapon() -> void:
	selected_weapon_idx = (selected_weapon_idx + 1) % weapon_slots.size()
	emit_signal("weapon_selected", weapon_slots[selected_weapon_idx]["name"])
