extends CanvasLayer
## HUD.gd - Heads-up display and virtual joystick controller.

signal joystick_moved(direction: Vector2)
signal fire_pressed
signal weapon_selected(weapon_name: String)

@onready var score_label: Label = $TopBar/ScoreLabel
@onready var timer_label: Label = $TopBar/TimerLabel
@onready var money_label: Label = $MoneyBar/MoneyLabel
@onready var hearts_label: Label = $TopBar/HeartsLabel
@onready var weapon_label: Label = $BottomBar/WeaponLabel
@onready var ammo_label: Label = $BottomBar/AmmoLabel
@onready var delivery_label: Label = $DeliveryBanner
@onready var message_label: Label = $MessageLabel
@onready var joystick_base: ColorRect = $VirtualJoystick/JoystickBase
@onready var joystick_knob: ColorRect = $VirtualJoystick/JoystickKnob
@onready var fire_button: ColorRect = $FireButton
@onready var arrow_indicator: Label = $ArrowIndicator

const WEAPON_COLORS = {
	"platano": Color(1.0, 0.85, 0.1),
	"huevo": Color(0.95, 0.95, 0.85),
	"salami": Color(0.8, 0.2, 0.2),
	"fart": Color(0.5, 0.9, 0.3),
}

var joystick_active: bool = false
var joystick_touch_id: int = -1
var joystick_base_pos: Vector2 = Vector2.ZERO
const JOYSTICK_RADIUS = 55.0

var current_weapon: String = "platano"
var weapons_list: Array = ["platano", "huevo", "salami", "fart"]
var current_weapon_idx: int = 0

func _ready() -> void:
	if joystick_base:
		joystick_base_pos = joystick_base.global_position + joystick_base.size / 2
	_update_weapon_display()

func update_score(score: int) -> void:
	if score_label:
		score_label.text = "SCORE: %06d" % score

func update_timer(seconds: float) -> void:
	if timer_label:
		var mins = int(seconds) / 60
		var secs = int(seconds) % 60
		timer_label.text = "TIME: %d:%02d" % [mins, secs]
		if seconds < 30:
			timer_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
		else:
			timer_label.add_theme_color_override("font_color", Color(1, 1, 0.2))

func update_money(money: int) -> void:
	if money_label:
		money_label.text = "$ %d" % money

func update_lives(lives: int) -> void:
	if hearts_label:
		var hearts = ""
		for i in lives:
			hearts += "♥"
		for i in (3 - lives):
			hearts += "♡"
		hearts_label.text = hearts

func show_delivery_message(msg: String, color: Color = Color.WHITE) -> void:
	if delivery_label:
		delivery_label.text = msg
		delivery_label.add_theme_color_override("font_color", color)
		delivery_label.visible = true
		var tween = create_tween()
		tween.tween_property(delivery_label, "modulate:a", 1.0, 0.1)
		tween.tween_interval(1.5)
		tween.tween_property(delivery_label, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func(): delivery_label.visible = false)

func show_message(msg: String, duration: float = 2.0) -> void:
	if message_label:
		message_label.text = msg
		message_label.visible = true
		await get_tree().create_timer(duration).timeout
		if is_instance_valid(message_label):
			message_label.visible = false

func update_weapon(weapon: String, ammo: int) -> void:
	current_weapon = weapon
	if weapon_label:
		weapon_label.text = weapon.to_upper()
		weapon_label.add_theme_color_override("font_color", WEAPON_COLORS.get(weapon, Color.WHITE))
	if ammo_label:
		ammo_label.text = "x%d" % ammo
	_update_weapon_display()

func update_arrow(direction: Vector2) -> void:
	if arrow_indicator:
		if direction == Vector2.ZERO:
			arrow_indicator.visible = false
		else:
			arrow_indicator.visible = true
			var angle = atan2(direction.y, direction.x)
			var arrows = ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
			var idx = int(round(angle / (PI / 4))) % 8
			if idx < 0: idx += 8
			arrow_indicator.text = arrows[idx]

func _update_weapon_display() -> void:
	pass

func _input(event: InputEvent) -> void:
	_handle_joystick(event)
	_handle_fire(event)

func _handle_joystick(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_pos = event.position
		if joystick_base and _is_in_joystick_zone(touch_pos):
			if event.pressed:
				joystick_active = true
				joystick_touch_id = event.index
				_update_joystick(touch_pos)
			else:
				if event.index == joystick_touch_id:
					joystick_active = false
					joystick_touch_id = -1
					_reset_joystick()

	elif event is InputEventScreenDrag:
		if joystick_active and event.index == joystick_touch_id:
			_update_joystick(event.position)

func _is_in_joystick_zone(pos: Vector2) -> bool:
	# Left half of screen for joystick
	return pos.x < get_viewport().get_visible_rect().size.x * 0.5

func _update_joystick(touch_pos: Vector2) -> void:
	if not joystick_base:
		return
	var base_center = joystick_base.global_position + joystick_base.size / 2
	var delta = touch_pos - base_center
	if delta.length() > JOYSTICK_RADIUS:
		delta = delta.normalized() * JOYSTICK_RADIUS
	if joystick_knob:
		joystick_knob.position = joystick_base.position + joystick_base.size / 2 - joystick_knob.size / 2 + delta
	emit_signal("joystick_moved", delta / JOYSTICK_RADIUS)

func _reset_joystick() -> void:
	if not joystick_base or not joystick_knob:
		return
	joystick_knob.position = joystick_base.position + joystick_base.size / 2 - joystick_knob.size / 2
	emit_signal("joystick_moved", Vector2.ZERO)

func _handle_fire(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if fire_button and _is_in_fire_zone(event.position):
			emit_signal("fire_pressed")
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		emit_signal("fire_pressed")

func _is_in_fire_zone(pos: Vector2) -> bool:
	var vp = get_viewport().get_visible_rect().size
	return pos.x > vp.x * 0.5

func cycle_weapon() -> void:
	current_weapon_idx = (current_weapon_idx + 1) % weapons_list.size()
	current_weapon = weapons_list[current_weapon_idx]
	emit_signal("weapon_selected", current_weapon)
