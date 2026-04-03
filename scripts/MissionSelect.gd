extends Node2D
## MissionSelect.gd - Mission selection screen.

const MISSIONS = [
	{
		"name": "La Primera Entrega",
		"desc": "Deliver 3 packages\nin Zona Colonial.",
		"reward": 50,
		"time": 120,
		"difficulty": "FACIL",
		"diff_color": Color(0.2, 0.9, 0.2)
	},
	{
		"name": "El Rush del Domingo",
		"desc": "Deliver 6 packages\nbefore the rain.",
		"reward": 120,
		"time": 150,
		"difficulty": "NORMAL",
		"diff_color": Color(1.0, 0.8, 0.1)
	},
	{
		"name": "Mediodia Loco",
		"desc": "8 deliveries, enemies\nare aggressive!",
		"reward": 220,
		"time": 180,
		"difficulty": "DIFICIL",
		"diff_color": Color(1.0, 0.3, 0.1)
	},
	{
		"name": "La Noche de Los Colmados",
		"desc": "Survive the night.\n10 deliveries. Buena suerte.",
		"reward": 400,
		"time": 200,
		"difficulty": "LOCO",
		"diff_color": Color(0.9, 0.1, 0.9)
	},
]

var selected_mission: int = 0

@onready var mission_name_label: Label = $Panel/MissionName
@onready var mission_desc_label: Label = $Panel/MissionDesc
@onready var reward_label: Label = $Panel/RewardLabel
@onready var time_label: Label = $Panel/TimeLabel
@onready var diff_label: Label = $Panel/DiffLabel
@onready var money_label: Label = $TopBar/MoneyLabel
@onready var mission_cards: VBoxContainer = $MissionList

func _ready() -> void:
	_populate_missions()
	_update_panel()
	if money_label:
		money_label.text = "$ %d" % GameState.money
	# Connect all buttons programmatically (bulletproof for iOS)
	_connect_buttons()

func _connect_buttons() -> void:
	var btns = {
		"ButtonPanel/PlayButton": _on_play_button_pressed,
		"ButtonPanel/GarageButton": _on_garage_button_pressed,
		"ButtonPanel/ShopButton": _on_shop_button_pressed,
		"ButtonPanel/BackButton": _on_back_button_pressed,
	}
	for path in btns:
		var btn = get_node_or_null(path)
		if btn:
			if btn.pressed.is_connected(btns[path]):
				btn.pressed.disconnect(btns[path])
			btn.pressed.connect(btns[path])

func _populate_missions() -> void:
	if not mission_cards:
		return
	for i in MISSIONS.size():
		var m = MISSIONS[i]
		var btn = Button.new()
		btn.text = "%d. %s" % [i + 1, m["name"]]
		btn.add_theme_font_size_override("font_size", 14)
		var idx = i
		btn.pressed.connect(func(): _select_mission(idx))
		mission_cards.add_child(btn)

func _select_mission(idx: int) -> void:
	selected_mission = idx
	_update_panel()

func _update_panel() -> void:
	if selected_mission >= MISSIONS.size():
		return
	var m = MISSIONS[selected_mission]
	if mission_name_label:
		mission_name_label.text = m["name"]
	if mission_desc_label:
		mission_desc_label.text = m["desc"]
	if reward_label:
		reward_label.text = "PAGA: $%d" % m["reward"]
	if time_label:
		time_label.text = "TIEMPO: %ds" % m["time"]
	if diff_label:
		diff_label.text = m["difficulty"]
		diff_label.add_theme_color_override("font_color", m["diff_color"])

func _on_play_button_pressed() -> void:
	GameState.current_mission = selected_mission
	GameState.reset_run()
	get_tree().change_scene_to_file("res://scenes/GameScene.tscn")

func _on_garage_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Garage.tscn")

func _on_shop_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Shop.tscn")

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MenuScene.tscn")
