extends Node2D
## Garage.gd - Vehicle selection and purchase screen.

const VEHICLES = [
	{
		"id": "bicycle",
		"name": "Bicicleta",
		"desc": "Clasico. Lento pero seguro.",
		"speed": 150,
		"cost": 0,
		"color": Color(0.2, 0.6, 1.0)
	},
	{
		"id": "moped",
		"name": "Motora",
		"desc": "El clasico mensajero. Mas rapido!",
		"speed": 250,
		"cost": 200,
		"color": Color(0.9, 0.3, 0.1)
	},
	{
		"id": "car",
		"name": "Carro",
		"desc": "Turbo speed! Pero ancho...",
		"speed": 350,
		"cost": 600,
		"color": Color(0.1, 0.8, 0.2)
	}
]

var selected_idx: int = 0

@onready var vehicle_name_label: Label = $Panel/VehicleName
@onready var vehicle_desc_label: Label = $Panel/VehicleDesc
@onready var speed_label: Label = $Panel/SpeedLabel
@onready var cost_label: Label = $Panel/CostLabel
@onready var status_label: Label = $Panel/StatusLabel
@onready var money_label: Label = $TopBar/MoneyLabel
@onready var buy_button: Button = $ButtonPanel/BuyButton
@onready var select_button: Button = $ButtonPanel/SelectButton
@onready var vehicle_display: ColorRect = $VehicleDisplay

func _ready() -> void:
	_update_display()
	if money_label:
		money_label.text = "$ %d" % GameState.money
	# Connect button signals
	if buy_button and not buy_button.pressed.is_connected(_on_buy_button_pressed):
		buy_button.pressed.connect(_on_buy_button_pressed)
	if select_button and not select_button.pressed.is_connected(_on_select_button_pressed):
		select_button.pressed.connect(_on_select_button_pressed)
	var back_btn = get_node_or_null("ButtonPanel/BackButton")
	if back_btn and not back_btn.pressed.is_connected(_on_back_button_pressed):
		back_btn.pressed.connect(_on_back_button_pressed)
	var prev_btn = get_node_or_null("NavButtons/PrevButton")
	if prev_btn and not prev_btn.pressed.is_connected(_on_prev_button_pressed):
		prev_btn.pressed.connect(_on_prev_button_pressed)
	var next_btn = get_node_or_null("NavButtons/NextButton")
	if next_btn and not next_btn.pressed.is_connected(_on_next_button_pressed):
		next_btn.pressed.connect(_on_next_button_pressed)

func _select(idx: int) -> void:
	selected_idx = idx
	_update_display()

func _update_display() -> void:
	var v = VEHICLES[selected_idx]
	if vehicle_name_label:
		vehicle_name_label.text = v["name"]
	if vehicle_desc_label:
		vehicle_desc_label.text = v["desc"]
	if speed_label:
		speed_label.text = "VELOCIDAD: %d" % v["speed"]
	if cost_label:
		cost_label.text = "PRECIO: $%d" % v["cost"]
	if vehicle_display:
		vehicle_display.color = v["color"]

	var owned = v["id"] in GameState.unlocked_vehicles
	var selected = GameState.vehicle == v["id"]

	if status_label:
		if selected:
			status_label.text = "✓ SELECCIONADO"
			status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		elif owned:
			status_label.text = "DESBLOQUEADO"
			status_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
		else:
			status_label.text = "BLOQUEADO"
			status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))

	if buy_button:
		buy_button.visible = not owned
		buy_button.disabled = GameState.money < v["cost"]

	if select_button:
		select_button.visible = owned
		select_button.disabled = selected

func _on_buy_button_pressed() -> void:
	var v = VEHICLES[selected_idx]
	if GameState.spend_money(v["cost"]):
		GameState.unlock_vehicle(v["id"])
		GameState.vehicle = v["id"]
		GameState.save()
		_update_display()
		if money_label:
			money_label.text = "$ %d" % GameState.money

func _on_select_button_pressed() -> void:
	var v = VEHICLES[selected_idx]
	GameState.vehicle = v["id"]
	GameState.save()
	_update_display()

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MissionSelect.tscn")

func _on_prev_button_pressed() -> void:
	selected_idx = (selected_idx - 1 + VEHICLES.size()) % VEHICLES.size()
	_update_display()

func _on_next_button_pressed() -> void:
	selected_idx = (selected_idx + 1) % VEHICLES.size()
	_update_display()
