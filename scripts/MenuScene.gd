extends Node2D
## MenuScene.gd - Title screen with PS1-style aesthetics.

@onready var title_label: Label = $TitleContainer/TitleLabel
@onready var press_start_label: Label = $PressStartLabel
@onready var buildings_container: Node2D = $BuildingsContainer
@onready var blink_timer: Timer = $BlinkTimer
@onready var wobble_timer: Timer = $WobbleTimer

var blink_visible: bool = true
var wobble_time: float = 0.0
var building_scroll_speed: float = 80.0

# Building data for scrolling city
var buildings_data: Array = []
var building_nodes: Array = []

const BUILDING_COLORS = [
	Color(0.18, 0.18, 0.35),
	Color(0.25, 0.15, 0.20),
	Color(0.15, 0.25, 0.20),
	Color(0.30, 0.20, 0.10),
	Color(0.20, 0.20, 0.40),
]

const BUILDING_SIGNS = ["COLMADO", "FRIO-FRIO", "LOTERIA", "CHIMICHURRI", "VARIEDADES", "FERRETERIA", "FARMACIA", "BANCA"]

func _ready() -> void:
	_setup_buildings()
	_start_wobble()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		get_tree().change_scene_to_file("res://scenes/MissionSelect.tscn")
	elif event is InputEventMouseButton and event.pressed:
		get_tree().change_scene_to_file("res://scenes/MissionSelect.tscn")

func _process(delta: float) -> void:
	_scroll_buildings(delta)
	_update_wobble(delta)

func _setup_buildings() -> void:
	# Create building rects procedurally
	var x_pos = 0
	while x_pos < 500:
		var b = _make_building(x_pos)
		buildings_data.append(b)
		building_nodes.append(b)
		x_pos += b["width"] + randi() % 10 + 2

func _make_building(x: float) -> Dictionary:
	var height = randi() % 80 + 40
	var width = randi() % 40 + 25
	var color = BUILDING_COLORS[randi() % BUILDING_COLORS.size()]
	var sign = BUILDING_SIGNS[randi() % BUILDING_SIGNS.size()]
	var node = ColorRect.new()
	node.size = Vector2(width, height)
	node.position = Vector2(x, 680 - height)
	node.color = color
	buildings_container.add_child(node)

	# Add top face for isometric look
	var top = ColorRect.new()
	top.size = Vector2(width, 8)
	top.position = Vector2(x, 680 - height - 8)
	top.color = color.lightened(0.3)
	buildings_container.add_child(top)

	# Window lights
	for wy in range(2):
		for wx in range(int(width / 14)):
			var win = ColorRect.new()
			win.size = Vector2(6, 6)
			win.position = Vector2(x + wx * 12 + 4, 680 - height + wy * 18 + 10)
			win.color = Color(1.0, 0.95, 0.5, 0.8) if randf() > 0.3 else Color(0.1, 0.1, 0.1)
			buildings_container.add_child(win)

	# Sign label
	var lbl = Label.new()
	lbl.text = sign
	lbl.add_theme_font_size_override("font_size", 6)
	lbl.position = Vector2(x + 2, 680 - height + 5)
	lbl.add_theme_color_override("font_color", Color(1, 1, 0.2))
	buildings_container.add_child(lbl)

	return {"x": x, "width": width + 50, "node_start_idx": 0}

func _scroll_buildings(delta: float) -> void:
	for child in buildings_container.get_children():
		child.position.x -= building_scroll_speed * delta
		if child.position.x < -100:
			child.position.x += 520

func _start_wobble() -> void:
	wobble_time = 0.0

func _update_wobble(delta: float) -> void:
	wobble_time += delta * 3.0
	if title_label:
		title_label.position.x = 0 + sin(wobble_time) * 3.0
		title_label.position.y = 0 + cos(wobble_time * 0.7) * 2.0

	# Blink press start
	var blink_speed = 1.5
	var t = fmod(Time.get_ticks_msec() / 1000.0, 1.0 / blink_speed)
	if press_start_label:
		press_start_label.visible = (fmod(Time.get_ticks_msec() / 1000.0 * blink_speed, 1.0) < 0.6)

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MissionSelect.tscn")

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		get_tree().change_scene_to_file("res://scenes/MissionSelect.tscn")
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		get_tree().change_scene_to_file("res://scenes/MissionSelect.tscn")

func _on_blink_timer_timeout() -> void:
	blink_visible = !blink_visible
	if press_start_label:
		press_start_label.visible = blink_visible
