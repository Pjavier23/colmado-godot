extends CanvasLayer
## HUD.gd - Heads-up display and virtual joystick controller.
## Fully rewritten for bulletproof iOS touch support.

# Signals — direction_changed is the primary signal; joystick_moved kept for compat
signal direction_changed(dir: Vector2)
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

# Touch tracking
var _joy_finger: int = -1
var _joy_origin: Vector2 = Vector2.ZERO
var _fire_finger: int = -1

# Legacy state kept for compatibility
var joystick_active: bool = false
var joystick_touch_id: int = -1
var joystick_base_pos: Vector2 = Vector2.ZERO
const JOYSTICK_RADIUS = 60.0

var current_weapon: String = "platano"
var weapons_list: Array = ["platano", "huevo", "salami", "fart"]
var current_weapon_idx: int = 0

func _ready() -> void:
	if joystick_base:
		joystick_base_pos = joystick_base.global_position + joystick_base.size / 2
	_update_weapon_display()

	# Use unhandled_input so Button presses still go to buttons first,
	# but joystick/fire zone touches (on non-Button areas) always work.
	set_process_unhandled_input(true)

	# Connect GameOverPanel buttons programmatically
	var retry = get_node_or_null("GameOverPanel/RetryButton")
	var menu_btn = get_node_or_null("GameOverPanel/MenuButton")
	if retry:
		if not retry.pressed.is_connected(_on_retry_button_pressed):
			retry.pressed.connect(_on_retry_button_pressed)
	if menu_btn:
		if not menu_btn.pressed.is_connected(_on_menu_button_pressed):
			menu_btn.pressed.connect(_on_menu_button_pressed)

func _on_retry_button_pressed() -> void:
	GameState.reset_run()
	get_tree().change_scene_to_file("res://scenes/GameScene.tscn")

func _on_menu_button_pressed() -> void:
	GameState.save()
	get_tree().change_scene_to_file("res://scenes/MenuScene.tscn")

# ─── HUD update methods ───────────────────────────────────────────────────────

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

# ─── Touch input (iOS-first, bulletproof) ────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	var screen_size = get_viewport().get_visible_rect().size

	if event is InputEventScreenTouch:
		if event.pressed:
			# Left 45% of screen → joystick
			if event.position.x < screen_size.x * 0.45:
				_joy_finger = event.index
				_joy_origin = event.position
				joystick_active = true
				joystick_touch_id = event.index
				# Move joystick base to touch point
				if joystick_base:
					joystick_base.global_position = event.position - joystick_base.size / 2
				if joystick_knob:
					joystick_knob.global_position = event.position - joystick_knob.size / 2
			# Right 45%+ bottom half → fire
			elif event.position.x > screen_size.x * 0.55 and event.position.y > screen_size.y * 0.5:
				_fire_finger = event.index
				emit_signal("fire_pressed")
		else:
			# Finger lifted
			if event.index == _joy_finger:
				_joy_finger = -1
				joystick_active = false
				joystick_touch_id = -1
				emit_signal("direction_changed", Vector2.ZERO)
				emit_signal("joystick_moved", Vector2.ZERO)
				_reset_joystick()
			if event.index == _fire_finger:
				_fire_finger = -1

	elif event is InputEventScreenDrag:
		if event.index == _joy_finger:
			var offset = event.position - _joy_origin
			var clamped = offset.limit_length(JOYSTICK_RADIUS)
			var dir = offset.normalized() if offset.length() > 15 else Vector2.ZERO
			emit_signal("direction_changed", dir)
			emit_signal("joystick_moved", dir)
			if joystick_knob:
				joystick_knob.global_position = _joy_origin + clamped - joystick_knob.size / 2

	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			emit_signal("fire_pressed")

func _reset_joystick() -> void:
	if not joystick_base or not joystick_knob:
		return
	joystick_knob.position = joystick_base.position + joystick_base.size / 2 - joystick_knob.size / 2

func cycle_weapon() -> void:
	current_weapon_idx = (current_weapon_idx + 1) % weapons_list.size()
	current_weapon = weapons_list[current_weapon_idx]
	emit_signal("weapon_selected", current_weapon)
